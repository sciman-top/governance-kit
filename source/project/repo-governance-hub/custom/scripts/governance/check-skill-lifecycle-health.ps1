param(
  [string]$RepoRoot = ".",
  [string]$PolicyRelativePath = ".governance/skill-lifecycle-health-policy.json",
  [string]$RegistryRelativePath = ".governance/skill-candidates/promotion-registry.json",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

function Read-Json([string]$PathText, [object]$DefaultValue) {
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return $DefaultValue }
  try {
    return (Get-Content -LiteralPath $PathText -Raw -Encoding UTF8 | ConvertFrom-Json)
  } catch {
    return $DefaultValue
  }
}

function Parse-DateOrNull([object]$Value) {
  if ($null -eq $Value) { return $null }
  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) { return $null }
  try { return [datetime]$text } catch { return $null }
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$repoWin = $repoPath -replace '/', '\'
$policyPath = Join-Path $repoWin ($PolicyRelativePath -replace '/', '\')
$registryPath = Join-Path $repoWin ($RegistryRelativePath -replace '/', '\')
$lifecycleScript = Join-Path $repoWin "scripts\governance\run-skill-lifecycle-review.ps1"

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  policy_path = ($policyPath -replace '\\', '/')
  registry_path = ($registryPath -replace '\\', '/')
  status = "unknown"
  retire_candidate_count = 0
  merge_candidate_count = 0
  retired_entry_count = 0
  retired_avg_latency_days = 0
  retired_avg_health_score = 0
  active_avg_health_score = 0
  quality_impact_delta = 0
}

$policy = Read-Json -PathText $policyPath -DefaultValue $null
if ($null -eq $policy) {
  $result.status = "missing_policy"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_lifecycle_health.status=missing_policy" }
  exit 1
}

if (-not (Test-Path -LiteralPath $lifecycleScript -PathType Leaf)) {
  $result.status = "missing_lifecycle_script"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_lifecycle_health.status=missing_lifecycle_script" }
  exit 1
}

$lifecycleRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $lifecycleScript -RepoRoot $repoWin -Mode plan -AsJson 2>&1
if ($LASTEXITCODE -ne 0) {
  $result.status = "lifecycle_plan_failed"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_lifecycle_health.status=lifecycle_plan_failed" }
  exit 1
}
$lifecycleObj = $null
try { $lifecycleObj = ($lifecycleRaw | Out-String | ConvertFrom-Json) } catch { $lifecycleObj = $null }
if ($null -eq $lifecycleObj) {
  $result.status = "lifecycle_plan_parse_error"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_lifecycle_health.status=lifecycle_plan_parse_error" }
  exit 1
}

try { $result.retire_candidate_count = [int]$lifecycleObj.retire_candidate_count } catch { $result.retire_candidate_count = 0 }
try { $result.merge_candidate_count = [int]$lifecycleObj.merge_candidate_count } catch { $result.merge_candidate_count = 0 }

$registry = Read-Json -PathText $registryPath -DefaultValue $null
if ($null -eq $registry -or $null -eq $registry.PSObject.Properties['promoted']) {
  $result.status = "missing_registry"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_lifecycle_health.status=missing_registry" }
  exit 1
}

$retiredLatencySum = 0.0
$retiredLatencyCount = 0
$retiredHealthSum = 0.0
$retiredHealthCount = 0
$activeHealthSum = 0.0
$activeHealthCount = 0
$retiredCount = 0

foreach ($entry in @($registry.promoted)) {
  if ($null -eq $entry) { continue }
  $state = ""
  if ($null -ne $entry.PSObject.Properties['lifecycle_state']) { $state = ([string]$entry.lifecycle_state).Trim().ToLowerInvariant() }

  $healthParsed = $false
  $health = 0.0
  if ($null -ne $entry.PSObject.Properties['health_score']) {
    try {
      $health = [double]$entry.health_score
      $healthParsed = $true
    } catch {
      $healthParsed = $false
    }
  }

  if ($state -eq "active" -or $state -eq "approved") {
    if ($healthParsed) {
      $activeHealthSum += $health
      $activeHealthCount++
    }
  }

  if ($state -ne "retired") { continue }
  $retiredCount++
  if ($healthParsed) {
    $retiredHealthSum += $health
    $retiredHealthCount++
  }

  $retiredAt = $null
  $promotedAt = $null
  if ($null -ne $entry.PSObject.Properties['retired_at']) { $retiredAt = Parse-DateOrNull $entry.retired_at }
  if ($null -ne $entry.PSObject.Properties['promoted_at']) { $promotedAt = Parse-DateOrNull $entry.promoted_at }
  if ($null -eq $retiredAt -or $null -eq $promotedAt) { continue }
  if ($retiredAt -lt $promotedAt) { continue }
  $retiredLatencySum += (New-TimeSpan -Start $promotedAt -End $retiredAt).TotalDays
  $retiredLatencyCount++
}

$result.retired_entry_count = [int]$retiredCount
if ($retiredLatencyCount -gt 0) {
  $result.retired_avg_latency_days = [Math]::Round(($retiredLatencySum / [double]$retiredLatencyCount), 6)
}
if ($retiredHealthCount -gt 0) {
  $result.retired_avg_health_score = [Math]::Round(($retiredHealthSum / [double]$retiredHealthCount), 6)
}
if ($activeHealthCount -gt 0) {
  $result.active_avg_health_score = [Math]::Round(($activeHealthSum / [double]$activeHealthCount), 6)
}
if ($activeHealthCount -gt 0 -and $retiredHealthCount -gt 0) {
  $result.quality_impact_delta = [Math]::Round(([double]$result.active_avg_health_score - [double]$result.retired_avg_health_score), 6)
}

$maxRetireCandidate = 20
$maxRetiredAvgLatencyDays = 365
$minQualityImpactDelta = 0.0
$blockOnRetireBacklog = $true
$blockOnLatencyViolation = $true
$blockOnQualityRegression = $true
if ($null -ne $policy.PSObject.Properties['max_retire_candidate_count']) { try { $maxRetireCandidate = [int]$policy.max_retire_candidate_count } catch {} }
if ($null -ne $policy.PSObject.Properties['max_retired_avg_latency_days']) { try { $maxRetiredAvgLatencyDays = [int]$policy.max_retired_avg_latency_days } catch {} }
if ($null -ne $policy.PSObject.Properties['min_quality_impact_delta']) { try { $minQualityImpactDelta = [double]$policy.min_quality_impact_delta } catch {} }
if ($null -ne $policy.PSObject.Properties['block_on_retire_backlog']) { $blockOnRetireBacklog = [bool]$policy.block_on_retire_backlog }
if ($null -ne $policy.PSObject.Properties['block_on_latency_violation']) { $blockOnLatencyViolation = [bool]$policy.block_on_latency_violation }
if ($null -ne $policy.PSObject.Properties['block_on_quality_regression']) { $blockOnQualityRegression = [bool]$policy.block_on_quality_regression }

$status = "ok"
$shouldFail = $false

if ($result.retire_candidate_count -gt $maxRetireCandidate) {
  $status = "retire_backlog_high"
  if ($blockOnRetireBacklog) { $shouldFail = $true }
}
if ($status -eq "ok" -and $retiredLatencyCount -gt 0 -and [double]$result.retired_avg_latency_days -gt [double]$maxRetiredAvgLatencyDays) {
  $status = "retirement_latency_high"
  if ($blockOnLatencyViolation) { $shouldFail = $true }
}
if ($status -eq "ok" -and $retiredHealthCount -gt 0 -and $activeHealthCount -gt 0 -and [double]$result.quality_impact_delta -lt [double]$minQualityImpactDelta) {
  $status = "quality_impact_negative"
  if ($blockOnQualityRegression) { $shouldFail = $true }
}

$result.status = $status

if ($AsJson) {
  $result | ConvertTo-Json -Depth 10 | Write-Output
} else {
  Write-Host ("skill_lifecycle_health.status={0}" -f $result.status)
  Write-Host ("skill_lifecycle_health.retire_candidate_count={0}" -f [int]$result.retire_candidate_count)
  Write-Host ("skill_lifecycle_health.merge_candidate_count={0}" -f [int]$result.merge_candidate_count)
  Write-Host ("skill_lifecycle_health.retired_entry_count={0}" -f [int]$result.retired_entry_count)
  Write-Host ("skill_lifecycle_health.retired_avg_latency_days={0}" -f $result.retired_avg_latency_days)
  Write-Host ("skill_lifecycle_health.quality_impact_delta={0}" -f $result.quality_impact_delta)
}

if ($shouldFail) { exit 1 }
exit 0
