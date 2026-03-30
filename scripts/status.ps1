$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

$repos = Read-JsonArray (Join-Path $kitRoot "config\repositories.json")
$targets = Read-JsonArray (Join-Path $kitRoot "config\targets.json")
$userHome = [System.IO.Path]::GetFullPath($HOME) -replace '\\','/'

Write-Host "governance-kit status"
Write-Host "repositories=$($repos.Count)"
Write-Host "targets=$($targets.Count)"

$missingRepos = 0
foreach ($r in $repos) {
  $repoNorm = Normalize-Repo ([string]$r)
  if (!(Test-Path ($repoNorm -replace '/', '\'))) {
    $missingRepos++
  }
  $prefix = "$repoNorm/"
  $count = @($targets | Where-Object {
    ([string]$_.target).StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
  }).Count
  Write-Host "- $r : targets=$count"
}

$globalTargets = @($targets | Where-Object {
  $_.target -like "$userHome/.codex/*" -or
  $_.target -like "$userHome/.claude/*" -or
  $_.target -like "$userHome/.gemini/*"
}).Count
Write-Host "global-home-targets=$globalTargets"
Write-Host "missing-repositories=$missingRepos"

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
Write-Host "orphan-targets=$orphanTargets"

if (Test-Path $rolloutPath) {
  $rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
  $defaultPhase = [string]$rollout.default.phase
  $defaultBlock = [bool]$rollout.default.blockExpiredWaiver
  $rules = @($rollout.repos)
  $observe = 0
  $enforce = 0
  $overdueObserve = 0
  $today = (Get-Date).Date
  foreach ($r in $repos) {
    $repoNorm = Normalize-Repo ([string]$r)
    $rule = $rules | Where-Object { (Normalize-Repo ([string]$_.repo)).Equals($repoNorm, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    $phase = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.phase)) { [string]$rule.phase } else { $defaultPhase }
    $planned = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.planned_enforce_date)) { [string]$rule.planned_enforce_date } else { "" }
    if ($phase -eq "observe" -and -not [string]::IsNullOrWhiteSpace($planned)) {
      try {
        $plannedDt = (Get-Date -Date $planned).Date
        if ($plannedDt -lt $today) {
          $overdueObserve++
        }
      } catch {
        Write-Host "[WARN] invalid planned_enforce_date: $repoNorm => $planned"
      }
    }
    if ($phase -eq "enforce") { $enforce++ } else { $observe++ }
  }
  Write-Host "rollout.default.phase=$defaultPhase"
  Write-Host "rollout.default.blockExpiredWaiver=$defaultBlock"
  Write-Host "rollout.observe=$observe"
  Write-Host "rollout.enforce=$enforce"
  Write-Host "rollout.observe_overdue=$overdueObserve"
}
