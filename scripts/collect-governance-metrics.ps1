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

function Read-TextWithEncodingFallback {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }

  $rawCandidates = [System.Collections.Generic.List[string]]::new()
  $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
  try {
    $rawUtf8Strict = [System.IO.File]::ReadAllText($Path, $utf8Strict)
    if ($null -ne $rawUtf8Strict) { [void]$rawCandidates.Add([string]$rawUtf8Strict) }
  } catch {}
  try {
    $rawUtf8 = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($null -ne $rawUtf8) { [void]$rawCandidates.Add([string]$rawUtf8) }
  } catch {}
  try {
    $rawDefault = [System.IO.File]::ReadAllText($Path)
    if ($null -ne $rawDefault) { [void]$rawCandidates.Add([string]$rawDefault) }
  } catch {}
  try {
    $rawContent = Get-Content -LiteralPath $Path -Raw
    if ($null -ne $rawContent) { [void]$rawCandidates.Add([string]$rawContent) }
  } catch {}

  foreach ($candidate in @($rawCandidates.ToArray())) {
    if ($null -eq $candidate) { continue }
    return ([string]$candidate).TrimStart([char]0xFEFF)
  }
  return ""
}

function Try-ParseIntMetricValue {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

  $trimmed = [string]$Text
  $trimmed = $trimmed.Trim()
  $parsed = 0
  if ([int]::TryParse($trimmed, [ref]$parsed)) {
    return [int]$parsed
  }

  $inline = [regex]::Match($trimmed, "(?<![0-9])([0-9]+)(?![0-9])")
  if ($inline.Success) {
    $fallback = 0
    if ([int]::TryParse([string]$inline.Groups[1].Value, [ref]$fallback)) {
      return [int]$fallback
    }
  }
  return $null
}

function Get-IntMetricFromRaw {
  param(
    [string]$Raw,
    [string]$Key
  )
  if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
  if ([string]::IsNullOrWhiteSpace($Key)) { return $null }

  $escaped = [regex]::Escape($Key)

  # Strict line-boundary parse keeps metric semantics aligned with key=value evidence files.
  $linePattern = "(?im)^\s*$escaped\s*[:=]\s*([^\r\n]+)\s*$"
  $lineMatch = [regex]::Match($Raw, $linePattern)
  if ($lineMatch.Success) {
    $parsed = Try-ParseIntMetricValue -Text ([string]$lineMatch.Groups[1].Value)
    if ($null -ne $parsed) { return [int]$parsed }
  }

  # Fallback for legacy PowerShell decoding quirks where adjacent key/value lines may collapse.
  $inlinePattern = "(?i)\b$escaped\b\s*[:=]\s*([0-9]+)"
  $inlineMatch = [regex]::Match($Raw, $inlinePattern)
  if ($inlineMatch.Success) {
    $parsed = Try-ParseIntMetricValue -Text ([string]$inlineMatch.Groups[1].Value)
    if ($null -ne $parsed) { return [int]$parsed }
  }

  return $null
}

function Get-TokenQualitySnapshot {
  param([System.IO.FileInfo[]]$EvidenceFiles)

  $attemptTotal = 0
  $attemptFirstPass = 0
  $attemptRework = 0
  $responseTokens = [System.Collections.Generic.List[int]]::new()
  $taskTokens = [System.Collections.Generic.List[int]]::new()

  foreach ($f in @($EvidenceFiles)) {
    $raw = Read-TextWithEncodingFallback -Path $f.FullName
    if ([string]::IsNullOrWhiteSpace($raw)) {
      continue
    }

    $attempt = Get-IntMetricFromRaw -Raw $raw -Key "attempt_count"
    if ($null -ne $attempt) {
      $attemptTotal++
      if ($attempt -le 1) { $attemptFirstPass++ }
      if ($attempt -ge 2) { $attemptRework++ }
    }

    $respValue = Get-IntMetricFromRaw -Raw $raw -Key "average_response_token"
    if ($null -ne $respValue) {
      [void]$responseTokens.Add([int]$respValue)
    } else {
      try {
        $kv = Parse-KeyValueFile $f.FullName
        if ($kv.ContainsKey("average_response_token")) {
          $parsedResp = Try-ParseIntMetricValue -Text ([string]$kv["average_response_token"])
          if ($null -ne $parsedResp) {
            [void]$responseTokens.Add([int]$parsedResp)
          }
        }
      } catch {
        # best-effort fallback only
      }
    }

    $taskValue = Get-IntMetricFromRaw -Raw $raw -Key "single_task_token"
    if ($null -ne $taskValue) {
      [void]$taskTokens.Add([int]$taskValue)
    } else {
      try {
        $kv = Parse-KeyValueFile $f.FullName
        if ($kv.ContainsKey("single_task_token")) {
          $parsedTask = Try-ParseIntMetricValue -Text ([string]$kv["single_task_token"])
          if ($null -ne $parsedTask) {
            [void]$taskTokens.Add([int]$parsedTask)
          }
        }
      } catch {
        # best-effort fallback only
      }
    }
  }

  $firstPassRate = Format-Rate $attemptFirstPass $attemptTotal
  $reworkRate = Format-Rate $attemptRework $attemptTotal

  $avgResponseToken = "N/A"
  $responseTokenValues = @($responseTokens.ToArray())
  if ($responseTokenValues.Count -eq 0) {
    # Secondary fallback: direct full-scan match to avoid silent parser drift.
    $responseFallback = [System.Collections.Generic.List[int]]::new()
    foreach ($f in @($EvidenceFiles)) {
      $raw = Read-TextWithEncodingFallback -Path $f.FullName
      if ([string]::IsNullOrWhiteSpace($raw)) { continue }
      $value = Get-IntMetricFromRaw -Raw $raw -Key "average_response_token"
      if ($null -ne $value) {
        [void]$responseFallback.Add([int]$value)
      }
    }
    $responseTokenValues = @($responseFallback.ToArray())
  }
  if ($responseTokenValues.Count -gt 0) {
    $avgResponseToken = [string]([int][math]::Round((($responseTokenValues | Measure-Object -Sum).Sum / [double]$responseTokenValues.Count), 0))
  }

  $avgSingleTaskToken = "N/A"
  $singleTaskTokenValues = @($taskTokens.ToArray())
  if ($singleTaskTokenValues.Count -eq 0) {
    $singleTaskFallback = [System.Collections.Generic.List[int]]::new()
    foreach ($f in @($EvidenceFiles)) {
      $raw = Read-TextWithEncodingFallback -Path $f.FullName
      if ([string]::IsNullOrWhiteSpace($raw)) { continue }
      $value = Get-IntMetricFromRaw -Raw $raw -Key "single_task_token"
      if ($null -ne $value) {
        [void]$singleTaskFallback.Add([int]$value)
      }
    }
    $singleTaskTokenValues = @($singleTaskFallback.ToArray())
  }
  if ($singleTaskTokenValues.Count -gt 0) {
    $avgSingleTaskToken = [string]([int][math]::Round((($singleTaskTokenValues | Measure-Object -Sum).Sum / [double]$singleTaskTokenValues.Count), 0))
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
    response_token_sample_count = $responseTokenValues.Count
    single_task_token_sample_count = $singleTaskTokenValues.Count
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

function Get-ExternalBaselineEnableRates {
  param([string]$RepoWin)

  $policyPath = Join-Path $RepoWin ".governance\external-baseline-policy.json"
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    return [pscustomobject]@{
      code_scanning = "N/A"
      dependency_review = "N/A"
      codeowners = "N/A"
      repository_rulesets = "N/A"
    }
  }

  $policy = $null
  try {
    $policy = Read-JsonFile -Path $policyPath -DisplayName $policyPath
  } catch {
    $policy = $null
  }
  if ($null -eq $policy -or $null -eq $policy.checks) {
    return [pscustomobject]@{
      code_scanning = "N/A"
      dependency_review = "N/A"
      codeowners = "N/A"
      repository_rulesets = "N/A"
    }
  }

  function Resolve-CheckEnabledRate {
    param(
      [object]$Checks,
      [string]$Name
    )
    if ($null -eq $Checks.PSObject.Properties[$Name]) { return "N/A" }
    $node = $Checks.$Name
    if ($null -eq $node -or $null -eq $node.PSObject.Properties["enabled"]) { return "N/A" }
    $enabled = [bool]$node.enabled
    if ($enabled) { return "100.00%" }
    return "0.00%"
  }

  return [pscustomobject]@{
    code_scanning = (Resolve-CheckEnabledRate -Checks $policy.checks -Name "code_scanning")
    dependency_review = (Resolve-CheckEnabledRate -Checks $policy.checks -Name "dependency_review")
    codeowners = (Resolve-CheckEnabledRate -Checks $policy.checks -Name "codeowners")
    repository_rulesets = (Resolve-CheckEnabledRate -Checks $policy.checks -Name "repository_rulesets")
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
  $externalBaselineRates = Get-ExternalBaselineEnableRates -RepoWin $repoWin

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
    "response_token_sample_count=$($tokenQuality.response_token_sample_count)"
    "single_task_token_sample_count=$($tokenQuality.single_task_token_sample_count)"
    "evidence_completeness_rate=$evidenceRate"
    "learning_loop_evidence_rate=$learningLoopRate"
    "waiver_active_count=$waiverActive"
    "waiver_expired_unrecovered_count=$waiverExpiredUnrecovered"
    "update_trigger_alert_count=$updateTriggerAlertCount"
    "practice_stack_ssdf_enabled_rate=$($practiceRates.ssdf)"
    "practice_stack_slsa_enabled_rate=$($practiceRates.slsa)"
    "practice_stack_sbom_enabled_rate=$($practiceRates.sbom)"
    "practice_stack_scorecard_enabled_rate=$($practiceRates.scorecard)"
    "practice_stack_code_scanning_enabled_rate=$($externalBaselineRates.code_scanning)"
    "practice_stack_dependency_review_enabled_rate=$($externalBaselineRates.dependency_review)"
    "practice_stack_codeowners_enabled_rate=$($externalBaselineRates.codeowners)"
    "practice_stack_repository_rulesets_enabled_rate=$($externalBaselineRates.repository_rulesets)"
    "supply_chain_sbom_validation_pass_rate=N/A"
    "slsa_target_level=N/A"
    "scorecard_average=N/A"
    "external_baseline_status=$externalBaselineStatus"
    "external_baseline_advisory_count=$externalBaselineAdvisoryCount"
    "external_baseline_warn_count=$externalBaselineWarnCount"
    "notes=auto-generated by repo-governance-hub/scripts/collect-governance-metrics.ps1"
  ) -join "`r`n"

  try {
    Set-Content -Path $metricsOut -Value $content -Encoding UTF8
    Write-Host "[METRICS] $metricsOut"
  } catch {
    Write-Host "[WARN] cannot write metrics: $metricsOut"
  }
}

Write-Host "collect-governance-metrics done"

