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
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

if (-not $SkipConfigValidation) {
  Invoke-ChildScript -ScriptPath (Join-Path $PSScriptRoot "validate-config.ps1")
}

try {
  $targets = @(Read-JsonArray $targetsPath)
} catch {
  throw "targets.json is not valid JSON: $targetsPath"
}

if ($targets.Count -eq 0) {
  throw "targets.json has no entries: $targetsPath"
}

$repos = Read-JsonArray $reposPath
$repoRoots = @((Read-TargetRepoRoots $kitRoot))
$enforceBoundary = ($repoRoots.Count -gt 0)
if (-not $enforceBoundary) {
  Write-Host "[INFO] skip boundary validation: repositories.json not found or empty"
}
$projectRulePolicy = Read-ProjectRulePolicy $kitRoot
$enforceBoundaryClass = $false
if ($null -ne $projectRulePolicy.defaults -and $null -ne $projectRulePolicy.defaults.PSObject.Properties['enforce_boundary_class']) {
  $enforceBoundaryClass = [bool]$projectRulePolicy.defaults.enforce_boundary_class
}
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
  $expectedBoundaryClass = Get-ExpectedBoundaryClass -Source ([string]$item.source)
  $boundaryClassProp = $item.PSObject.Properties['boundary_class']
  $boundaryClassText = if ($null -eq $boundaryClassProp) { "" } else { ([string]$boundaryClassProp.Value).Trim().ToLowerInvariant() }
  if ($enforceBoundaryClass -and $expectedBoundaryClass -eq "unknown") {
    Write-Host "[CFG] unknown source layer for boundary classification: source=$($item.source) target=$($item.target)"
    $cfgFail++
  } elseif ($enforceBoundaryClass) {
    if ([string]::IsNullOrWhiteSpace($boundaryClassText)) {
      Write-Host "[CFG] missing boundary_class: source=$($item.source) target=$($item.target)"
      $cfgFail++
    } elseif (-not (Test-BoundaryClassValue -BoundaryClass $boundaryClassText)) {
      Write-Host "[CFG] invalid boundary_class: expected one of global-user/project/shared-template source=$($item.source) target=$($item.target) actual=$boundaryClassText"
      $cfgFail++
    } elseif ($boundaryClassText -ne $expectedBoundaryClass) {
      Write-Host "[CFG] boundary_class mismatch: source=$($item.source) target=$($item.target) expected=$expectedBoundaryClass actual=$boundaryClassText"
      $cfgFail++
    }
  }

  if ($enforceBoundary) {
    $boundaryCheck = Get-BoundaryMappingCheck -Source ([string]$item.source) -Target ([string]$item.target) -RepoRoots $repoRoots
    if (-not $boundaryCheck.allowed) {
      Write-Host ("[CFG] boundary violation: source={0} target={1} reason={2} source_layer={3} target_layer={4}" -f $item.source, $item.target, $boundaryCheck.reason, $boundaryCheck.source_layer, $boundaryCheck.target_layer)
      $cfgFail++
    }
  }

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

  if (Test-FileContentEqual -PathA $src -PathB $dst) {
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
      try {
        Invoke-ChildScript -ScriptPath $trackedScript -ScriptArgs @("-RepoPath", $activeRepo, "-PolicyPath", $policyPath, "-Scope", $TrackedFilesScope)
      } catch {
        Write-Host ("[TRACKED] policy check failed: " + $_.Exception.Message)
        $trackedFilesFail++
      }
    }
  }
}

$growthFail = 0
$growthScript = Join-Path $PSScriptRoot "governance\verify-growth-pack.ps1"
if (-not (Test-Path -LiteralPath $growthScript -PathType Leaf)) {
  Write-Host "[GROWTH] skip: script not found"
} else {
  try {
    Invoke-ChildScript -ScriptPath $growthScript
  } catch {
    Write-Host ("[GROWTH] verification failed: " + $_.Exception.Message)
    $growthFail++
  }
}

$antiBloatFail = 0
$antiBloatScript = Join-Path $PSScriptRoot "governance\check-anti-bloat-budgets.ps1"
if (-not (Test-Path -LiteralPath $antiBloatScript -PathType Leaf)) {
  Write-Host "[ANTI-BLOAT] skip: script not found"
} else {
  try {
    Invoke-ChildScript -ScriptPath $antiBloatScript -ScriptArgs @("-PolicyOnly")
  } catch {
    Write-Host ("[ANTI-BLOAT] policy validation failed: " + $_.Exception.Message)
    $antiBloatFail++
  }
}

if ($fail -gt 0 -or $policyFail -gt 0 -or $trackedFilesFail -gt 0 -or $growthFail -gt 0 -or $antiBloatFail -gt 0) { exit 1 }
