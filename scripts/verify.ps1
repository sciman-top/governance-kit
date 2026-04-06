param(
  [switch]$SkipConfigValidation,
  [ValidateSet("none", "staged", "outgoing", "both")]
  [string]$TrackedFilesScope = "both",
  [switch]$SkipTrackedFilesPolicy
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$targetsPath = Join-Path $kitRoot "config\targets.json"
$reposPath = Join-Path $kitRoot "config\repositories.json"
if (!(Test-Path $targetsPath)) {
  throw "targets.json not found: $targetsPath"
}

$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

if (-not $SkipConfigValidation) {
  Invoke-ChildScript (Join-Path $PSScriptRoot "validate-config.ps1")
}

try {
  $raw = Get-Content -Path $targetsPath -Raw | ConvertFrom-Json
} catch {
  throw "targets.json is not valid JSON: $targetsPath"
}

$targets = if ($raw -is [System.Array]) { @($raw) } elseif ($null -eq $raw) { @() } else { @($raw) }
if ($targets.Count -eq 0) {
  throw "targets.json has no entries: $targetsPath"
}

$repos = Read-JsonArray $reposPath
$allowProjectRuleRepos = Read-ProjectRuleAllowRepos $kitRoot

$cfgFail = 0
$seenTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($item in $targets) {
  if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.source) -or [string]::IsNullOrWhiteSpace([string]$item.target)) {
    Write-Host "[CFG] invalid entry (missing source/target)"
    $cfgFail++
    continue
  }

  if ([System.IO.Path]::IsPathRooted([string]$item.source)) {
    Write-Host "[CFG] source must be relative path: $($item.source)"
    $cfgFail++
    continue
  }

  if (-not [System.IO.Path]::IsPathRooted(([string]$item.target -replace '/', '\'))) {
    Write-Host "[CFG] target must be absolute path: $($item.target)"
    $cfgFail++
    continue
  }

  $normTarget = [System.IO.Path]::GetFullPath(([string]$item.target -replace '/', '\'))
  if (Is-ProjectRuleSource ([string]$item.source)) {
    $normTargetUnix = ($normTarget -replace '\\', '/')
    $allowed = $false
    foreach ($allowRepo in $allowProjectRuleRepos) {
      if ($normTargetUnix.StartsWith("$allowRepo/", [System.StringComparison]::OrdinalIgnoreCase)) {
        $allowed = $true
        break
      }
    }
    if (-not $allowed) {
      Write-Host "[CFG] disallowed project-rule target mapping: $($item.source) -> $normTargetUnix"
      $cfgFail++
    }
  }

  if (-not $seenTargets.Add($normTarget)) {
    Write-Host "[CFG] duplicate target path: $normTarget"
    $cfgFail++
  }
}

if ($cfgFail -gt 0) {
  Write-Host "Verify done. config_fail=$cfgFail"
  exit 1
}

$ok = 0
$fail = 0
foreach ($item in $targets) {
  $src = Join-Path $kitRoot $item.source
  $dst = [System.IO.Path]::GetFullPath(($item.target -replace '/', '\'))

  if (!(Test-Path $src) -or !(Test-Path $dst)) {
    Write-Host "[MISS] $($item.source) -> $dst"
    $fail++
    continue
  }

  $h1 = Get-FileSha256 -Path $src
  $h2 = Get-FileSha256 -Path $dst
  if ($h1 -eq $h2) {
    Write-Host "[OK]   $($item.source) == $dst"
    $ok++
  } else {
    Write-Host "[DIFF] $($item.source) != $dst"
    $fail++
  }
}

Write-Host "Verify done. ok=$ok fail=$fail"

$projectRuleFiles = @("AGENTS.md", "CLAUDE.md", "GEMINI.md")
$projectSourceHashesByName = @{}
foreach ($f in $projectRuleFiles) {
  $projectSourceHashesByName[$f] = @()
}

$projectSourceRoot = Join-Path $kitRoot "source\project"
if (Test-Path $projectSourceRoot) {
  $projectSourceFiles = @(Get-ChildItem -Path $projectSourceRoot -Recurse -File | Where-Object {
    $projectRuleFiles -contains $_.Name
  })
  foreach ($sf in $projectSourceFiles) {
    $h = Get-FileSha256 -Path $sf.FullName
    $projectSourceHashesByName[$sf.Name] += $h
  }
}
$policyFail = 0
foreach ($repoRaw in $repos) {
  $repoNorm = Normalize-Repo ([string]$repoRaw)
  if (Is-RepoAllowedForProjectRules -Repo $repoNorm -AllowRepos $allowProjectRuleRepos) {
    continue
  }

  $repoWin = $repoNorm -replace '/', '\'
  if (!(Test-Path $repoWin)) {
    continue
  }

  foreach ($f in $projectRuleFiles) {
    $actualPath = Join-Path $repoWin $f
    if (!(Test-Path $actualPath)) {
      continue
    }
    $sourceHashes = @($projectSourceHashesByName[$f])
    if ($sourceHashes.Count -eq 0) {
      continue
    }
    $actualHash = Get-FileSha256 -Path $actualPath
    if ($sourceHashes -contains $actualHash) {
      Write-Host "[POLICY] disallowed project rule content detected: $actualPath"
      $policyFail++
    }
  }
}

if ($policyFail -gt 0) {
  Write-Host "Verify policy failed. disallowed_project_rule_files=$policyFail"
}

$trackedFilesFail = 0
if (-not $SkipTrackedFilesPolicy -and $TrackedFilesScope -ne "none") {
  $trackedScript = Join-Path $PSScriptRoot "governance\check-tracked-files.ps1"
  if (-not (Test-Path -LiteralPath $trackedScript -PathType Leaf)) {
    Write-Host "[TRACKED] skip: script not found: $trackedScript"
  } else {
    $gitTop = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$gitTop)) {
      Write-Host "[TRACKED] skip: current working directory is not a git repository"
    } else {
      $activeRepo = [System.IO.Path]::GetFullPath(([string]$gitTop).Trim())
      $policyPath = Join-Path $activeRepo ".governance\tracked-files-policy.json"
      & powershell -NoProfile -ExecutionPolicy Bypass -File $trackedScript -RepoPath $activeRepo -PolicyPath $policyPath -Scope $TrackedFilesScope
      if ($LASTEXITCODE -ne 0) {
        $trackedFilesFail++
      }
    }
  }
}

if ($fail -gt 0 -or $policyFail -gt 0 -or $trackedFilesFail -gt 0) { exit 1 }
