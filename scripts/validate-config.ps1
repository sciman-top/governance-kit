$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

$reposPath = Join-Path $kitRoot "config\repositories.json"
$targetsPath = Join-Path $kitRoot "config\targets.json"
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$projectRulePolicyPath = Get-ProjectRulePolicyPath $kitRoot
$projectCustomPath = Join-Path $kitRoot "config\project-custom-files.json"

if (!(Test-Path $reposPath)) { throw "repositories.json not found: $reposPath" }
if (!(Test-Path $targetsPath)) { throw "targets.json not found: $targetsPath" }
if (!(Test-Path $rolloutPath)) { throw "rule-rollout.json not found: $rolloutPath" }
if (!(Test-Path $projectRulePolicyPath)) { throw "project-rule-policy.json not found: $projectRulePolicyPath" }
if (!(Test-Path $projectCustomPath)) { throw "project-custom-files.json not found: $projectCustomPath" }

$fail = 0

try {
  $repos = Read-JsonArray $reposPath
} catch {
  throw "repositories.json invalid JSON: $reposPath"
}

try {
  $targets = Read-JsonArray $targetsPath
} catch {
  throw "targets.json invalid JSON: $targetsPath"
}

try {
  $rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
} catch {
  throw "rule-rollout.json invalid JSON: $rolloutPath"
}

try {
  $projectRulePolicy = Get-Content -Path $projectRulePolicyPath -Raw | ConvertFrom-Json
} catch {
  throw "project-rule-policy.json invalid JSON: $projectRulePolicyPath"
}

try {
  $projectCustom = Get-Content -Path $projectCustomPath -Raw | ConvertFrom-Json
} catch {
  throw "project-custom-files.json invalid JSON: $projectCustomPath"
}

if ($null -ne $projectRulePolicy.defaults) {
  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_auto_fix']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.allow_auto_fix -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.allow_auto_fix must be boolean"
    $fail++
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_rule_optimization']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.allow_rule_optimization -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.allow_rule_optimization must be boolean"
    $fail++
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_local_optimize_without_backflow']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.allow_local_optimize_without_backflow -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.allow_local_optimize_without_backflow must be boolean"
    $fail++
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['max_autonomous_iterations']) {
    if ($projectRulePolicy.defaults.max_autonomous_iterations -isnot [int] -and $projectRulePolicy.defaults.max_autonomous_iterations -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.defaults.max_autonomous_iterations must be integer"
      $fail++
    } elseif ([int]$projectRulePolicy.defaults.max_autonomous_iterations -lt 1 -or [int]$projectRulePolicy.defaults.max_autonomous_iterations -gt 100) {
      Write-Host "[CFG] project-rule-policy.defaults.max_autonomous_iterations out of range: expected 1..100"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['max_repeated_failure_per_step']) {
    if ($projectRulePolicy.defaults.max_repeated_failure_per_step -isnot [int] -and $projectRulePolicy.defaults.max_repeated_failure_per_step -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.defaults.max_repeated_failure_per_step must be integer"
      $fail++
    } elseif ([int]$projectRulePolicy.defaults.max_repeated_failure_per_step -lt 1 -or [int]$projectRulePolicy.defaults.max_repeated_failure_per_step -gt 20) {
      Write-Host "[CFG] project-rule-policy.defaults.max_repeated_failure_per_step out of range: expected 1..20"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['stop_on_irreversible_risk']) {
    if ($projectRulePolicy.defaults.stop_on_irreversible_risk -isnot [bool]) {
      Write-Host "[CFG] project-rule-policy.defaults.stop_on_irreversible_risk must be boolean"
      $fail++
    }
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['forbid_breaking_contract']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.forbid_breaking_contract -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.forbid_breaking_contract must be boolean"
    $fail++
  }
}

$seenRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($r in $repos) {
  $repo = Normalize-Repo ([string]$r)
  if (-not $seenRepo.Add($repo)) {
    Write-Host "[CFG] duplicate repository: $repo"
    $fail++
  }
}

$customRepos = if ($null -eq $projectCustom.repos) { @() } else { @($projectCustom.repos) }
$seenCustomRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $customRepos) {
  if ($null -eq $entry) {
    Write-Host "[CFG] project-custom entry is null"
    $fail++
    continue
  }

  $entryRepoName = [string]$entry.repoName
  if ([string]::IsNullOrWhiteSpace($entryRepoName)) {
    Write-Host "[CFG] project-custom entry missing repoName"
    $fail++
    continue
  }

  if (-not $seenCustomRepo.Add($entryRepoName)) {
    Write-Host "[CFG] duplicate project-custom repoName: $entryRepoName"
    $fail++
  }

  $customRepoMatched = $false
  foreach ($repoNorm in $seenRepo) {
    if ((Split-Path -Leaf $repoNorm).Equals($entryRepoName, [System.StringComparison]::OrdinalIgnoreCase)) {
      $customRepoMatched = $true
      break
    }
  }
  if (-not $customRepoMatched) {
    Write-Host "[CFG] project-custom repoName not in repositories.json: $entryRepoName"
    $fail++
  }
}

foreach ($repoNorm in $seenRepo) {
  $repoLeaf = Split-Path -Leaf $repoNorm
  if (-not $seenCustomRepo.Contains($repoLeaf)) {
    Write-Host "[CFG] project-custom missing repo entry: $repoLeaf"
    $fail++
  }
}

$allowProjectRuleRepos = if ($null -eq $projectRulePolicy.allowProjectRulesForRepos) { @() } else { @($projectRulePolicy.allowProjectRulesForRepos) }
$seenProjectAllowRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ar in $allowProjectRuleRepos) {
  $arText = [string]$ar
  if ([string]::IsNullOrWhiteSpace($arText)) {
    Write-Host "[CFG] project-rule allow repo is empty"
    $fail++
    continue
  }

  $arWin = ($arText -replace '/', '\')
  if (-not [System.IO.Path]::IsPathRooted($arWin)) {
    Write-Host "[CFG] project-rule allow repo must be absolute: $arText"
    $fail++
    continue
  }

  $arNorm = Normalize-Repo $arText
  if (-not $seenProjectAllowRepo.Add($arNorm)) {
    Write-Host "[CFG] duplicate project-rule allow repo: $arNorm"
    $fail++
  }

  if (-not $seenRepo.Contains($arNorm)) {
    Write-Host "[CFG] project-rule allow repo not in repositories.json: $arNorm"
    $fail++
  }
}

$policyRepos = if ($null -eq $projectRulePolicy.repos) { @() } else { @($projectRulePolicy.repos) }
foreach ($pr in $policyRepos) {
  if ($null -eq $pr) {
    Write-Host "[CFG] project-rule-policy.repos entry is null"
    $fail++
    continue
  }

  $hasRepoKey = $pr.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$pr.repo)
  $hasRepoNameKey = $pr.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$pr.repoName)
  if (-not $hasRepoKey -and -not $hasRepoNameKey) {
    Write-Host "[CFG] project-rule-policy.repos entry must contain repo or repoName"
    $fail++
  }

  if ($pr.PSObject.Properties['allow_auto_fix'] -and $pr.allow_auto_fix -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.allow_auto_fix must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['allow_rule_optimization'] -and $pr.allow_rule_optimization -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.allow_rule_optimization must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['allow_local_optimize_without_backflow'] -and $pr.allow_local_optimize_without_backflow -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.allow_local_optimize_without_backflow must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['max_autonomous_iterations']) {
    if ($pr.max_autonomous_iterations -isnot [int] -and $pr.max_autonomous_iterations -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.repos.max_autonomous_iterations must be integer"
      $fail++
    } elseif ([int]$pr.max_autonomous_iterations -lt 1 -or [int]$pr.max_autonomous_iterations -gt 100) {
      Write-Host "[CFG] project-rule-policy.repos.max_autonomous_iterations out of range: expected 1..100"
      $fail++
    }
  }
  if ($pr.PSObject.Properties['max_repeated_failure_per_step']) {
    if ($pr.max_repeated_failure_per_step -isnot [int] -and $pr.max_repeated_failure_per_step -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.repos.max_repeated_failure_per_step must be integer"
      $fail++
    } elseif ([int]$pr.max_repeated_failure_per_step -lt 1 -or [int]$pr.max_repeated_failure_per_step -gt 20) {
      Write-Host "[CFG] project-rule-policy.repos.max_repeated_failure_per_step out of range: expected 1..20"
      $fail++
    }
  }
  if ($pr.PSObject.Properties['stop_on_irreversible_risk'] -and $pr.stop_on_irreversible_risk -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.stop_on_irreversible_risk must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['forbid_breaking_contract'] -and $pr.forbid_breaking_contract -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.forbid_breaking_contract must be boolean"
    $fail++
  }
}

$seenTarget = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($t in $targets) {
  if ($null -eq $t -or [string]::IsNullOrWhiteSpace([string]$t.source) -or [string]::IsNullOrWhiteSpace([string]$t.target)) {
    Write-Host "[CFG] invalid target entry: missing source or target"
    $fail++
    continue
  }

  if ([System.IO.Path]::IsPathRooted([string]$t.source)) {
    Write-Host "[CFG] source must be relative: $($t.source)"
    $fail++
  }

  $target = ([string]$t.target -replace '/', '\')
  if (-not [System.IO.Path]::IsPathRooted($target)) {
    Write-Host "[CFG] target must be absolute: $($t.target)"
    $fail++
  } else {
    $targetNorm = [System.IO.Path]::GetFullPath($target)
    if (-not $seenTarget.Add($targetNorm)) {
      Write-Host "[CFG] duplicate target path: $targetNorm"
      $fail++
    }

    if (Is-ProjectRuleSource ([string]$t.source)) {
      $targetNormUnix = ($targetNorm -replace '\\', '/')
      $matchedAllowRepo = $false
      foreach ($ar in $seenProjectAllowRepo) {
        if ($targetNormUnix.StartsWith("$ar/", [System.StringComparison]::OrdinalIgnoreCase)) {
          $matchedAllowRepo = $true
          break
        }
      }
      if (-not $matchedAllowRepo) {
        Write-Host "[CFG] disallowed project-rule target: source=$($t.source) target=$($t.target)"
        $fail++
      }
    }
  }
}

if ($null -eq $rollout.default) {
  Write-Host "[CFG] rollout.default missing"
  $fail++
}

$validPhases = @("observe", "enforce")
$defaultPhase = [string]$rollout.default.phase
if ([string]::IsNullOrWhiteSpace($defaultPhase) -or ($validPhases -notcontains $defaultPhase)) {
  Write-Host "[CFG] rollout.default.phase invalid: $defaultPhase"
  $fail++
}

if ($null -eq $rollout.repos) {
  $rolloutRepos = @()
} else {
  $rolloutRepos = @($rollout.repos)
}

foreach ($rr in $rolloutRepos) {
  $repo = [string]$rr.repo
  if ([string]::IsNullOrWhiteSpace($repo)) {
    Write-Host "[CFG] rollout repo entry missing repo"
    $fail++
    continue
  }

  $phase = [string]$rr.phase
  if (-not [string]::IsNullOrWhiteSpace($phase) -and ($validPhases -notcontains $phase)) {
    Write-Host "[CFG] rollout phase invalid: repo=$repo phase=$phase"
    $fail++
  }

  $planned = [string]$rr.planned_enforce_date
  if (-not [string]::IsNullOrWhiteSpace($planned)) {
    $d = Parse-IsoDate $planned
    if ($null -eq $d) {
      Write-Host "[CFG] invalid planned_enforce_date: repo=$repo value=$planned (expected yyyy-MM-dd)"
      $fail++
    }
  }
}

if ($fail -gt 0) {
  Write-Host "Config validation failed. issues=$fail"
  exit 1
}

Write-Host "Config validation passed. repositories=$($repos.Count) targets=$($targets.Count) rolloutRepos=$($rolloutRepos.Count)"
