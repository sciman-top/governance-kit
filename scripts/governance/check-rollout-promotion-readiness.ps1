param(
  [string]$RepoRoot = ".",
  [string]$RolloutRelativePath = "config/rule-rollout.json",
  [string]$PolicyRelativePath = ".governance/rollout-promotion-policy.json",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

function Parse-IsoDateOrNull([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  try {
    return [datetime]::ParseExact($Text.Trim(), "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
  } catch {
    return $null
  }
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$rolloutPath = Join-Path ($repoPath -replace '/', '\\') ($RolloutRelativePath -replace '/', '\\')
$policyPath = Join-Path ($repoPath -replace '/', '\\') ($PolicyRelativePath -replace '/', '\\')

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  rollout_path = ($rolloutPath -replace '\\', '/')
  policy_path = ($policyPath -replace '\\', '/')
  status = "unknown"
  minimum_observe_days_before_enforce = 14
  observe_window_violation_count = 0
  invalid_entry_count = 0
  violations = @()
}

$violations = New-Object System.Collections.Generic.List[object]

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  $result.status = "missing_policy"
  $result.invalid_entry_count = 1
  $result.violations = @([pscustomobject]@{ repo = "*"; id = "missing_policy"; reason = "rollout promotion policy file not found" })
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "rollout_promotion.status=missing_policy" }
  exit 1
}

if (-not (Test-Path -LiteralPath $rolloutPath -PathType Leaf)) {
  $result.status = "missing_rollout"
  $result.invalid_entry_count = 1
  $result.violations = @([pscustomobject]@{ repo = "*"; id = "missing_rollout"; reason = "rule-rollout.json not found" })
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "rollout_promotion.status=missing_rollout" }
  exit 1
}

$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rollout = Get-Content -LiteralPath $rolloutPath -Raw -Encoding UTF8 | ConvertFrom-Json

$minObserveDays = 14
if ($null -ne $policy.PSObject.Properties['minimum_observe_days_before_enforce']) {
  try { $minObserveDays = [int]$policy.minimum_observe_days_before_enforce } catch { $minObserveDays = 14 }
}
$result.minimum_observe_days_before_enforce = [int]$minObserveDays

$requireObserveStartedAt = $true
if ($null -ne $policy.PSObject.Properties['require_observe_started_at']) {
  $requireObserveStartedAt = [bool]$policy.require_observe_started_at
}

$requirePlannedForObserve = $true
if ($null -ne $policy.PSObject.Properties['require_planned_enforce_date_for_observe']) {
  $requirePlannedForObserve = [bool]$policy.require_planned_enforce_date_for_observe
}

$today = (Get-Date).Date

foreach ($entry in @($rollout.repos)) {
  if ($null -eq $entry) { continue }
  $repo = [string]$entry.repo
  if ([string]::IsNullOrWhiteSpace($repo)) { $repo = "<missing-repo>" }

  $phase = "observe"
  if ($null -ne $entry.PSObject.Properties['phase'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.phase)) {
    $phase = ([string]$entry.phase).Trim().ToLowerInvariant()
  }

  $startedText = if ($null -ne $entry.PSObject.Properties['observe_started_at']) { [string]$entry.observe_started_at } else { "" }
  $plannedText = if ($null -ne $entry.PSObject.Properties['planned_enforce_date']) { [string]$entry.planned_enforce_date } else { "" }
  $started = Parse-IsoDateOrNull $startedText
  $planned = Parse-IsoDateOrNull $plannedText

  if ($requireObserveStartedAt -and $null -eq $started) {
    $violations.Add([pscustomobject]@{ repo = $repo; id = "missing_observe_started_at"; reason = "observe_started_at is required (yyyy-MM-dd)" }) | Out-Null
  }

  if ($phase -eq "observe" -and $requirePlannedForObserve -and $null -eq $planned) {
    $violations.Add([pscustomobject]@{ repo = $repo; id = "missing_planned_enforce_date"; reason = "planned_enforce_date is required in observe phase (yyyy-MM-dd)" }) | Out-Null
  }

  if ($null -ne $started -and $null -ne $planned) {
    $windowDays = [int]($planned.Date - $started.Date).TotalDays
    if ($windowDays -lt $minObserveDays) {
      $violations.Add([pscustomobject]@{ repo = $repo; id = "observe_window_too_short"; reason = ("planned observe window {0}d < minimum {1}d" -f $windowDays, $minObserveDays) }) | Out-Null
    }
  }

  if ($phase -eq "enforce" -and $null -ne $started) {
    $actualObserveDays = [int]($today - $started.Date).TotalDays
    if ($actualObserveDays -lt $minObserveDays) {
      $violations.Add([pscustomobject]@{ repo = $repo; id = "enforce_too_early"; reason = ("enforce after {0}d observe < minimum {1}d" -f $actualObserveDays, $minObserveDays) }) | Out-Null
    }
  }
}

$result.violations = @($violations.ToArray())
$result.observe_window_violation_count = @($result.violations).Count
$result.invalid_entry_count = @($result.violations).Count
$result.status = if ($result.observe_window_violation_count -gt 0) { "violation" } else { "ok" }

if ($AsJson) {
  $result | ConvertTo-Json -Depth 12 | Write-Output
} else {
  Write-Host ("rollout_promotion.status={0}" -f $result.status)
  Write-Host ("rollout_promotion.minimum_observe_days_before_enforce={0}" -f [int]$result.minimum_observe_days_before_enforce)
  Write-Host ("rollout_promotion.observe_window_violation_count={0}" -f [int]$result.observe_window_violation_count)
}

if ([string]$result.status -ne "ok") { exit 1 }
exit 0
