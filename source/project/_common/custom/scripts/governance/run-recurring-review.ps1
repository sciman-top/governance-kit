param(
  [string]$RepoRoot = ".",
  [switch]$NoNotifyOnAlert,
  [switch]$NoAlertSnapshot,
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$kitRoot = $repoPath
$notifyOnAlert = -not $NoNotifyOnAlert.IsPresent
$writeAlertSnapshot = -not $NoAlertSnapshot.IsPresent
$commonPath = Join-Path $kitRoot "scripts\lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$doctorScript = Join-Path $kitRoot "scripts\doctor.ps1"
$rolloutScript = Join-Path $kitRoot "scripts\rollout-status.ps1"
$waiverScript = Join-Path $kitRoot "scripts\check-waivers.ps1"
$metricsScript = Join-Path $kitRoot "scripts\collect-governance-metrics.ps1"
$triggerScript = Join-Path $kitRoot "scripts\governance\check-update-triggers.ps1"
$skillTriggerEvalScript = Join-Path $kitRoot "scripts\governance\check-skill-trigger-evals.ps1"
$skillLifecycleScript = Join-Path $kitRoot "scripts\governance\run-skill-lifecycle-review.ps1"
$tokenBalanceScript = Join-Path $kitRoot "scripts\governance\check-token-balance.ps1"
$externalBaselineScript = Join-Path $kitRoot "scripts\governance\check-external-baselines.ps1"
$requiredScripts = @($doctorScript, $rolloutScript, $waiverScript, $metricsScript, $triggerScript)
foreach ($script in $requiredScripts) {
  if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    throw "Missing recurring review dependency: $script"
  }
}
$hasExternalBaselineScript = (Test-Path -LiteralPath $externalBaselineScript -PathType Leaf)
$hasTokenBalanceScript = (Test-Path -LiteralPath $tokenBalanceScript -PathType Leaf)
$hasSkillTriggerEvalScript = (Test-Path -LiteralPath $skillTriggerEvalScript -PathType Leaf)
$hasSkillLifecycleScript = (Test-Path -LiteralPath $skillLifecycleScript -PathType Leaf)

$psExe = Get-CurrentPowerShellPath

function Invoke-StepText([string]$Name, [string]$ScriptPath, [string[]]$Args) {
  $captured = & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Args 2>&1
  $exitCode = $LASTEXITCODE
  $text = ($captured | Out-String).Trim()
  return [pscustomobject]@{
    name = $Name
    exit_code = [int]$exitCode
    output = $text
  }
}

function Parse-JsonLoose([string]$RawText) {
  if ([string]::IsNullOrWhiteSpace($RawText)) { return $null }
  try {
    return ($RawText | ConvertFrom-Json)
  } catch {
    $start = $RawText.IndexOf("{")
    $end = $RawText.LastIndexOf("}")
    if ($start -ge 0 -and $end -ge $start) {
      try {
        return ($RawText.Substring($start, $end - $start + 1) | ConvertFrom-Json)
      } catch {
        return $null
      }
    }
  }
  return $null
}

function Write-AlertSnapshot([object]$ReviewResult, [string]$RootPath) {
  $docsDir = Join-Path $RootPath "docs\governance"
  if (-not (Test-Path -LiteralPath $docsDir -PathType Container)) {
    New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
  }
  $snapshotPath = Join-Path $docsDir "alerts-latest.md"
  $status = if ($ReviewResult.ok) { "OK" } else { "ALERT" }
  $lines = [System.Collections.Generic.List[string]]::new()
  [void]$lines.Add(("generated_at={0}" -f $ReviewResult.generated_at))
  [void]$lines.Add(("repo_root={0}" -f $ReviewResult.repo_root))
  [void]$lines.Add(("status={0}" -f $status))
  [void]$lines.Add(("doctor_health={0}" -f $ReviewResult.summary.doctor_health))
  [void]$lines.Add(("observe_overdue={0}" -f $ReviewResult.summary.observe_overdue))
  [void]$lines.Add(("waiver_remind_count={0}" -f $ReviewResult.summary.waiver_remind_count))
  [void]$lines.Add(("waiver_block_count={0}" -f $ReviewResult.summary.waiver_block_count))
  [void]$lines.Add(("release_distribution_policy_drift_count={0}" -f $ReviewResult.summary.release_distribution_policy_drift_count))
  if (@($ReviewResult.alerts).Count -gt 0) {
    [void]$lines.Add("alerts=")
    foreach ($a in @($ReviewResult.alerts)) {
      [void]$lines.Add(("- " + [string]$a))
    }
  } else {
    [void]$lines.Add("alerts=none")
  }
  Set-Content -LiteralPath $snapshotPath -Value ($lines -join "`r`n") -Encoding UTF8
  return $snapshotPath
}

$doctor = Invoke-StepText -Name "doctor" -ScriptPath $doctorScript -Args @()
$rollout = Invoke-StepText -Name "rollout-status" -ScriptPath $rolloutScript -Args @()
$waiver = Invoke-StepText -Name "check-waivers" -ScriptPath $waiverScript -Args @()
$metrics = Invoke-StepText -Name "collect-governance-metrics" -ScriptPath $metricsScript -Args @()
$trigger = Invoke-StepText -Name "check-update-triggers" -ScriptPath $triggerScript -Args @("-RepoRoot", $repoPath, "-AsJson")
if ($hasSkillTriggerEvalScript) {
  $skillTriggerEval = Invoke-StepText -Name "check-skill-trigger-evals" -ScriptPath $skillTriggerEvalScript -Args @("-RepoRoot", $repoPath, "-AsJson")
} else {
  $skillTriggerEval = [pscustomobject]@{
    name = "check-skill-trigger-evals"
    exit_code = 0
    output = ""
  }
}
if ($hasSkillLifecycleScript) {
  $skillLifecycle = Invoke-StepText -Name "run-skill-lifecycle-review" -ScriptPath $skillLifecycleScript -Args @("-RepoRoot", $repoPath, "-Mode", "plan", "-AsJson")
} else {
  $skillLifecycle = [pscustomobject]@{
    name = "run-skill-lifecycle-review"
    exit_code = 0
    output = ""
  }
}
if ($hasTokenBalanceScript) {
  $tokenBalance = Invoke-StepText -Name "check-token-balance" -ScriptPath $tokenBalanceScript -Args @("-RepoRoot", $repoPath)
} else {
  $tokenBalance = [pscustomobject]@{
    name = "check-token-balance"
    exit_code = 0
    output = ""
  }
}
if ($hasExternalBaselineScript) {
  $externalBaseline = Invoke-StepText -Name "check-external-baselines" -ScriptPath $externalBaselineScript -Args @("-RepoRoot", $repoPath, "-AsJson")
} else {
  $externalBaseline = [pscustomobject]@{
    name = "check-external-baselines"
    exit_code = 0
    output = ""
  }
}

$alerts = [System.Collections.Generic.List[string]]::new()
$doctorHealth = "UNKNOWN"
$observeOverdue = -1

if (-not [string]::IsNullOrWhiteSpace($doctor.output)) {
  $m = [regex]::Match($doctor.output, "(?m)^HEALTH=([A-Z]+)\s*$")
  if ($m.Success) {
    $doctorHealth = $m.Groups[1].Value
  }
}
if (-not [string]::IsNullOrWhiteSpace($rollout.output)) {
  $m = [regex]::Match($rollout.output, "(?m)^phase\.observe_overdue=([0-9]+)\s*$")
  if ($m.Success) {
    $observeOverdue = [int]$m.Groups[1].Value
  }
}

if ($doctor.exit_code -ne 0) {
  [void]$alerts.Add("doctor failed")
}
if (($doctorHealth).ToUpperInvariant() -ne "GREEN") {
  [void]$alerts.Add("doctor health is not GREEN")
}

if ($rollout.exit_code -ne 0) {
  [void]$alerts.Add("rollout-status failed")
}
if ($observeOverdue -gt 0) {
  [void]$alerts.Add(("observe_overdue={0}" -f $observeOverdue))
}

$waiverRemindCount = 0
$waiverBlockCount = 0
if (-not [string]::IsNullOrWhiteSpace($waiver.output)) {
  $waiverRemindCount = ([regex]::Matches($waiver.output, "(?m)^\[REMIND\]")).Count
  $waiverBlockCount = ([regex]::Matches($waiver.output, "(?m)^\[BLOCK\]")).Count
}
if ($waiver.exit_code -ne 0 -or $waiverBlockCount -gt 0) {
  [void]$alerts.Add(("waiver blocked count={0}" -f $waiverBlockCount))
}
if ($waiverRemindCount -gt 0) {
  [void]$alerts.Add(("waiver remind count={0}" -f $waiverRemindCount))
}

if ($metrics.exit_code -ne 0) {
  [void]$alerts.Add("collect-governance-metrics failed")
}

if ($hasSkillTriggerEvalScript) {
  $skillTriggerEvalStatus = "UNKNOWN"
  if (-not [string]::IsNullOrWhiteSpace($skillTriggerEval.output)) {
    $skillEvalObj = Parse-JsonLoose -RawText ([string]$skillTriggerEval.output)
    if ($null -ne $skillEvalObj) {
      if ($skillEvalObj.PSObject.Properties.Name -contains "status") {
        $skillTriggerEvalStatus = [string]$skillEvalObj.status
      }
      if ($skillEvalObj.PSObject.Properties.Name -contains "validation_pass_rate") {
        try { $skillTriggerEvalValidationPassRate = [double]$skillEvalObj.validation_pass_rate } catch { $skillTriggerEvalValidationPassRate = $null }
      }
      if ($skillEvalObj.PSObject.Properties.Name -contains "validation_false_trigger_rate") {
        try { $skillTriggerEvalValidationFalseTriggerRate = [double]$skillEvalObj.validation_false_trigger_rate } catch { $skillTriggerEvalValidationFalseTriggerRate = $null }
      }
      if ($skillEvalObj.PSObject.Properties.Name -contains "grouped_query_count") {
        try { $skillTriggerEvalGroupedQueryCount = [int]$skillEvalObj.grouped_query_count } catch { $skillTriggerEvalGroupedQueryCount = 0 }
      }
    } else {
      $skillTriggerEvalStatus = "PARSE_ERROR"
    }
  }
  if ($skillTriggerEval.exit_code -ne 0 -or $skillTriggerEvalStatus -eq "PARSE_ERROR") {
    [void]$alerts.Add(("skill trigger eval status={0} grouped_query_count={1}" -f $skillTriggerEvalStatus, $skillTriggerEvalGroupedQueryCount))
  }
}

$updateTriggerAlertCount = 0
$orphanCustomSourceCount = 0
$releaseDistributionPolicyDriftCount = 0
$tokenBalanceStatus = "UNKNOWN"
$tokenBalanceWarningCount = 0
$tokenBalanceViolationCount = 0
$externalBaselineStatus = "UNKNOWN"
$externalBaselineAdvisoryCount = 0
$externalBaselineWarnCount = 0
$skillTriggerEvalStatus = "UNAVAILABLE"
$skillTriggerEvalGroupedQueryCount = 0
$skillTriggerEvalValidationPassRate = $null
$skillTriggerEvalValidationFalseTriggerRate = $null
$skillLifecycleStatus = "UNAVAILABLE"
$skillLifecycleMergeCandidateCount = 0
$skillLifecycleRetireCandidateCount = 0
$skillLifecycleAppliedMergeCount = 0
$skillLifecycleAppliedRetireCount = 0
if ($trigger.exit_code -ne 0) {
  $triggerObj = $null
  $rawTriggerText = [string]$trigger.output
  if (-not [string]::IsNullOrWhiteSpace($trigger.output)) {
    try {
      $triggerObj = $trigger.output | ConvertFrom-Json
    } catch {
      $triggerObj = $null
    }
  }
  if ($null -ne $triggerObj -and $triggerObj.PSObject.Properties.Name -contains "alert_count") {
    $updateTriggerAlertCount = [int]$triggerObj.alert_count
  }
  if ($null -ne $triggerObj -and $triggerObj.PSObject.Properties.Name -contains "orphan_custom_source_count") {
    $orphanCustomSourceCount = [int]$triggerObj.orphan_custom_source_count
  }
  if ($null -ne $triggerObj -and $triggerObj.PSObject.Properties.Name -contains "release_distribution_policy_drift_count") {
    $releaseDistributionPolicyDriftCount = [int]$triggerObj.release_distribution_policy_drift_count
  }
  if ($null -eq $triggerObj) {
    $alertCountMatch = [regex]::Match($rawTriggerText, "(?m)^alert_count=([0-9]+)\s*$")
    $orphanCountMatch = [regex]::Match($rawTriggerText, "(?m)^orphan_custom_source_count=([0-9]+)\s*$")
    $driftCountMatch = [regex]::Match($rawTriggerText, "(?m)^release_distribution_policy_drift_count=([0-9]+)\s*$")
    if ($alertCountMatch.Success) {
      $updateTriggerAlertCount = [int]$alertCountMatch.Groups[1].Value
    }
    if ($orphanCountMatch.Success) {
      $orphanCustomSourceCount = [int]$orphanCountMatch.Groups[1].Value
    }
    if ($driftCountMatch.Success) {
      $releaseDistributionPolicyDriftCount = [int]$driftCountMatch.Groups[1].Value
    }
  }
  if ($updateTriggerAlertCount -gt 0) {
    [void]$alerts.Add(("update triggers alert count={0}" -f $updateTriggerAlertCount))
  } else {
    [void]$alerts.Add("check-update-triggers failed")
  }
}

if (-not $hasTokenBalanceScript) {
  $tokenBalanceStatus = "UNAVAILABLE"
} elseif (-not [string]::IsNullOrWhiteSpace($tokenBalance.output)) {
  $rawTokenBalanceText = [string]$tokenBalance.output
  $statusMatch = [regex]::Match($rawTokenBalanceText, "(?m)^token_balance\.status=([A-Z_]+)\s*$")
  $warningMatch = [regex]::Match($rawTokenBalanceText, "(?m)^token_balance\.warning_count=([0-9]+)\s*$")
  $violationMatch = [regex]::Match($rawTokenBalanceText, "(?m)^token_balance\.violation_count=([0-9]+)\s*$")
  if ($statusMatch.Success) {
    $tokenBalanceStatus = $statusMatch.Groups[1].Value
  }
  if ($warningMatch.Success) {
    $tokenBalanceWarningCount = [int]$warningMatch.Groups[1].Value
  }
  if ($violationMatch.Success) {
    $tokenBalanceViolationCount = [int]$violationMatch.Groups[1].Value
  } else {
    $tokenBalanceObj = Parse-JsonLoose -RawText $rawTokenBalanceText
    if ($null -ne $tokenBalanceObj) {
      if ($tokenBalanceObj.PSObject.Properties.Name -contains "status") {
        $tokenBalanceStatus = [string]$tokenBalanceObj.status
      }
      if ($tokenBalanceObj.PSObject.Properties.Name -contains "warning_count") {
        $tokenBalanceWarningCount = [int]$tokenBalanceObj.warning_count
      }
      if ($tokenBalanceObj.PSObject.Properties.Name -contains "violation_count") {
        $tokenBalanceViolationCount = [int]$tokenBalanceObj.violation_count
      }
    }
  }
}

if ($hasTokenBalanceScript -and ($tokenBalance.exit_code -ne 0 -or $tokenBalanceViolationCount -gt 0 -or $tokenBalanceStatus -eq "ALERT")) {
  [void]$alerts.Add(("token balance status={0} violation_count={1}" -f $tokenBalanceStatus, $tokenBalanceViolationCount))
}

if ($hasSkillLifecycleScript) {
  if ($skillLifecycle.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($skillLifecycle.output)) {
    $lifecycleObj = Parse-JsonLoose -RawText ([string]$skillLifecycle.output)
    if ($null -ne $lifecycleObj) {
      if ($lifecycleObj.PSObject.Properties.Name -contains "status") {
        $skillLifecycleStatus = [string]$lifecycleObj.status
      }
      if ($lifecycleObj.PSObject.Properties.Name -contains "merge_candidate_count") {
        try { $skillLifecycleMergeCandidateCount = [int]$lifecycleObj.merge_candidate_count } catch { $skillLifecycleMergeCandidateCount = 0 }
      }
      if ($lifecycleObj.PSObject.Properties.Name -contains "retire_candidate_count") {
        try { $skillLifecycleRetireCandidateCount = [int]$lifecycleObj.retire_candidate_count } catch { $skillLifecycleRetireCandidateCount = 0 }
      }
      if ($lifecycleObj.PSObject.Properties.Name -contains "applied_merge_count") {
        try { $skillLifecycleAppliedMergeCount = [int]$lifecycleObj.applied_merge_count } catch { $skillLifecycleAppliedMergeCount = 0 }
      }
      if ($lifecycleObj.PSObject.Properties.Name -contains "applied_retire_count") {
        try { $skillLifecycleAppliedRetireCount = [int]$lifecycleObj.applied_retire_count } catch { $skillLifecycleAppliedRetireCount = 0 }
      }
    } else {
      $skillLifecycleStatus = "PARSE_ERROR"
    }
  }
  if ($skillLifecycle.exit_code -ne 0 -or $skillLifecycleStatus -eq "PARSE_ERROR") {
    [void]$alerts.Add(("skill lifecycle review status={0}" -f $skillLifecycleStatus))
  }
}

if (-not $hasExternalBaselineScript) {
  $externalBaselineStatus = "UNAVAILABLE"
} elseif ($externalBaseline.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($externalBaseline.output)) {
  $externalObj = $null
  $rawText = [string]$externalBaseline.output
  try {
    $externalObj = $rawText | ConvertFrom-Json
  } catch {
    $start = $rawText.IndexOf("{")
    $end = $rawText.LastIndexOf("}")
    if ($start -ge 0 -and $end -ge $start) {
      try {
        $externalObj = $rawText.Substring($start, $end - $start + 1) | ConvertFrom-Json
      } catch {
        $externalObj = $null
      }
    }
  }
  if ($null -ne $externalObj) {
    if ($externalObj.PSObject.Properties.Name -contains "status") {
      $externalBaselineStatus = [string]$externalObj.status
    }
    if ($null -ne $externalObj.summary -and $externalObj.summary.PSObject.Properties.Name -contains "advisory_count") {
      $externalBaselineAdvisoryCount = [int]$externalObj.summary.advisory_count
    }
    if ($null -ne $externalObj.summary -and $externalObj.summary.PSObject.Properties.Name -contains "warn_count") {
      $externalBaselineWarnCount = [int]$externalObj.summary.warn_count
    }
  } else {
    $statusMatch = [regex]::Match($rawText, "(?m)^status=([A-Z]+)\s*$")
    $advisoryMatch = [regex]::Match($rawText, "(?m)^advisory_count=([0-9]+)\s*$")
    $warnMatch = [regex]::Match($rawText, "(?m)^warn_count=([0-9]+)\s*$")
    if ($statusMatch.Success) {
      $externalBaselineStatus = $statusMatch.Groups[1].Value
      if ($advisoryMatch.Success) {
        $externalBaselineAdvisoryCount = [int]$advisoryMatch.Groups[1].Value
      }
      if ($warnMatch.Success) {
        $externalBaselineWarnCount = [int]$warnMatch.Groups[1].Value
      }
    } else {
      $externalBaselineStatus = "PARSE_ERROR"
    }
  }
}

$result = [pscustomobject]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  repo_root = ($repoPath -replace '\\', '/')
  cadence = "weekly"
  ok = ($alerts.Count -eq 0)
  alerts = @($alerts)
  summary = [pscustomobject]@{
    doctor_exit_code = [int]$doctor.exit_code
    doctor_health = $doctorHealth
    observe_overdue = $observeOverdue
    waiver_remind_count = [int]$waiverRemindCount
    waiver_block_count = [int]$waiverBlockCount
    metrics_exit_code = [int]$metrics.exit_code
    update_trigger_alert_count = [int]$updateTriggerAlertCount
    orphan_custom_source_count = [int]$orphanCustomSourceCount
    release_distribution_policy_drift_count = [int]$releaseDistributionPolicyDriftCount
    token_balance_status = $tokenBalanceStatus
    token_balance_warning_count = [int]$tokenBalanceWarningCount
    token_balance_violation_count = [int]$tokenBalanceViolationCount
    external_baseline_status = $externalBaselineStatus
    external_baseline_advisory_count = [int]$externalBaselineAdvisoryCount
    external_baseline_warn_count = [int]$externalBaselineWarnCount
    skill_trigger_eval_status = $skillTriggerEvalStatus
    skill_trigger_eval_grouped_query_count = [int]$skillTriggerEvalGroupedQueryCount
    skill_trigger_eval_validation_pass_rate = $skillTriggerEvalValidationPassRate
    skill_trigger_eval_validation_false_trigger_rate = $skillTriggerEvalValidationFalseTriggerRate
    skill_lifecycle_status = $skillLifecycleStatus
    skill_lifecycle_merge_candidate_count = [int]$skillLifecycleMergeCandidateCount
    skill_lifecycle_retire_candidate_count = [int]$skillLifecycleRetireCandidateCount
    skill_lifecycle_applied_merge_count = [int]$skillLifecycleAppliedMergeCount
    skill_lifecycle_applied_retire_count = [int]$skillLifecycleAppliedRetireCount
    update_trigger_exit_code = [int]$trigger.exit_code
    skill_trigger_eval_exit_code = [int]$skillTriggerEval.exit_code
    skill_lifecycle_exit_code = [int]$skillLifecycle.exit_code
    token_balance_exit_code = [int]$tokenBalance.exit_code
    external_baseline_exit_code = [int]$externalBaseline.exit_code
  }
  steps = @(
    [pscustomobject]@{ name = "doctor"; exit_code = [int]$doctor.exit_code },
    [pscustomobject]@{ name = "rollout-status"; exit_code = [int]$rollout.exit_code },
    [pscustomobject]@{ name = "check-waivers"; exit_code = [int]$waiver.exit_code },
    [pscustomobject]@{ name = "collect-governance-metrics"; exit_code = [int]$metrics.exit_code },
    [pscustomobject]@{ name = "check-update-triggers"; exit_code = [int]$trigger.exit_code },
    [pscustomobject]@{ name = "check-skill-trigger-evals"; exit_code = [int]$skillTriggerEval.exit_code },
    [pscustomobject]@{ name = "run-skill-lifecycle-review"; exit_code = [int]$skillLifecycle.exit_code },
    [pscustomobject]@{ name = "check-token-balance"; exit_code = [int]$tokenBalance.exit_code },
    [pscustomobject]@{ name = "check-external-baselines"; exit_code = [int]$externalBaseline.exit_code }
  )
}

$alertSnapshotPath = ""
if ($writeAlertSnapshot) {
  $alertSnapshotPath = Write-AlertSnapshot -ReviewResult $result -RootPath $repoPath
}
$result | Add-Member -NotePropertyName alert_snapshot_path -NotePropertyValue ($alertSnapshotPath -replace '\\', '/') -Force

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  if ($result.ok) { exit 0 } else { exit 1 }
}

Write-Host "RECURRING_REVIEW"
Write-Host ("generated_at={0}" -f $result.generated_at)
Write-Host ("repo_root={0}" -f $result.repo_root)
Write-Host ("cadence={0}" -f $result.cadence)
Write-Host ("doctor_health={0}" -f $result.summary.doctor_health)
Write-Host ("observe_overdue={0}" -f $result.summary.observe_overdue)
Write-Host ("waiver_remind_count={0}" -f $result.summary.waiver_remind_count)
Write-Host ("waiver_block_count={0}" -f $result.summary.waiver_block_count)
Write-Host ("update_trigger_alert_count={0}" -f $result.summary.update_trigger_alert_count)
Write-Host ("orphan_custom_source_count={0}" -f $result.summary.orphan_custom_source_count)
Write-Host ("release_distribution_policy_drift_count={0}" -f $result.summary.release_distribution_policy_drift_count)
Write-Host ("token_balance_status={0}" -f $result.summary.token_balance_status)
Write-Host ("token_balance_warning_count={0}" -f $result.summary.token_balance_warning_count)
Write-Host ("token_balance_violation_count={0}" -f $result.summary.token_balance_violation_count)
Write-Host ("external_baseline_status={0}" -f $result.summary.external_baseline_status)
Write-Host ("external_baseline_advisory_count={0}" -f $result.summary.external_baseline_advisory_count)
Write-Host ("external_baseline_warn_count={0}" -f $result.summary.external_baseline_warn_count)
Write-Host ("skill_trigger_eval_status={0}" -f $result.summary.skill_trigger_eval_status)
Write-Host ("skill_trigger_eval_grouped_query_count={0}" -f $result.summary.skill_trigger_eval_grouped_query_count)
Write-Host ("skill_trigger_eval_validation_pass_rate={0}" -f $result.summary.skill_trigger_eval_validation_pass_rate)
Write-Host ("skill_trigger_eval_validation_false_trigger_rate={0}" -f $result.summary.skill_trigger_eval_validation_false_trigger_rate)
Write-Host ("skill_lifecycle_status={0}" -f $result.summary.skill_lifecycle_status)
Write-Host ("skill_lifecycle_merge_candidate_count={0}" -f $result.summary.skill_lifecycle_merge_candidate_count)
Write-Host ("skill_lifecycle_retire_candidate_count={0}" -f $result.summary.skill_lifecycle_retire_candidate_count)
Write-Host ("skill_lifecycle_applied_merge_count={0}" -f $result.summary.skill_lifecycle_applied_merge_count)
Write-Host ("skill_lifecycle_applied_retire_count={0}" -f $result.summary.skill_lifecycle_applied_retire_count)
if ($result.ok) {
  Write-Host "result=OK"
  if (-not [string]::IsNullOrWhiteSpace($alertSnapshotPath)) {
    Write-Host ("alert_snapshot_path={0}" -f ($alertSnapshotPath -replace '\\', '/'))
  }
  exit 0
}

Write-Host "result=ALERT"
foreach ($item in $result.alerts) {
  Write-Host ("[ALERT] {0}" -f $item)
}
if ($notifyOnAlert) {
  Write-Warning "governance recurring review has alerts; see docs/governance/alerts-latest.md"
  try {
    [console]::Beep(880, 220)
  } catch {
  }
}
if (-not [string]::IsNullOrWhiteSpace($alertSnapshotPath)) {
  Write-Host ("alert_snapshot_path={0}" -f ($alertSnapshotPath -replace '\\', '/'))
}
exit 1
