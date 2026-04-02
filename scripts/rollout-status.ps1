param(
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$reposPath = Join-Path $kitRoot "config\repositories.json"
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

if (!(Test-Path $rolloutPath)) {
  throw "rule-rollout.json not found: $rolloutPath"
}

$repos = @(Read-JsonArray $reposPath)
$rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
$defaultPhase = [string]$rollout.default.phase
$defaultBlock = [bool]$rollout.default.blockExpiredWaiver
$rules = @($rollout.repos)

$observe = 0
$enforce = 0
$overdueObserve = 0
$today = (Get-Date).Date
$warnings = [System.Collections.Generic.List[string]]::new()
$repoEntries = [System.Collections.Generic.List[object]]::new()

foreach ($repoRaw in $repos) {
  $repo = Normalize-Repo ([string]$repoRaw)
  $rule = $rules | Where-Object { (Normalize-Repo ([string]$_.repo)).Equals($repo, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
  $phase = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.phase)) { [string]$rule.phase } else { $defaultPhase }
  $block = if ($null -ne $rule -and $null -ne $rule.blockExpiredWaiver) { [bool]$rule.blockExpiredWaiver } else { $defaultBlock }
  $planned = if ($null -ne $rule -and -not [string]::IsNullOrWhiteSpace([string]$rule.planned_enforce_date)) { [string]$rule.planned_enforce_date } else { "" }
  $overdue = $false
  if ($phase -eq "observe" -and -not [string]::IsNullOrWhiteSpace($planned)) {
    $plannedDt = Parse-IsoDate $planned
    if ($null -eq $plannedDt) {
      [void]$warnings.Add("invalid planned_enforce_date: $repo => $planned (expected yyyy-MM-dd)")
    } elseif ($plannedDt.Date -lt $today) {
      $overdue = $true
      $overdueObserve++
    }
  }

  if ($phase -eq "enforce") { $enforce++ } else { $observe++ }

  [void]$repoEntries.Add([pscustomobject]@{
    repo = $repo
    phase = $phase
    block_expired_waiver = $block
    planned_enforce_date = if ([string]::IsNullOrWhiteSpace($planned)) { $null } else { $planned }
    overdue = [bool]$overdue
  })
}

$result = [pscustomobject]@{
  schema_version = "1.0"
  default_phase = $defaultPhase
  default_block_expired_waiver = $defaultBlock
  observe = $observe
  enforce = $enforce
  observe_overdue = $overdueObserve
  repos = @($repoEntries)
  warnings = @($warnings)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  return
}

Write-Host "governance rollout status"
Write-Host "default.phase=$defaultPhase"
Write-Host "default.blockExpiredWaiver=$defaultBlock"
foreach ($w in $warnings) {
  Write-Host "[WARN] $w"
}
foreach ($repoItem in $repoEntries) {
  if ($null -eq $repoItem.planned_enforce_date) {
    Write-Host "- $($repoItem.repo) : phase=$($repoItem.phase) blockExpiredWaiver=$($repoItem.block_expired_waiver)"
  } else {
    Write-Host "- $($repoItem.repo) : phase=$($repoItem.phase) blockExpiredWaiver=$($repoItem.block_expired_waiver) planned_enforce_date=$($repoItem.planned_enforce_date) overdue=$($repoItem.overdue)"
  }
}
Write-Host "phase.observe=$observe"
Write-Host "phase.enforce=$enforce"
Write-Host "phase.observe_overdue=$overdueObserve"
