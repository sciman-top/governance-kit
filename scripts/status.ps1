param(
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$codexRuntimePolicyPath = Join-Path $kitRoot "config\codex-runtime-policy.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$repos = @(Read-JsonArray (Join-Path $kitRoot "config\repositories.json"))
$targets = @(Read-JsonArray (Join-Path $kitRoot "config\targets.json"))
$userHome = [System.IO.Path]::GetFullPath($HOME) -replace '\\','/'

$repoSummaries = [System.Collections.Generic.List[object]]::new()
$missingRepos = 0
foreach ($r in $repos) {
  $repoNorm = Normalize-Repo ([string]$r)
  $repoMissing = -not (Test-Path ($repoNorm -replace '/', '\'))
  if ($repoMissing) { $missingRepos++ }
  $prefix = "$repoNorm/"
  $count = @($targets | Where-Object {
    ([string]$_.target).StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
  }).Count
  [void]$repoSummaries.Add([pscustomobject]@{
    repo = [string]$r
    targets = $count
    missing = [bool]$repoMissing
  })
}

$globalTargets = @($targets | Where-Object {
  $_.target -like "$userHome/.codex/*" -or
  $_.target -like "$userHome/.claude/*" -or
  $_.target -like "$userHome/.gemini/*"
}).Count

$orphanTargets = 0
foreach ($t in $targets) {
  $target = [string]$t.target
  $isGlobal = $target -like "$userHome/.codex/*" -or $target -like "$userHome/.claude/*" -or $target -like "$userHome/.gemini/*"
  if ($isGlobal) { continue }

  $matchedRepo = $false
  foreach ($r in $repos) {
    $repoNorm = Normalize-Repo ([string]$r)
    if ($target.StartsWith("$repoNorm/", [System.StringComparison]::OrdinalIgnoreCase)) {
      $matchedRepo = $true
      break
    }
  }

  if (-not $matchedRepo) { $orphanTargets++ }
}

$warnings = [System.Collections.Generic.List[string]]::new()
$rolloutSummary = $null
$codexRuntimeSummary = $null
if (Test-Path $rolloutPath) {
  $rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
  $defaultPhase = [string]$rollout.default.phase
  $defaultBlock = [bool]$rollout.default.blockExpiredWaiver
  $rules = @($rollout.repos)
  $observe = 0
  $enforce = 0
  $overdueObserve = 0
  $today = (Get-Date).Date
  $repoRollouts = [System.Collections.Generic.List[object]]::new()

  foreach ($r in $repos) {
    $repoNorm = Normalize-Repo ([string]$r)
    $rule = $rules | Where-Object { (Normalize-Repo ([string]$_.repo)).Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    $phase = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.phase)) { [string]$rule.phase } else { $defaultPhase }
    $planned = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.planned_enforce_date)) { [string]$rule.planned_enforce_date } else { "" }
    $overdue = $false
    if ($phase -eq "observe" -and -not [string]::IsNullOrWhiteSpace($planned)) {
      $plannedDt = Parse-IsoDate $planned
      if ($null -eq $plannedDt) {
        [void]$warnings.Add("invalid planned_enforce_date: $repoNorm => $planned (expected yyyy-MM-dd)")
      } elseif ($plannedDt.Date -lt $today) {
        $overdueObserve++
        $overdue = $true
      }
    }
    if ($phase -eq "enforce") { $enforce++ } else { $observe++ }
    [void]$repoRollouts.Add([pscustomobject]@{
      repo = $repoNorm
      phase = $phase
      planned_enforce_date = if ([string]::IsNullOrWhiteSpace($planned)) { $null } else { $planned }
      overdue = [bool]$overdue
    })
  }

  $rolloutSummary = [pscustomobject]@{
    default_phase = $defaultPhase
    default_block_expired_waiver = $defaultBlock
    observe = $observe
    enforce = $enforce
    observe_overdue = $overdueObserve
    repos = @($repoRollouts)
  }
}

if (Test-Path -LiteralPath $codexRuntimePolicyPath -PathType Leaf) {
  try {
    $runtimePolicy = Get-Content -Path $codexRuntimePolicyPath -Raw | ConvertFrom-Json
    $enabledByDefault = if ($null -ne $runtimePolicy.PSObject.Properties['enabled_by_default']) { [bool]$runtimePolicy.enabled_by_default } else { $false }
    $policyEntries = @()
    if ($null -ne $runtimePolicy.PSObject.Properties['repos'] -and $null -ne $runtimePolicy.repos) {
      $policyEntries = @($runtimePolicy.repos)
    }
    $enabledRepoEntries = @($policyEntries | Where-Object { $null -ne $_ -and $_.PSObject.Properties['enabled'] -and [bool]$_.enabled })
    $codexTargetCount = @($targets | Where-Object { ([string]$_.target) -match "/\.codex/" }).Count
    $codexHomeTargetCount = @($targets | Where-Object { ([string]$_.target) -like "$userHome/.codex/*" }).Count
    $codexRepoTargetCount = $codexTargetCount - $codexHomeTargetCount
    if ($codexRepoTargetCount -lt 0) { $codexRepoTargetCount = 0 }

    $codexRuntimeSummary = [pscustomobject]@{
      policy_found = $true
      enabled_by_default = [bool]$enabledByDefault
      policy_repo_entries = @($policyEntries).Count
      enabled_repo_entries = $enabledRepoEntries.Count
      codex_target_mappings = $codexTargetCount
      codex_home_target_mappings = $codexHomeTargetCount
      codex_repo_target_mappings = $codexRepoTargetCount
    }
  } catch {
    [void]$warnings.Add("invalid codex-runtime-policy.json: $codexRuntimePolicyPath")
    $codexRuntimeSummary = [pscustomobject]@{
      policy_found = $true
      enabled_by_default = $false
      policy_repo_entries = 0
      enabled_repo_entries = 0
      codex_target_mappings = 0
      codex_home_target_mappings = 0
      codex_repo_target_mappings = 0
    }
  }
} else {
  $codexRuntimeSummary = [pscustomobject]@{
    policy_found = $false
    enabled_by_default = $false
    policy_repo_entries = 0
    enabled_repo_entries = 0
    codex_target_mappings = 0
    codex_home_target_mappings = 0
    codex_repo_target_mappings = 0
  }
}

$result = [pscustomobject]@{
  schema_version = "1.0"
  repositories = $repos.Count
  targets = $targets.Count
  repos = @($repoSummaries)
  global_home_targets = $globalTargets
  missing_repositories = $missingRepos
  orphan_targets = $orphanTargets
  rollout = $rolloutSummary
  codex_runtime = $codexRuntimeSummary
  warnings = @($warnings)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  return
}

Write-Host "governance-kit status"
Write-Host "repositories=$($repos.Count)"
Write-Host "targets=$($targets.Count)"
foreach ($repoItem in $repoSummaries) {
  Write-Host "- $($repoItem.repo) : targets=$($repoItem.targets)"
}
Write-Host "global-home-targets=$globalTargets"
Write-Host "missing-repositories=$missingRepos"
Write-Host "orphan-targets=$orphanTargets"

if ($null -ne $rolloutSummary) {
  foreach ($w in $warnings) {
    Write-Host "[WARN] $w"
  }
  Write-Host "rollout.default.phase=$($rolloutSummary.default_phase)"
  Write-Host "rollout.default.blockExpiredWaiver=$($rolloutSummary.default_block_expired_waiver)"
  Write-Host "rollout.observe=$($rolloutSummary.observe)"
  Write-Host "rollout.enforce=$($rolloutSummary.enforce)"
  Write-Host "rollout.observe_overdue=$($rolloutSummary.observe_overdue)"
}
if ($null -ne $codexRuntimeSummary) {
  Write-Host "codex_runtime.policy_found=$($codexRuntimeSummary.policy_found)"
  Write-Host "codex_runtime.enabled_by_default=$($codexRuntimeSummary.enabled_by_default)"
  Write-Host "codex_runtime.policy_repo_entries=$($codexRuntimeSummary.policy_repo_entries)"
  Write-Host "codex_runtime.enabled_repo_entries=$($codexRuntimeSummary.enabled_repo_entries)"
  Write-Host "codex_runtime.target_mappings=$($codexRuntimeSummary.codex_target_mappings)"
  Write-Host "codex_runtime.home_target_mappings=$($codexRuntimeSummary.codex_home_target_mappings)"
  Write-Host "codex_runtime.repo_target_mappings=$($codexRuntimeSummary.codex_repo_target_mappings)"
}
