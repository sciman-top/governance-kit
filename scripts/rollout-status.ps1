$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$reposPath = Join-Path $kitRoot "config\repositories.json"
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

if (!(Test-Path $rolloutPath)) {
  throw "rule-rollout.json not found: $rolloutPath"
}

$repos = Read-JsonArray $reposPath
$rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
$defaultPhase = [string]$rollout.default.phase
$defaultBlock = [bool]$rollout.default.blockExpiredWaiver
$rules = @($rollout.repos)

$observe = 0
$enforce = 0
$overdueObserve = 0
$today = (Get-Date).Date

Write-Host "governance rollout status"
Write-Host "default.phase=$defaultPhase"
Write-Host "default.blockExpiredWaiver=$defaultBlock"

foreach ($repoRaw in $repos) {
  $repo = Normalize-Repo ([string]$repoRaw)
  $rule = $rules | Where-Object { (Normalize-Repo ([string]$_.repo)).Equals($repo, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
  $phase = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.phase)) { [string]$rule.phase } else { $defaultPhase }
  $block = if ($null -ne $rule -and $null -ne $rule.blockExpiredWaiver) { [bool]$rule.blockExpiredWaiver } else { $defaultBlock }
  $planned = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.planned_enforce_date)) { [string]$rule.planned_enforce_date } else { "" }
  $overdue = $false
  if ($phase -eq "observe" -and -not [string]::IsNullOrWhiteSpace($planned)) {
    try {
      $plannedDt = (Get-Date -Date $planned).Date
      if ($plannedDt -lt $today) {
        $overdue = $true
        $overdueObserve++
      }
    } catch {
      Write-Host "[WARN] invalid planned_enforce_date: $repo => $planned"
    }
  }

  if ($phase -eq "enforce") { $enforce++ } else { $observe++ }
  if ([string]::IsNullOrWhiteSpace($planned)) {
    Write-Host "- $repo : phase=$phase blockExpiredWaiver=$block"
  } else {
    Write-Host "- $repo : phase=$phase blockExpiredWaiver=$block planned_enforce_date=$planned overdue=$overdue"
  }
}

Write-Host "phase.observe=$observe"
Write-Host "phase.enforce=$enforce"
Write-Host "phase.observe_overdue=$overdueObserve"
