param(
  [Parameter(Mandatory=$true)]
  [string]$RepoPath,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [ValidateRange(1, 3600)]
  [int]$LockTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "add-repo.ps1" -Mode $Mode
$scriptLock = New-ScriptLock -KitRoot $kitRoot -LockName "add-repo" -TimeoutSeconds $LockTimeoutSeconds
try {
$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = ([System.IO.Path]::GetFullPath($repoResolved.Path) -replace '\\','/').TrimEnd('/')

$reposPath = Join-Path $kitRoot "config\repositories.json"
$targetsPath = Join-Path $kitRoot "config\targets.json"
$projectCustomPath = Join-Path $kitRoot "config\project-custom-files.json"
$repoName = Split-Path -Leaf $repo

$reposRaw = Read-JsonArray $reposPath
$repos = [System.Collections.Generic.List[string]]::new()
foreach ($r in @($reposRaw)) {
  [void]$repos.Add([string]$r)
}
$repoExists = @($repos | Where-Object { ([string]$_).Equals($repo, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0

$allowProjectRuleRepos = Read-ProjectRuleAllowRepos $kitRoot
$allowProjectRules = Is-RepoAllowedForProjectRules -Repo $repo -AllowRepos $allowProjectRuleRepos

$targetsRaw = Read-JsonArray $targetsPath
$targets = [System.Collections.Generic.List[object]]::new()
foreach ($t in @($targetsRaw)) {
  [void]$targets.Add($t)
}

$customCfg = $null
$customEntryExists = $false
$customCfgChanged = $false
if (Test-Path -LiteralPath $projectCustomPath) {
  try {
    $customCfg = Get-Content -LiteralPath $projectCustomPath -Raw | ConvertFrom-Json
  } catch {
    throw "project-custom-files.json invalid JSON: $projectCustomPath"
  }
} else {
  $customCfg = [pscustomobject]@{
    default = @()
    repos = @()
  }
  $customCfgChanged = $true
}

if (-not $customCfg.PSObject.Properties['default']) {
  $customCfg | Add-Member -NotePropertyName "default" -NotePropertyValue @()
  $customCfgChanged = $true
}
if (-not $customCfg.PSObject.Properties['repos']) {
  $customCfg | Add-Member -NotePropertyName "repos" -NotePropertyValue @()
  $customCfgChanged = $true
}

$customRepos = @($customCfg.repos)
foreach ($entry in $customRepos) {
  if ($null -eq $entry) { continue }
  if ($entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
    if (([string]$entry.repoName).Equals($repoName, [System.StringComparison]::OrdinalIgnoreCase)) {
      $customEntryExists = $true
      break
    }
  }
  if ($entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
    $entryRepoNorm = Normalize-Repo ([string]$entry.repo)
    if ($entryRepoNorm.Equals($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
      $customEntryExists = $true
      break
    }
  }
}

if (-not $customEntryExists) {
  if ($Mode -eq "plan") {
    Write-Host "[PLAN] ADD custom policy repo entry: repoName=$repoName files=[]"
  } else {
    $customCfg.repos = @($customRepos + @([pscustomobject]@{
      repoName = $repoName
      files = @()
    }))
    $customCfgChanged = $true
    Write-Host "[ADDED] custom policy repo entry: repoName=$repoName files=[]"
  }
} elseif ($Mode -eq "plan") {
  Write-Host "[PLAN] KEEP custom policy repo entry: repoName=$repoName"
}

$desired = [System.Collections.Generic.List[object]]::new()
foreach ($fileName in @("AGENTS.md", "CLAUDE.md", "GEMINI.md")) {
  $projectSource = $null
  if ($allowProjectRules) {
    $projectSource = Get-ProjectRuleSourceForRepo -KitRoot $kitRoot -RepoPath $repo -FileName $fileName
  } else {
    $projectSource = Get-DefaultProjectRuleTemplateSource -KitRoot $kitRoot -FileName $fileName
  }

  if ($null -eq $projectSource) {
    Write-Host "[WARN] project rule source not found for $repo ($fileName), skipped"
    continue
  }

  [void]$desired.Add([pscustomobject]@{ source = $projectSource; target = "$repo/$fileName" })
}

$customFiles = @(Get-ProjectCustomFilesForRepo -KitRoot $kitRoot -RepoPath $repo -RepoName $repoName)
foreach ($customRelRaw in $customFiles) {
  $customRel = ([string]$customRelRaw -replace '\\', '/').TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($customRel)) { continue }

  $customSourceRel = Get-ProjectCustomSourceForRepo -KitRoot $kitRoot -RepoName $repoName -CustomRelativePath $customRel
  if ([string]::IsNullOrWhiteSpace($customSourceRel)) {
    Write-Host "[WARN] custom source not found for repo/common fallback: $repoName/$customRel"
    continue
  }

  [void]$desired.Add([pscustomobject]@{
    source = $customSourceRel
    target = "$repo/$customRel"
  })
}

$removedDisallowed = 0
if (-not $allowProjectRules) {
  $repoPrefix = "$repo/"
  $filteredTargets = @($targets | Where-Object {
    $src = [string]$_.source
    $dst = [string]$_.target
    -not ((Is-ProjectRuleSource $src) -and $dst.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase))
  })
  $removedDisallowed = $targets.Count - $filteredTargets.Count
  $targets = [System.Collections.Generic.List[object]]::new()
  foreach ($ft in $filteredTargets) {
    [void]$targets.Add($ft)
  }
}

$added = 0
foreach ($d in @($desired)) {
  $exists = $targets | Where-Object { $_.source -eq $d.source -and $_.target -eq $d.target }
  if (-not $exists) {
    if ($Mode -eq "plan") {
      Write-Host "[PLAN] ADD target: $($d.source) -> $($d.target)"
    } else {
      [void]$targets.Add([pscustomobject]$d)
      Write-Host "[ADDED] target: $($d.source) -> $($d.target)"
    }
    $added++
  }
}

if ($Mode -eq "plan") {
  if (-not $allowProjectRules) {
    Write-Host "[PLAN] project rules disabled for repo: $repo"
    if ($removedDisallowed -gt 0) {
      Write-Host "[PLAN] REMOVE disallowed project-rule targets: $removedDisallowed"
    }
  }
  if ($repoExists) {
    Write-Host "[PLAN] KEEP repositories: $repo"
  } else {
    Write-Host "[PLAN] ADD repositories: $repo"
  }
  Write-Host "Plan done. add_repo=$([int](-not $repoExists)) added_targets=$added removed_disallowed_targets=$removedDisallowed"
  return
}

if (-not $repoExists) {
  [void]$repos.Add($repo)
  Write-JsonArray $reposPath @($repos) 4
  Write-Host "[ADDED] repositories: $repo"
} else {
  Write-Host "[SKIP] repositories already has: $repo"
}

Write-JsonArray $targetsPath @($targets) 6
if (-not $allowProjectRules) {
  Write-Host "[INFO] project rules disabled for repo: $repo"
}
if ($customCfgChanged) {
  $customCfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $projectCustomPath -Encoding UTF8
  Write-Host "[UPDATED] project-custom-files.json"
}
Write-Host "Done. added_targets=$added removed_disallowed_targets=$removedDisallowed mode=$Mode"
} finally {
  Release-ScriptLock -LockHandle $scriptLock
}
