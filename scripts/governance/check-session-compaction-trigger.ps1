param(
  [string]$RepoRoot = ".",
  [string]$PolicyRelativePath = ".governance/session-compaction-trigger-policy.json",
  [string]$MetricsRelativePath = "docs/governance/metrics-auto.md",
  [string]$ClarificationStateRelativePath = ".codex/clarification",
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

function Parse-KeyValueMap([string]$PathText) {
  $map = @{}
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return $map }
  foreach ($line in @(Get-Content -LiteralPath $PathText -Encoding UTF8)) {
    $text = [string]$line
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    if ($text.TrimStart().StartsWith("#")) { continue }
    $idx = $text.IndexOf("=")
    if ($idx -lt 1) { continue }
    $k = $text.Substring(0, $idx).Trim()
    $v = $text.Substring($idx + 1).Trim()
    if (-not [string]::IsNullOrWhiteSpace($k)) { $map[$k] = $v }
  }
  return $map
}

function Parse-IntOrNull([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  if ($Text -eq "N/A") { return $null }
  $v = 0
  if ([int]::TryParse($Text, [ref]$v)) { return [int]$v }
  return $null
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$repoWin = $repoPath -replace '/', '\'
$policyPath = Join-Path $repoWin ($PolicyRelativePath -replace '/', '\')
$metricsPath = Join-Path $repoWin ($MetricsRelativePath -replace '/', '\')
$clarificationStatePath = Join-Path $repoWin ($ClarificationStateRelativePath -replace '/', '\')

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  policy_path = ($policyPath -replace '\\', '/')
  metrics_path = ($metricsPath -replace '\\', '/')
  clarification_state_path = ($clarificationStatePath -replace '\\', '/')
  status = "unknown"
  recommend_compaction = $false
  reason_count = 0
  reasons = @()
  signals = [ordered]@{
    average_response_token = $null
    single_task_token = $null
    max_issue_attempt_count = 0
    clarification_required_open_count = 0
    issue_state_file_count = 0
  }
}

$policy = Read-Json -PathText $policyPath -DefaultValue $null
if ($null -eq $policy) {
  $result.status = "missing_policy"
  if ($AsJson) { $result | ConvertTo-Json -Depth 12 | Write-Output } else { Write-Host "session_compaction.status=missing_policy" }
  exit 0
}

$enabled = $true
if ($null -ne $policy.PSObject.Properties['enabled']) { $enabled = [bool]$policy.enabled }
if (-not $enabled) {
  $result.status = "disabled"
  if ($AsJson) { $result | ConvertTo-Json -Depth 12 | Write-Output } else { Write-Host "session_compaction.status=disabled" }
  exit 0
}

$triggerWhenAny = $true
if ($null -ne $policy.PSObject.Properties['trigger_when_any']) { $triggerWhenAny = [bool]$policy.trigger_when_any }

$maxAverageResponseToken = 1200
$maxSingleTaskToken = 8000
$maxIssueAttemptCount = 2
$maxClarificationRequiredOpenCount = 1

if ($null -ne $policy.PSObject.Properties['thresholds']) {
  $thresholds = $policy.thresholds
  if ($null -ne $thresholds.PSObject.Properties['max_average_response_token']) {
    try { $maxAverageResponseToken = [int]$thresholds.max_average_response_token } catch {}
  }
  if ($null -ne $thresholds.PSObject.Properties['max_single_task_token']) {
    try { $maxSingleTaskToken = [int]$thresholds.max_single_task_token } catch {}
  }
  if ($null -ne $thresholds.PSObject.Properties['max_issue_attempt_count']) {
    try { $maxIssueAttemptCount = [int]$thresholds.max_issue_attempt_count } catch {}
  }
  if ($null -ne $thresholds.PSObject.Properties['max_clarification_required_open_count']) {
    try { $maxClarificationRequiredOpenCount = [int]$thresholds.max_clarification_required_open_count } catch {}
  }
}

$kv = Parse-KeyValueMap -PathText $metricsPath
$avgResponseToken = Parse-IntOrNull -Text ([string]$kv["average_response_token"])
$singleTaskToken = Parse-IntOrNull -Text ([string]$kv["single_task_token"])

$result.signals.average_response_token = $avgResponseToken
$result.signals.single_task_token = $singleTaskToken

$maxAttempt = 0
$clarificationRequiredOpenCount = 0
$stateFileCount = 0
if (Test-Path -LiteralPath $clarificationStatePath -PathType Container) {
  $stateFiles = @(Get-ChildItem -LiteralPath $clarificationStatePath -File -Filter "*.json" -ErrorAction SilentlyContinue)
  $stateFileCount = $stateFiles.Count
  foreach ($stateFile in $stateFiles) {
    $stateObj = Read-Json -PathText $stateFile.FullName -DefaultValue $null
    if ($null -eq $stateObj) { continue }
    $attempt = 0
    if ($null -ne $stateObj.PSObject.Properties['attempt_count']) {
      try { $attempt = [int]$stateObj.attempt_count } catch { $attempt = 0 }
    }
    if ($attempt -gt $maxAttempt) { $maxAttempt = $attempt }
    if ($null -ne $stateObj.PSObject.Properties['clarification_required'] -and [bool]$stateObj.clarification_required) {
      $clarificationRequiredOpenCount++
    }
  }
}

$result.signals.max_issue_attempt_count = [int]$maxAttempt
$result.signals.clarification_required_open_count = [int]$clarificationRequiredOpenCount
$result.signals.issue_state_file_count = [int]$stateFileCount

$checks = @()
if ($null -ne $avgResponseToken) {
  $checks += [pscustomobject]@{
    hit = ([int]$avgResponseToken -gt [int]$maxAverageResponseToken)
    reason = ("average_response_token>{0}" -f [int]$maxAverageResponseToken)
  }
}
if ($null -ne $singleTaskToken) {
  $checks += [pscustomobject]@{
    hit = ([int]$singleTaskToken -gt [int]$maxSingleTaskToken)
    reason = ("single_task_token>{0}" -f [int]$maxSingleTaskToken)
  }
}
$checks += [pscustomobject]@{
  hit = ([int]$maxAttempt -ge [int]$maxIssueAttemptCount)
  reason = ("max_issue_attempt_count>={0}" -f [int]$maxIssueAttemptCount)
}
$checks += [pscustomobject]@{
  hit = ([int]$clarificationRequiredOpenCount -ge [int]$maxClarificationRequiredOpenCount)
  reason = ("clarification_required_open_count>={0}" -f [int]$maxClarificationRequiredOpenCount)
}

$hitReasons = New-Object System.Collections.Generic.List[string]
foreach ($check in $checks) {
  if ([bool]$check.hit) { $hitReasons.Add([string]$check.reason) | Out-Null }
}

$recommend = $false
if ($triggerWhenAny) {
  $recommend = ($hitReasons.Count -gt 0)
} else {
  $recommend = ($checks.Count -gt 0 -and $hitReasons.Count -eq $checks.Count)
}

$result.recommend_compaction = [bool]$recommend
$result.reason_count = [int]$hitReasons.Count
$result.reasons = @($hitReasons.ToArray())
$result.status = if ($recommend) { "recommend_compact" } else { "ok" }

if ($AsJson) {
  $result | ConvertTo-Json -Depth 12 | Write-Output
} else {
  Write-Host ("session_compaction.status={0}" -f $result.status)
  Write-Host ("session_compaction.recommend={0}" -f $result.recommend_compaction)
  Write-Host ("session_compaction.reason_count={0}" -f $result.reason_count)
  Write-Host ("session_compaction.reasons={0}" -f (@($result.reasons) -join ";"))
}

exit 0

