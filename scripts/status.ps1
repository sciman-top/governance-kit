param(
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
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

$result = [pscustomobject]@{
  schema_version = "1.0"
  repositories = $repos.Count
  targets = $targets.Count
  repos = @($repoSummaries)
  global_home_targets = $globalTargets
  missing_repositories = $missingRepos
  orphan_targets = $orphanTargets
  rollout = $rolloutSummary
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
