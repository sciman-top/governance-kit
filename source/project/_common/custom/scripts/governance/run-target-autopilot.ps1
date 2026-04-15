param(
  [string]$RepoRoot = ".",
  [string]$GovernanceRoot = "",
  [string]$IssueId = "target-autopilot-default",
  [ValidateSet("auto", "plan", "requirement", "bugfix", "acceptance")]
  [string]$ClarificationScenario = "auto",
  [string]$ClarificationContextFile = "",
  [string]$CodexCommand = "codex",
  [int]$MaxCycles = 20,
  [int]$MaxFixAttemptsPerGate = 2,
  [int]$MaxWorkIterationsPerCycle = 1,
  [switch]$SkipWorkIteration,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path

function Resolve-GovernanceRoot {
  param([string]$ProvidedPath)

  if (-not [string]::IsNullOrWhiteSpace($ProvidedPath)) {
    $resolved = Resolve-Path -LiteralPath $ProvidedPath -ErrorAction SilentlyContinue
    if ($null -ne $resolved) { return $resolved.Path }
    throw "Governance kit path not found: $ProvidedPath"
  }

  $gitValue = ""
  try {
    $gitValue = (& git -C $repoPath config --local --get governance.root 2>$null)
  }
  catch {
    $gitValue = ""
  }

  if (-not [string]::IsNullOrWhiteSpace($gitValue)) {
    $resolved = Resolve-Path -LiteralPath ($gitValue -replace '/', '\\') -ErrorAction SilentlyContinue
    if ($null -ne $resolved) { return $resolved.Path }
  }

  if (-not [string]::IsNullOrWhiteSpace($env:GOVERNANCE_ROOT)) {
    $resolved = Resolve-Path -LiteralPath $env:GOVERNANCE_ROOT -ErrorAction SilentlyContinue
    if ($null -ne $resolved) { return $resolved.Path }
  }

  throw "Cannot resolve repo-governance-hub root. Set git config governance.root or pass -GovernanceRoot."
}

function Invoke-ShellCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$CommandText,
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [Parameter(Mandatory = $true)][string]$LogRoot
  )

  return Invoke-LoggedCommand -Name $Name -WorkDir $WorkDir -LogRoot $LogRoot -Action {
    $scriptBlock = [ScriptBlock]::Create($CommandText)
    & $scriptBlock
  }
}

function Emit-BrowserSessionHint {
  param([string]$RepoPath)
  $helperPath = Join-Path $RepoPath "tools\browser-session\start-browser-session.ps1"
  if (-not (Test-Path -LiteralPath $helperPath)) {
    return
  }

  Write-Host "browser_session.helper=$helperPath"
  Write-Host "browser_session.start=powershell -ExecutionPolicy Bypass -File tools/browser-session/start-browser-session.ps1 -Action start -Name automation -Port 9222 -Url about:blank"
  Write-Host "browser_session.attach=agent-browser --cdp 9222 open about:blank"
}

function Try-RegisterSkillCandidate {
  param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$IssueId,
    [Parameter(Mandatory = $true)][string]$StepName,
    [Parameter(Mandatory = $true)][string]$CommandText,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$FailureReason,
    [Parameter(Mandatory = $true)][string]$PowerShellPath
  )

  $registered = $false
  $registerScript = Join-Path $RepoPath "scripts\governance\register-skill-candidate.ps1"
  if (-not (Test-Path -LiteralPath $registerScript -PathType Leaf)) {
    return $false
  }

  try {
    $signature = New-CommandFailureSignature -StepName $StepName -CommandText $CommandText -LogPath $LogPath
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $registerScript,
      "-IssueSignature", $signature,
      "-RepoRoot", $RepoPath,
      "-IssueId", $IssueId,
      "-StepName", $StepName,
      "-CommandText", $CommandText,
      "-FailureReason", $FailureReason,
      "-EvidenceLink", $LogPath
    )
    & $PowerShellPath @args | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Host ("[WARN] skill candidate register failed: step={0} exit={1}" -f $StepName, $LASTEXITCODE)
    } else {
      $registered = $true
      Write-Host ("[SKILL_CANDIDATE] step={0} signature={1}" -f $StepName, $signature)
    }
  }
  catch {
    Write-Host ("[WARN] skill candidate register exception: step={0} error={1}" -f $StepName, $_.Exception.Message)
  }
  return $registered
}

function Try-PromoteSkillCandidates {
  param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$GovernanceRoot,
    [Parameter(Mandatory = $true)][string]$PowerShellPath
  )

  $promoteScript = Join-Path $RepoPath "scripts\governance\promote-skill-candidates.ps1"
  if (-not (Test-Path -LiteralPath $promoteScript -PathType Leaf)) {
    return
  }

  try {
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $promoteScript,
      "-GovernanceRoot", $GovernanceRoot,
      "-AsJson"
    )
    $raw = & $PowerShellPath @args
    if ($LASTEXITCODE -ne 0) {
      Write-Host ("[WARN] skill promotion failed: exit={0}" -f $LASTEXITCODE)
      return
    }
    $text = [string]::Join([Environment]::NewLine, @($raw))
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    $result = $text | ConvertFrom-Json
    Write-Host ("[SKILL_PROMOTION] promoted_count={0} gates_ran={1}" -f [int]$result.promoted_count, [bool]$result.gates_ran)
  }
  catch {
    Write-Host ("[WARN] skill promotion exception: {0}" -f $_.Exception.Message)
  }
}

function Resolve-SkillPromotionPolicyState {
  param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$KitRoot
  )

  $defaultEnabled = $false
  $repoPolicyPath = Join-Path $RepoPath ".governance\skill-promotion-policy.json"
  $kitPolicyPath = Join-Path $KitRoot "config\skill-promotion-policy.json"
  $selectedPath = $null
  $selectedSource = "default"
  $enabled = $defaultEnabled

  if (Test-Path -LiteralPath $repoPolicyPath -PathType Leaf) {
    $selectedPath = $repoPolicyPath
    $selectedSource = "repo"
  } elseif (Test-Path -LiteralPath $kitPolicyPath -PathType Leaf) {
    $selectedPath = $kitPolicyPath
    $selectedSource = "kit"
  }

  if ($null -ne $selectedPath) {
    $candidate = Read-JsonFile -Path $selectedPath -DefaultValue $null -UseCache -DisplayName "skill-promotion-policy.json"
    if ($null -ne $candidate -and $null -ne $candidate.PSObject.Properties['auto_register_trigger_eval_from_autopilot']) {
      $enabled = [bool]$candidate.auto_register_trigger_eval_from_autopilot
    }
  }

  return [pscustomobject]@{
    source = $selectedSource
    path = if ($null -ne $selectedPath) { $selectedPath } else { "default(in-memory)" }
    auto_register_trigger_eval_from_autopilot = [bool]$enabled
  }
}

function Try-RegisterSkillTriggerEvalRun {
  param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$IssueId,
    [Parameter(Mandatory = $true)][string]$Query,
    [Parameter(Mandatory = $true)][bool]$ShouldTrigger,
    [Parameter(Mandatory = $true)][bool]$Triggered,
    [Parameter(Mandatory = $false)][string]$EvidencePath,
    [Parameter(Mandatory = $true)][psobject]$PolicyState,
    [Parameter(Mandatory = $true)][string]$PowerShellPath
  )

  if (-not [bool]$PolicyState.auto_register_trigger_eval_from_autopilot) {
    Write-Host "[SKILL_TRIGGER_EVAL] skipped reason=policy_disabled"
    return $false
  }

  $registerScript = Join-Path $RepoPath "scripts\governance\register-skill-trigger-eval-run.ps1"
  if (-not (Test-Path -LiteralPath $registerScript -PathType Leaf)) {
    Write-Host "[SKILL_TRIGGER_EVAL] skipped reason=script_missing"
    return $false
  }

  try {
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $registerScript,
      "-RepoRoot", $RepoPath,
      "-IssueId", $IssueId,
      "-Split", "validation",
      "-Evaluator", "autopilot",
      "-Query", $Query,
      "-ShouldTrigger", $(if ($ShouldTrigger) { 1 } else { 0 }),
      "-Triggered", ([string]$Triggered).ToLowerInvariant()
    )
    if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
      $args += @("-EvidencePath", $EvidencePath)
    }
    & $PowerShellPath @args | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Host ("[WARN] skill trigger eval register failed: exit={0}" -f $LASTEXITCODE)
      return $false
    }
    Write-Host ("[SKILL_TRIGGER_EVAL] split=validation should_trigger={0} triggered={1}" -f $ShouldTrigger, $Triggered)
    return $true
  }
  catch {
    Write-Host ("[WARN] skill trigger eval register exception: {0}" -f $_.Exception.Message)
    return $false
  }
}

function New-DefaultSubagentTriggerPolicy {
  return [pscustomobject]@{
    schema_version = "1.0"
    enabled = $true
    decision_mode = "hard_guard_plus_score"
    hard_guards = [pscustomobject]@{
      require_explicit_parallel_intent = $true
      block_when_no_disjoint_write_set_evidence = $true
      block_when_high_risk_release = $true
      block_when_critical_path_blocking = $true
    }
    scoring = [pscustomobject]@{
      spawn_threshold = 70
      consider_threshold = 45
      weights = [pscustomobject]@{
        explicit_parallel_intent = 35
        has_work_iterations = 20
        disjoint_write_set_evidence = 20
        critical_path_blocking = -30
        high_risk_release = -30
        single_slice_only = -20
      }
    }
    limits = [pscustomobject]@{
      max_parallel_agents = 3
      max_parallel_agents_on_windows = 2
    }
    signals = [pscustomobject]@{
      parallel_intent_when_max_work_iterations_gt_1 = $true
      parallel_intent_env_var = "GOVERNANCE_PARALLEL_INTENT"
      high_risk_env_var = "GOVERNANCE_HIGH_RISK_RELEASE"
      disjoint_write_set_env_var = "GOVERNANCE_DISJOINT_WRITESET_OK"
    }
    evidence = [pscustomobject]@{
      emit_decision_json = $true
    }
  }
}

function Resolve-SubagentTriggerPolicy {
  param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$KitRoot
  )

  $defaultPolicy = New-DefaultSubagentTriggerPolicy
  $repoPolicyPath = Join-Path $RepoPath ".governance\subagent-trigger-policy.json"
  $kitPolicyPath = Join-Path $KitRoot "config\subagent-trigger-policy.json"
  $selectedPath = $null
  $selectedSource = "default"
  $resolved = $defaultPolicy

  if (Test-Path -LiteralPath $repoPolicyPath -PathType Leaf) {
    $selectedPath = $repoPolicyPath
    $selectedSource = "repo"
  } elseif (Test-Path -LiteralPath $kitPolicyPath -PathType Leaf) {
    $selectedPath = $kitPolicyPath
    $selectedSource = "kit"
  }

  if ($null -ne $selectedPath) {
    $candidate = Read-JsonFile -Path $selectedPath -DefaultValue $null -UseCache -DisplayName "subagent-trigger-policy.json"
    if ($null -ne $candidate) {
      if ($null -ne $candidate.PSObject.Properties['schema_version']) { $resolved.schema_version = [string]$candidate.schema_version }
      if ($null -ne $candidate.PSObject.Properties['enabled']) { $resolved.enabled = [bool]$candidate.enabled }
      if ($null -ne $candidate.PSObject.Properties['decision_mode']) { $resolved.decision_mode = [string]$candidate.decision_mode }
      if ($null -ne $candidate.PSObject.Properties['hard_guards'] -and $null -ne $candidate.hard_guards) { $resolved.hard_guards = $candidate.hard_guards }
      if ($null -ne $candidate.PSObject.Properties['scoring'] -and $null -ne $candidate.scoring) { $resolved.scoring = $candidate.scoring }
      if ($null -ne $candidate.PSObject.Properties['limits'] -and $null -ne $candidate.limits) { $resolved.limits = $candidate.limits }
      if ($null -ne $candidate.PSObject.Properties['signals'] -and $null -ne $candidate.signals) { $resolved.signals = $candidate.signals }
      if ($null -ne $candidate.PSObject.Properties['evidence'] -and $null -ne $candidate.evidence) { $resolved.evidence = $candidate.evidence }
    }
  }

  return [pscustomobject]@{
    source = $selectedSource
    path = if ($null -ne $selectedPath) { $selectedPath } else { "default(in-memory)" }
    policy = $resolved
  }
}

function Resolve-SubagentDecision {
  param(
    [Parameter(Mandatory = $true)][psobject]$Policy,
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$IssueId,
    [Parameter(Mandatory = $true)][int]$MaxWorkIterationsPerCycle,
    [Parameter(Mandatory = $true)][switch]$SkipWorkIteration
  )

  $signalIntent = ($MaxWorkIterationsPerCycle -gt 1)
  $intentEnvVar = [string]$Policy.signals.parallel_intent_env_var
  if (-not [string]::IsNullOrWhiteSpace($intentEnvVar) -and [string]([Environment]::GetEnvironmentVariable($intentEnvVar)) -eq "1") {
    $signalIntent = $true
  }

  $highRiskSignal = $false
  $highRiskEnvVar = [string]$Policy.signals.high_risk_env_var
  if (-not [string]::IsNullOrWhiteSpace($highRiskEnvVar) -and [string]([Environment]::GetEnvironmentVariable($highRiskEnvVar)) -eq "1") {
    $highRiskSignal = $true
  }

  $disjointWriteSetSignal = ($MaxWorkIterationsPerCycle -ge 2)
  $disjointEnvVar = [string]$Policy.signals.disjoint_write_set_env_var
  if (-not [string]::IsNullOrWhiteSpace($disjointEnvVar) -and [string]([Environment]::GetEnvironmentVariable($disjointEnvVar)) -eq "1") {
    $disjointWriteSetSignal = $true
  }

  $hasWorkIteration = (-not $SkipWorkIteration.IsPresent -and $MaxWorkIterationsPerCycle -gt 0)
  $criticalPathBlocking = -not $hasWorkIteration
  $singleSliceOnly = ($MaxWorkIterationsPerCycle -le 1)

  $weights = $Policy.scoring.weights
  $score = 0
  if ($signalIntent) { $score += [int]$weights.explicit_parallel_intent }
  if ($hasWorkIteration) { $score += [int]$weights.has_work_iterations }
  if ($disjointWriteSetSignal) { $score += [int]$weights.disjoint_write_set_evidence }
  if ($criticalPathBlocking) { $score += [int]$weights.critical_path_blocking }
  if ($highRiskSignal) { $score += [int]$weights.high_risk_release }
  if ($singleSliceOnly) { $score += [int]$weights.single_slice_only }
  if ($score -lt 0) { $score = 0 }
  if ($score -gt 100) { $score = 100 }

  $hardGuardHits = [System.Collections.Generic.List[string]]::new()
  if ([bool]$Policy.hard_guards.require_explicit_parallel_intent -and -not $signalIntent) {
    [void]$hardGuardHits.Add("no_explicit_parallel_intent")
  }
  if ([bool]$Policy.hard_guards.block_when_no_disjoint_write_set_evidence -and -not $disjointWriteSetSignal) {
    [void]$hardGuardHits.Add("no_disjoint_write_set_evidence")
  }
  if ([bool]$Policy.hard_guards.block_when_high_risk_release -and $highRiskSignal) {
    [void]$hardGuardHits.Add("high_risk_release")
  }
  if ([bool]$Policy.hard_guards.block_when_critical_path_blocking -and $criticalPathBlocking) {
    [void]$hardGuardHits.Add("critical_path_blocking")
  }

  $spawn = $false
  $reasonCodes = [System.Collections.Generic.List[string]]::new()
  if (-not [bool]$Policy.enabled) {
    [void]$reasonCodes.Add("policy_disabled")
  } elseif ($hardGuardHits.Count -gt 0) {
    [void]$reasonCodes.Add("blocked_by_hard_guard")
  } elseif ($score -ge [int]$Policy.scoring.spawn_threshold) {
    $spawn = $true
    [void]$reasonCodes.Add("score_at_or_above_spawn_threshold")
  } elseif ($score -ge [int]$Policy.scoring.consider_threshold) {
    [void]$reasonCodes.Add("score_in_consider_range")
  } else {
    [void]$reasonCodes.Add("score_below_consider_threshold")
  }

  $maxAgentsByPolicy = [Math]::Max(1, [int]$Policy.limits.max_parallel_agents)
  $isWindowsHost = ([string]$env:OS -eq "Windows_NT")
  if ($isWindowsHost -and $null -ne $Policy.limits.PSObject.Properties['max_parallel_agents_on_windows']) {
    $maxAgentsByPolicy = [Math]::Min($maxAgentsByPolicy, [Math]::Max(1, [int]$Policy.limits.max_parallel_agents_on_windows))
  }
  $requestedSlices = [Math]::Max(1, [int]$MaxWorkIterationsPerCycle)
  $maxAgents = if ($spawn) { [Math]::Min($maxAgentsByPolicy, $requestedSlices) } else { 0 }

  return [pscustomobject]@{
    issue_id = $IssueId
    decision_mode = [string]$Policy.decision_mode
    spawn_parallel_subagents = [bool]$spawn
    max_parallel_agents = [int]$maxAgents
    decision_score = [int]$score
    spawn_threshold = [int]$Policy.scoring.spawn_threshold
    consider_threshold = [int]$Policy.scoring.consider_threshold
    reason_codes = @($reasonCodes)
    hard_guard_hits = @($hardGuardHits)
    signals = [pscustomobject]@{
      explicit_parallel_intent = [bool]$signalIntent
      has_work_iteration = [bool]$hasWorkIteration
      disjoint_write_set_evidence = [bool]$disjointWriteSetSignal
      high_risk_release = [bool]$highRiskSignal
      critical_path_blocking = [bool]$criticalPathBlocking
    }
    disjoint_write_set_refs = if ($disjointWriteSetSignal) { @("max_work_iterations_signal") } else { @() }
    structured_result_schema = "subagent_result_v1"
    aggregation_owner = "main_agent"
    fallback_action = if ($spawn) { "delegate_parallel_to_outer_ai_session" } else { "delegate_serial_to_outer_ai_session" }
  }
}

$kitRoot = Resolve-GovernanceRoot -ProvidedPath $GovernanceRoot
$commonPath = Join-Path $kitRoot "scripts/lib/common.ps1"
$analyzeScript = Join-Path $kitRoot "scripts/analyze-repo-governance.ps1"
$trackerScript = Join-Path $kitRoot "scripts/governance/track-issue-state.ps1"
if (-not (Test-Path -LiteralPath $commonPath)) {
  throw "Missing common helper: $commonPath"
}
if (-not (Test-Path -LiteralPath $analyzeScript)) {
  throw "Missing analyzer script: $analyzeScript"
}
if (-not (Test-Path -LiteralPath $trackerScript)) {
  throw "Missing clarification tracker script: $trackerScript"
}
. $commonPath

Assert-Command -Name powershell
$psExe = Get-CurrentPowerShellPath
$repoPolicy = Get-RepoAutomationPolicy -KitRoot $kitRoot -Repo $repoPath
$policyMaxCycles = [Math]::Max(1, [int]$repoPolicy.max_autonomous_iterations)
$effectiveMaxCycles = [Math]::Min([Math]::Max(1, [int]$MaxCycles), $policyMaxCycles)
$policyMaxFixAttempts = [Math]::Max(1, [int]$repoPolicy.max_repeated_failure_per_step)
$effectiveMaxFixAttemptsPerGate = [Math]::Min([Math]::Max(1, [int]$MaxFixAttemptsPerGate), $policyMaxFixAttempts)
$enableNoProgressGuard = [bool]$repoPolicy.enable_no_progress_guard
$maxNoProgressIterations = [Math]::Max(1, [int]$repoPolicy.max_no_progress_iterations)
$tokenBudgetMode = [string]$repoPolicy.token_budget_mode
if ([string]::IsNullOrWhiteSpace($tokenBudgetMode)) {
  $tokenBudgetMode = "lite"
}
$failureSignatureCounts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)

$runId = [guid]::NewGuid().ToString("n")
$scenarioResolution = Resolve-EffectiveClarificationScenario -RequestedScenario $ClarificationScenario -ContextFile $ClarificationContextFile
$effectiveClarificationScenario = [string]$scenarioResolution.scenario
$clarificationScenarioSource = [string]$scenarioResolution.source
$logRoot = Join-Path $repoPath (".codex/logs/target-autopilot/" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $runId)
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$subagentPolicyState = Resolve-SubagentTriggerPolicy -RepoPath $repoPath -KitRoot $kitRoot
$subagentDecision = Resolve-SubagentDecision -Policy $subagentPolicyState.policy -RepoPath $repoPath -IssueId $IssueId -MaxWorkIterationsPerCycle $MaxWorkIterationsPerCycle -SkipWorkIteration:$SkipWorkIteration
$skillPromotionPolicyState = Resolve-SkillPromotionPolicyState -RepoPath $repoPath -KitRoot $kitRoot
$subagentDecisionPath = Join-Path $logRoot "subagent-decision.json"
if ([bool]$subagentPolicyState.policy.evidence.emit_decision_json) {
  Set-Content -LiteralPath $subagentDecisionPath -Encoding UTF8 -Value (($subagentDecision | ConvertTo-Json -Depth 8))
}

$analysisJson = & $psExe -NoProfile -ExecutionPolicy Bypass -File $analyzeScript -RepoPath $repoPath -AsJson
$analysis = [string]::Join([Environment]::NewLine, @($analysisJson)) | ConvertFrom-Json

$buildCmd = [string]$analysis.recommended.build
$testCmd = [string]$analysis.recommended.test
$contractCmd = [string]$analysis.recommended.contract_invariant
$hotspotCmd = [string]$analysis.recommended.hotspot

$gateSteps = @(
  [pscustomobject]@{ name = "build"; command = $buildCmd },
  [pscustomobject]@{ name = "test"; command = $testCmd },
  [pscustomobject]@{ name = "contract-invariant"; command = $contractCmd },
  [pscustomobject]@{ name = "hotspot"; command = $hotspotCmd }
)

Write-Host "TARGET_SAFE_AUTOPILOT"
Write-Host "run_id=$runId"
Write-Host "repo_root=$repoPath"
Write-Host "governance_root=$kitRoot"
Write-Host "logs=$logRoot"
Write-Host "mode=gate-orchestrator"
Write-Host "issue_id=$IssueId"
Write-Host "clarification_scenario=$effectiveClarificationScenario"
Write-Host "clarification_scenario_source=$clarificationScenarioSource"
Write-Host "policy.max_autonomous_iterations=$policyMaxCycles"
Write-Host "policy.max_repeated_failure_per_step=$policyMaxFixAttempts"
Write-Host "policy.enable_no_progress_guard=$enableNoProgressGuard"
Write-Host "policy.max_no_progress_iterations=$maxNoProgressIterations"
Write-Host "policy.token_budget_mode=$tokenBudgetMode"
Write-Host "subagent_policy.source=$($subagentPolicyState.source)"
Write-Host "subagent_policy.path=$($subagentPolicyState.path)"
Write-Host "subagent_decision.spawn_parallel_subagents=$($subagentDecision.spawn_parallel_subagents)"
Write-Host "subagent_decision.max_parallel_agents=$($subagentDecision.max_parallel_agents)"
Write-Host "subagent_decision.score=$($subagentDecision.decision_score)"
Write-Host "subagent_decision.reason_codes=$([string]::Join(',', @($subagentDecision.reason_codes)))"
Write-Host "subagent_decision.evidence_json=$subagentDecisionPath"
Write-Host "skill_promotion_policy.source=$($skillPromotionPolicyState.source)"
Write-Host "skill_promotion_policy.path=$($skillPromotionPolicyState.path)"
Write-Host "skill_promotion_policy.auto_register_trigger_eval_from_autopilot=$($skillPromotionPolicyState.auto_register_trigger_eval_from_autopilot)"
Write-Host ("[SUBAGENT_DECISION_JSON] " + ($subagentDecision | ConvertTo-Json -Depth 8 -Compress))
if ($effectiveMaxCycles -lt $MaxCycles) {
  Write-Host "[LIMIT] requested MaxCycles=$MaxCycles capped to policy max_autonomous_iterations=$effectiveMaxCycles"
}
if ($effectiveMaxFixAttemptsPerGate -lt $MaxFixAttemptsPerGate) {
  Write-Host "[LIMIT] requested MaxFixAttemptsPerGate=$MaxFixAttemptsPerGate capped to policy max_repeated_failure_per_step=$effectiveMaxFixAttemptsPerGate"
}
Emit-BrowserSessionHint -RepoPath $repoPath

if ($DryRun) {
  Write-Host "dry_run=true"
  foreach ($step in $gateSteps) {
    Write-Host ("planned_gate." + $step.name + "=" + $step.command)
  }
  if (-not $SkipWorkIteration.IsPresent -and $MaxWorkIterationsPerCycle -gt 0) {
    Write-Host "planned_work_iteration=no-op (handled by outer AI session)"
  }
  exit 0
}

$clarificationState = Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repoPath -IssueId $IssueId -Scenario $effectiveClarificationScenario -Mode "evaluate" -PowerShellPath $psExe
if ($clarificationState.clarification_required -eq $true) {
  Write-Host ("CLARIFICATION_REQUIRED issue_id={0} attempt_count={1} scenario={2}" -f $IssueId, $clarificationState.attempt_count, $clarificationState.scenario)
}

for ($cycle = 1; $cycle -le $effectiveMaxCycles; $cycle++) {
  Write-Host ""
  Write-Host "=== cycle $cycle / $effectiveMaxCycles ==="

  $skillCandidateRecordedInCycle = $false
  foreach ($step in $gateSteps) {
    if ([string]::IsNullOrWhiteSpace($step.command) -or $step.command -like "N/A*") {
      throw "Required gate step '$($step.name)' is unavailable: $($step.command)"
    }

    $result = Invoke-ShellCommand -Name ("gate." + $step.name) -CommandText $step.command -WorkDir $repoPath -LogRoot $logRoot
    if ($result.exit_code -eq 0) {
      continue
    }

    $registeredCandidate = Try-RegisterSkillCandidate -RepoPath $repoPath -IssueId $IssueId -StepName ([string]$step.name) -CommandText ([string]$step.command) -LogPath ([string]$result.log_path) -FailureReason "gate_failed_first_attempt" -PowerShellPath $psExe
    if ($registeredCandidate) { $skillCandidateRecordedInCycle = $true }

    $recovered = $false
    for ($attempt = 1; $attempt -le $effectiveMaxFixAttemptsPerGate; $attempt++) {
      if ($tokenBudgetMode -eq "lite") {
        Write-Host "RETRY step=$($step.name) attempt=$attempt/$effectiveMaxFixAttemptsPerGate mode=lite"
      } else {
        Write-Host "RETRY step=$($step.name) attempt=$attempt/$effectiveMaxFixAttemptsPerGate"
      }
      $result = Invoke-ShellCommand -Name ("gate.retry." + $step.name) -CommandText $step.command -WorkDir $repoPath -LogRoot $logRoot
      if ($result.exit_code -eq 0) {
        $recovered = $true
        break
      }
      $registeredCandidate = Try-RegisterSkillCandidate -RepoPath $repoPath -IssueId $IssueId -StepName ([string]$step.name) -CommandText ([string]$step.command) -LogPath ([string]$result.log_path) -FailureReason ("gate_retry_failed_attempt_" + $attempt) -PowerShellPath $psExe
      if ($registeredCandidate) { $skillCandidateRecordedInCycle = $true }
      if ($enableNoProgressGuard) {
        $sig = New-CommandFailureSignature -StepName ([string]$step.name) -CommandText ([string]$step.command) -LogPath ([string]$result.log_path)
        if (-not $failureSignatureCounts.ContainsKey($sig)) {
          $failureSignatureCounts[$sig] = 0
        }
        $failureSignatureCounts[$sig] = $failureSignatureCounts[$sig] + 1
        if ($failureSignatureCounts[$sig] -ge $maxNoProgressIterations) {
          throw "NO_PROGRESS_SIGNATURE_LIMIT step=$($step.name) signature=$sig count=$($failureSignatureCounts[$sig])/$maxNoProgressIterations log=$($result.log_path)"
        }
      }
    }

    if (-not $recovered) {
      $failureReason = "gate:$($step.name) failed; log=$($result.log_path)"
      $clarificationState = Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repoPath -IssueId $IssueId -Scenario $effectiveClarificationScenario -Mode "record" -Outcome "failure" -Reason $failureReason -PowerShellPath $psExe
      if ($clarificationState.clarification_required -eq $true) {
        Write-Host ("CLARIFICATION_REQUIRED issue_id={0} attempt_count={1} scenario={2}" -f $IssueId, $clarificationState.attempt_count, $clarificationState.scenario)
        Write-Host ("[CLARIFICATION_STATE_JSON] " + ($clarificationState | ConvertTo-Json -Depth 8 -Compress))
      }
      Try-PromoteSkillCandidates -RepoPath $repoPath -GovernanceRoot $kitRoot -PowerShellPath $psExe
      throw "Gate step '$($step.name)' failed. log=$($result.log_path)"
    }
  }

  if (-not $SkipWorkIteration.IsPresent -and $MaxWorkIterationsPerCycle -gt 0) {
    if ($subagentDecision.spawn_parallel_subagents) {
      Write-Host ("WORK_ITERATION delegated_to_outer_ai_session mode=parallel max_agents={0}" -f [int]$subagentDecision.max_parallel_agents)
    } else {
      Write-Host "WORK_ITERATION delegated_to_outer_ai_session mode=serial (no-op)"
    }
  }

  if ($skillCandidateRecordedInCycle) {
    Write-Host "[SKILL_TRIGGER_EVAL] skipped reason=skill_candidate_detected_requires_manual_label"
  } else {
    $queryText = "autopilot cycle=$cycle issue_id=$IssueId gate_chain_passed_without_skill_candidate"
    Try-RegisterSkillTriggerEvalRun -RepoPath $repoPath -IssueId $IssueId -Query $queryText -ShouldTrigger $false -Triggered $false -PolicyState $skillPromotionPolicyState -PowerShellPath $psExe | Out-Null
  }
}

Try-PromoteSkillCandidates -RepoPath $repoPath -GovernanceRoot $kitRoot -PowerShellPath $psExe
Write-Host "STATUS: ITERATION_COMPLETE_CONTINUE"
Write-Host "target safe autopilot completed"
Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repoPath -IssueId $IssueId -Scenario $effectiveClarificationScenario -Mode "record" -Outcome "success" -PowerShellPath $psExe | Out-Null

