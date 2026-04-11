$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$reposPath = Join-Path $kitRoot "config\repositories.json"
$globalAgents = Join-Path $kitRoot "source\global\AGENTS.md"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Assert-Command -Name powershell
$psExe = Get-CurrentPowerShellPath

function Format-Rate([int]$Numerator, [int]$Denominator) {
  if ($Denominator -le 0) { return "N/A" }
  return ("{0:P2}" -f ($Numerator / [double]$Denominator))
}

function Find-RepoPolicyEntry {
  param(
    [object[]]$Entries,
    [string]$RepoName
  )
  foreach ($entry in @($Entries)) {
    if ($null -eq $entry) { continue }
    $entryName = [string]$entry.repoName
    if ($entryName.Equals($RepoName, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $entry
    }
  }
  return $null
}

function Parse-JsonFromCommandOutput {
  param([string]$RawText)
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

function Invoke-JsonScriptSafe {
  param(
    [string]$ScriptPath,
    [string[]]$Args = @()
  )

  if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    return [pscustomobject]@{
      found = $false
      exit_code = -1
      parsed = $null
      raw = ""
    }
  }

  $captured = & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Args 2>&1
  $exitCode = $LASTEXITCODE
  $rawText = [string]::Join([Environment]::NewLine, @($captured))
  return [pscustomobject]@{
    found = $true
    exit_code = [int]$exitCode
    parsed = Parse-JsonFromCommandOutput -RawText $rawText
    raw = $rawText
  }
}

function Get-TokenQualitySnapshot {
  param([System.IO.FileInfo[]]$EvidenceFiles)

  $attemptTotal = 0
  $attemptFirstPass = 0
  $attemptRework = 0
  $responseTokens = [System.Collections.Generic.List[int]]::new()
  $taskTokens = [System.Collections.Generic.List[int]]::new()

  foreach ($f in @($EvidenceFiles)) {
    $raw = ""
    try {
      $raw = Get-Content -LiteralPath $f.FullName -Raw
    } catch {
      continue
    }

    $attemptMatch = [regex]::Match($raw, "(?im)^\s*attempt_count\s*[:=]\s*([0-9]+)\s*$")
    if ($attemptMatch.Success) {
      $attempt = [int]$attemptMatch.Groups[1].Value
      $attemptTotal++
      if ($attempt -le 1) { $attemptFirstPass++ }
      if ($attempt -ge 2) { $attemptRework++ }
    }

    $respMatch = [regex]::Match($raw, "(?im)^\s*average_response_token\s*[:=]\s*([0-9]+)\s*$")
    if ($respMatch.Success) {
      [void]$responseTokens.Add([int]$respMatch.Groups[1].Value)
    }

    $taskMatch = [regex]::Match($raw, "(?im)^\s*single_task_token\s*[:=]\s*([0-9]+)\s*$")
    if ($taskMatch.Success) {
      [void]$taskTokens.Add([int]$taskMatch.Groups[1].Value)
    }
  }

  $firstPassRate = Format-Rate $attemptFirstPass $attemptTotal
  $reworkRate = Format-Rate $attemptRework $attemptTotal

  $avgResponseToken = "N/A"
  if ($responseTokens.Count -gt 0) {
    $avgResponseToken = [string]([int][math]::Round((($responseTokens | Measure-Object -Sum).Sum / [double]$responseTokens.Count), 0))
  }

  $avgSingleTaskToken = "N/A"
  if ($taskTokens.Count -gt 0) {
    $avgSingleTaskToken = [string]([int][math]::Round((($taskTokens | Measure-Object -Sum).Sum / [double]$taskTokens.Count), 0))
  }

  $tokenPerEffectiveConclusion = "N/A"
  if ($avgSingleTaskToken -ne "N/A" -and $firstPassRate -ne "N/A") {
    $rateValue = 0.0
    if ([double]::TryParse(($firstPassRate -replace '%', ''), [ref]$rateValue) -and $rateValue -gt 0) {
      $tokenPerEffectiveConclusion = [string]([int][math]::Round(([double]$avgSingleTaskToken) / ($rateValue / 100.0), 0))
    }
  }

  return [pscustomobject]@{
    first_pass_rate = $firstPassRate
    rework_after_clarification_rate = $reworkRate
    average_response_token = $avgResponseToken
    single_task_token = $avgSingleTaskToken
    token_per_effective_conclusion = $tokenPerEffectiveConclusion
  }
}

function Get-PracticeStackEnableRates {
  param(
    [string]$RepoWin,
    [string]$RepoName
  )

  $policyPathCandidates = @(
    (Join-Path $RepoWin ".governance\practice-stack-policy.json"),
    (Join-Path $RepoWin "config\practice-stack-policy.json")
  )
  $policyPath = $null
  foreach ($candidate in $policyPathCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      $policyPath = $candidate
      break
    }
  }

  if ($null -eq $policyPath) {
    return [pscustomobject]@{
      ssdf = "N/A"
      slsa = "N/A"
      sbom = "N/A"
      scorecard = "N/A"
    }
  }

  $policy = $null
  try {
    $policy = Read-JsonFile -Path $policyPath -DisplayName $policyPath
  } catch {
    $policy = $null
  }
  if ($null -eq $policy) {
    return [pscustomobject]@{
      ssdf = "N/A"
      slsa = "N/A"
      sbom = "N/A"
      scorecard = "N/A"
    }
  }

  $repoEntry = Find-RepoPolicyEntry -Entries @($policy.repos) -RepoName $RepoName
  $repoPractices = if ($null -ne $repoEntry) { $repoEntry.practices } else { $null }
  $practiceKeys = @("ssdf", "slsa", "sbom", "scorecard")
  $enabledCount = 0
  foreach ($key in $practiceKeys) {
    $enabled = $true
    if ($null -ne $repoPractices -and $null -ne $repoPractices.PSObject.Properties[$key]) {
      $raw = $repoPractices.$key
      if ($raw -is [bool]) {
        $enabled = [bool]$raw
      } else {
        $enabled = $false
      }
    }
    if ($enabled) { $enabledCount++ }
  }
  $rate = Format-Rate $enabledCount $practiceKeys.Count
  return [pscustomobject]@{
    ssdf = $rate
    slsa = $rate
    sbom = $rate
    scorecard = $rate
  }
}

$ruleVersion = "unknown"
if (Test-Path $globalAgents) {
  $meta = Get-RuleDocMetadata -Path $globalAgents
  if (-not [string]::IsNullOrWhiteSpace([string]$meta.version)) {
    $ruleVersion = [string]$meta.version
  }
}

$repos = Read-JsonArray $reposPath
$today = Get-Date -Format "yyyy-MM-dd"

foreach ($repoRaw in $repos) {
  $repo = Normalize-Repo ([string]$repoRaw)
  $repoWin = $repo -replace '/', '\'
  if (!(Test-Path $repoWin)) {
    Write-Host "[SKIP] repo not found: $repo"
    continue
  }

  $evidenceDir = Join-Path $repoWin "docs\change-evidence"
  $evidenceFiles = @()
  if (Test-Path $evidenceDir) {
    $evidenceFiles = @(Get-ChildItem -Path $evidenceDir -File -Filter *.md | Where-Object { $_.Name -ne "template.md" })
  }

  $required = @("规则ID","风险等级","执行命令","验证证据","回滚动作")
  $learningLoopRequired = @("learning_points_3","reusable_checklist","open_questions")
  $totalEvidence = $evidenceFiles.Count
  $completeEvidence = 0
  $learningLoopCompleteEvidence = 0
  foreach ($f in $evidenceFiles) {
    $kv = Parse-KeyValueFile $f.FullName
    $ok = $true
    foreach ($k in $required) {
      if (-not $kv.ContainsKey($k) -or [string]::IsNullOrWhiteSpace([string]$kv[$k])) { $ok = $false; break }
    }
    if ($ok) { $completeEvidence++ }

    $learningOk = $true
    foreach ($k in $learningLoopRequired) {
      if (-not $kv.ContainsKey($k) -or [string]::IsNullOrWhiteSpace([string]$kv[$k])) { $learningOk = $false; break }
    }
    if ($learningOk) { $learningLoopCompleteEvidence++ }
  }

  $waiverDir = Join-Path $repoWin "docs\governance\waivers"
  $waiverFiles = @()
  if (Test-Path $waiverDir) {
    $waiverFiles = @(Get-ChildItem -Path $waiverDir -File -Filter *.md | Where-Object { $_.Name -ne "_template.md" -and $_.Name -ne "waiver-template.md" })
  }

  $waiverActive = 0
  $waiverExpiredUnrecovered = 0
  $todayDate = (Get-Date).Date
  foreach ($f in $waiverFiles) {
    $kv = Parse-KeyValueFile $f.FullName
    $status = if ($kv.ContainsKey("status")) { ([string]$kv["status"]).ToLowerInvariant() } else { "" }
    $closed = $status -eq "closed" -or $status -eq "recovered" -or $status -eq "done"
    if (-not $closed) { $waiverActive++ }

    $expRaw = if ($kv.ContainsKey("expires_at")) { [string]$kv["expires_at"] } else { "" }
    $exp = Parse-IsoDate $expRaw
    if (-not $closed -and $null -ne $exp -and $exp.Date -lt $todayDate) {
      $waiverExpiredUnrecovered++
    }
  }

  $overdueRate = Format-Rate $waiverExpiredUnrecovered $waiverFiles.Count
  $evidenceRate = Format-Rate $completeEvidence $totalEvidence
  $learningLoopRate = Format-Rate $learningLoopCompleteEvidence $totalEvidence
  $tokenQuality = Get-TokenQualitySnapshot -EvidenceFiles $evidenceFiles
  $repoName = Split-Path -Leaf $repoWin
  $practiceRates = Get-PracticeStackEnableRates -RepoWin $repoWin -RepoName $repoName

  $updateTriggerAlertCount = "N/A"
  $updateTriggerScript = Join-Path $repoWin "scripts\governance\check-update-triggers.ps1"
  $triggerResult = Invoke-JsonScriptSafe -ScriptPath $updateTriggerScript -Args @("-RepoRoot", $repoWin, "-AsJson")
  if ($null -ne $triggerResult.parsed -and $null -ne $triggerResult.parsed.PSObject.Properties['alert_count']) {
    $updateTriggerAlertCount = [string]([int]$triggerResult.parsed.alert_count)
  } else {
    $m = [regex]::Match([string]$triggerResult.raw, '"alert_count"\s*:\s*([0-9]+)')
    if (-not $m.Success) {
      $m = [regex]::Match([string]$triggerResult.raw, '(?m)^alert_count=([0-9]+)\s*$')
    }
    if ($m.Success) {
      $updateTriggerAlertCount = [string]([int]$m.Groups[1].Value)
    }
  }

  $externalBaselineStatus = "N/A"
  $externalBaselineAdvisoryCount = "N/A"
  $externalBaselineWarnCount = "N/A"
  $externalBaselineScript = Join-Path $repoWin "scripts\governance\check-external-baselines.ps1"
  $externalResult = Invoke-JsonScriptSafe -ScriptPath $externalBaselineScript -Args @("-RepoRoot", $repoWin, "-AsJson")
  if ($null -ne $externalResult.parsed) {
    if ($null -ne $externalResult.parsed.PSObject.Properties['status']) {
      $externalBaselineStatus = [string]$externalResult.parsed.status
    }
    if ($null -ne $externalResult.parsed.summary) {
      if ($null -ne $externalResult.parsed.summary.PSObject.Properties['advisory_count']) {
        $externalBaselineAdvisoryCount = [string]([int]$externalResult.parsed.summary.advisory_count)
      }
      if ($null -ne $externalResult.parsed.summary.PSObject.Properties['warn_count']) {
        $externalBaselineWarnCount = [string]([int]$externalResult.parsed.summary.warn_count)
      }
    }
  } else {
    $statusMatch = [regex]::Match([string]$externalResult.raw, '"status"\s*:\s*"([A-Z_]+)"')
    if (-not $statusMatch.Success) {
      $statusMatch = [regex]::Match([string]$externalResult.raw, '(?m)^status=([A-Z_]+)\s*$')
    }
    if ($statusMatch.Success) {
      $externalBaselineStatus = [string]$statusMatch.Groups[1].Value
    }

    $advisoryMatch = [regex]::Match([string]$externalResult.raw, '"advisory_count"\s*:\s*([0-9]+)')
    if (-not $advisoryMatch.Success) {
      $advisoryMatch = [regex]::Match([string]$externalResult.raw, '(?m)^advisory_count=([0-9]+)\s*$')
    }
    if ($advisoryMatch.Success) {
      $externalBaselineAdvisoryCount = [string]([int]$advisoryMatch.Groups[1].Value)
    }

    $warnMatch = [regex]::Match([string]$externalResult.raw, '"warn_count"\s*:\s*([0-9]+)')
    if (-not $warnMatch.Success) {
      $warnMatch = [regex]::Match([string]$externalResult.raw, '(?m)^warn_count=([0-9]+)\s*$')
    }
    if ($warnMatch.Success) {
      $externalBaselineWarnCount = [string]([int]$warnMatch.Groups[1].Value)
    }
  }

  $metricsDir = Join-Path $repoWin "docs\governance"
  if (!(Test-Path $metricsDir)) {
    try {
      New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    } catch {
      Write-Host "[WARN] cannot create metrics dir: $metricsDir"
      continue
    }
  }
  $metricsOut = Join-Path $metricsDir "metrics-auto.md"

  $content = @(
    "period=$today"
    "repo=$repo"
    "rule_version=$ruleVersion"
    "gate_pass_rate=N/A"
    "rollback_rate=N/A"
    "patch_recovery_overdue_rate=$overdueRate"
    "first_pass_rate=$($tokenQuality.first_pass_rate)"
    "rework_after_clarification_rate=$($tokenQuality.rework_after_clarification_rate)"
    "average_response_token=$($tokenQuality.average_response_token)"
    "single_task_token=$($tokenQuality.single_task_token)"
    "token_per_effective_conclusion=$($tokenQuality.token_per_effective_conclusion)"
    "evidence_completeness_rate=$evidenceRate"
    "learning_loop_evidence_rate=$learningLoopRate"
    "waiver_active_count=$waiverActive"
    "waiver_expired_unrecovered_count=$waiverExpiredUnrecovered"
    "update_trigger_alert_count=$updateTriggerAlertCount"
    "practice_stack_ssdf_enabled_rate=$($practiceRates.ssdf)"
    "practice_stack_slsa_enabled_rate=$($practiceRates.slsa)"
    "practice_stack_sbom_enabled_rate=$($practiceRates.sbom)"
    "practice_stack_scorecard_enabled_rate=$($practiceRates.scorecard)"
    "supply_chain_sbom_validation_pass_rate=N/A"
    "slsa_target_level=N/A"
    "scorecard_average=N/A"
    "external_baseline_status=$externalBaselineStatus"
    "external_baseline_advisory_count=$externalBaselineAdvisoryCount"
    "external_baseline_warn_count=$externalBaselineWarnCount"
    "notes=auto-generated by governance-kit/scripts/collect-governance-metrics.ps1"
  ) -join "`r`n"

  try {
    Set-Content -Path $metricsOut -Value $content -Encoding UTF8
    Write-Host "[METRICS] $metricsOut"
  } catch {
    Write-Host "[WARN] cannot write metrics: $metricsOut"
  }
}

Write-Host "collect-governance-metrics done"
