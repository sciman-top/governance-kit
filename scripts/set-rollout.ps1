param(
  [Parameter(Mandatory=$true)]
  [string]$RepoPath,
  [ValidateSet("observe", "enforce")]
  [string]$Phase,
  [string]$BlockExpiredWaiver,
  [string]$PlannedEnforceDate,
  [string]$Note,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe"
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "set-rollout.ps1" -Mode $Mode
if (!(Test-Path $rolloutPath)) {
  throw "rule-rollout.json not found: $rolloutPath"
}

$repo = Normalize-Repo $RepoPath
$rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
if ($null -eq $rollout.repos) { $rollout | Add-Member -NotePropertyName repos -NotePropertyValue @() -Force }
$repos = @($rollout.repos)

$idx = -1
for ($i = 0; $i -lt $repos.Count; $i++) {
  $r = [string]$repos[$i].repo
  if ((Normalize-Repo $r).Equals($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
    $idx = $i
    break
  }
}

if ($idx -ge 0) {
  $entry = [pscustomobject]@{}
  foreach ($p in $repos[$idx].PSObject.Properties) { $entry | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
} else {
  $entry = [pscustomobject]@{ repo = $repo }
}

if ($PSBoundParameters.ContainsKey("Phase")) { $entry.phase = $Phase }
if ($PSBoundParameters.ContainsKey("BlockExpiredWaiver")) {
  $raw = ($BlockExpiredWaiver + "").Trim().ToLowerInvariant()
  if ($raw -in @("true","1","yes","y")) {
    $entry.blockExpiredWaiver = $true
  } elseif ($raw -in @("false","0","no","n")) {
    $entry.blockExpiredWaiver = $false
  } else {
    throw "invalid BlockExpiredWaiver: $BlockExpiredWaiver (use true/false/1/0)"
  }
}
if ($PSBoundParameters.ContainsKey("PlannedEnforceDate")) {
  if (-not [string]::IsNullOrWhiteSpace($PlannedEnforceDate)) {
    $d = Parse-IsoDate $PlannedEnforceDate
    if ($null -eq $d) {
      throw "invalid PlannedEnforceDate: $PlannedEnforceDate"
    }
    $entry.planned_enforce_date = $d.ToString("yyyy-MM-dd")
  } else {
    $entry.PSObject.Properties.Remove("planned_enforce_date")
  }
}
if ($PSBoundParameters.ContainsKey("Note")) {
  if (-not [string]::IsNullOrWhiteSpace($Note)) {
    $entry.note = $Note
  } else {
    $entry.PSObject.Properties.Remove("note")
  }
}

if ($Mode -eq "plan") {
  if ($idx -ge 0) {
    Write-Host "[PLAN] UPDATE rollout entry: $repo"
  } else {
    Write-Host "[PLAN] ADD rollout entry: $repo"
  }
  $entry | ConvertTo-Json -Depth 8 | Write-Host
  Write-Host "Plan done."
  exit 0
}

if ($idx -ge 0) {
  $repos[$idx] = $entry
  Write-Host "[UPDATED] rollout entry: $repo"
} else {
  $repos += $entry
  Write-Host "[ADDED] rollout entry: $repo"
}

$rollout.repos = $repos
$rollout | ConvertTo-Json -Depth 10 | Set-Content -Path $rolloutPath -Encoding UTF8
Write-Host "set-rollout done. mode=$Mode"
