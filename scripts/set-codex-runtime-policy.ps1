param(
  [string]$RepoPath,
  [string]$RepoName,
  [Parameter(Mandatory = $true)]
  [string]$Enabled,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe"
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$policyPath = Join-Path $kitRoot "config\codex-runtime-policy.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
Write-ModeRisk -ScriptName "set-codex-runtime-policy.ps1" -Mode $Mode

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  throw "codex-runtime-policy.json not found: $policyPath"
}

$rawEnabled = ($Enabled + "").Trim().ToLowerInvariant()
if ($rawEnabled -in @("true", "1", "yes", "y")) {
  $enabledValue = $true
} elseif ($rawEnabled -in @("false", "0", "no", "n")) {
  $enabledValue = $false
} else {
  throw "invalid Enabled: $Enabled (use true/false/1/0)"
}

if ([string]::IsNullOrWhiteSpace($RepoPath) -and [string]::IsNullOrWhiteSpace($RepoName)) {
  throw "Either -RepoPath or -RepoName is required."
}

$repoNorm = $null
if (-not [string]::IsNullOrWhiteSpace($RepoPath)) {
  $repoNorm = Normalize-Repo $RepoPath
}

$repoNameNorm = $null
if (-not [string]::IsNullOrWhiteSpace($RepoName)) {
  $repoNameNorm = [string]$RepoName
} elseif (-not [string]::IsNullOrWhiteSpace($repoNorm)) {
  $repoNameNorm = Get-RepoName $repoNorm
}

$policy = Read-JsonFile -Path $policyPath -DefaultValue $null -DisplayName "codex-runtime-policy.json"
if ($null -eq $policy) {
  throw "codex-runtime-policy.json is empty: $policyPath"
}
if ($null -eq $policy.PSObject.Properties['repos']) {
  $policy | Add-Member -NotePropertyName repos -NotePropertyValue @() -Force
}

$repos = @($policy.repos)
$idx = -1
for ($i = 0; $i -lt $repos.Count; $i++) {
  $entry = $repos[$i]
  if ($null -eq $entry) { continue }

  $match = $false
  if ($null -ne $repoNorm -and $entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
    $entryRepoNorm = Normalize-Repo ([string]$entry.repo)
    if ($entryRepoNorm.Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
      $match = $true
    }
  }
  if (-not $match -and -not [string]::IsNullOrWhiteSpace($repoNameNorm) -and $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
    if (([string]$entry.repoName).Equals($repoNameNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
      $match = $true
    }
  }

  if ($match) {
    $idx = $i
    break
  }
}

if ($idx -ge 0) {
  $entry = [pscustomobject]@{}
  foreach ($p in $repos[$idx].PSObject.Properties) {
    $entry | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
  }
} else {
  $entry = [pscustomobject]@{}
}

if (-not [string]::IsNullOrWhiteSpace($repoNameNorm)) {
  $entry | Add-Member -NotePropertyName repoName -NotePropertyValue $repoNameNorm -Force
}
if ($null -ne $repoNorm) {
  $entry | Add-Member -NotePropertyName repo -NotePropertyValue $repoNorm -Force
}
$entry | Add-Member -NotePropertyName enabled -NotePropertyValue ([bool]$enabledValue) -Force

if ($Mode -eq "plan") {
  if ($idx -ge 0) {
    Write-Host "[PLAN] UPDATE codex runtime policy entry"
  } else {
    Write-Host "[PLAN] ADD codex runtime policy entry"
  }
  $entry | ConvertTo-Json -Depth 8 | Write-Host
  Write-Host "Plan done."
  exit 0
}

if ($idx -ge 0) {
  $repos[$idx] = $entry
  Write-Host "[UPDATED] codex runtime policy entry"
} else {
  $repos += $entry
  Write-Host "[ADDED] codex runtime policy entry"
}

$policy.repos = $repos
$policy | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $policyPath -Encoding UTF8
Write-Host "set-codex-runtime-policy done. mode=$Mode"
