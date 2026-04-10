param(
  [string]$RepoRoot = ".",
  [string]$GovernanceKitRoot = "",
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

function Resolve-KitRoot {
  param([string]$ProvidedPath)

  if (-not [string]::IsNullOrWhiteSpace($ProvidedPath)) {
    $resolved = Resolve-Path -LiteralPath $ProvidedPath -ErrorAction SilentlyContinue
    if ($null -ne $resolved) { return $resolved.Path }
    throw "Governance kit path not found: $ProvidedPath"
  }

  $gitValue = ""
  try {
    $gitValue = (& git -C $repoPath config --local --get governance.kitRoot 2>$null)
  }
  catch {
    $gitValue = ""
  }

  if (-not [string]::IsNullOrWhiteSpace($gitValue)) {
    $resolved = Resolve-Path -LiteralPath ($gitValue -replace '/', '\\') -ErrorAction SilentlyContinue
    if ($null -ne $resolved) { return $resolved.Path }
  }

  if (-not [string]::IsNullOrWhiteSpace($env:GOVERNANCE_KIT_ROOT)) {
    $resolved = Resolve-Path -LiteralPath $env:GOVERNANCE_KIT_ROOT -ErrorAction SilentlyContinue
    if ($null -ne $resolved) { return $resolved.Path }
  }

  throw "Cannot resolve governance-kit root. Set git config governance.kitRoot or pass -GovernanceKitRoot."
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

$kitRoot = Resolve-KitRoot -ProvidedPath $GovernanceKitRoot
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
Write-Host "governance_kit_root=$kitRoot"
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

  foreach ($step in $gateSteps) {
    if ([string]::IsNullOrWhiteSpace($step.command) -or $step.command -like "N/A*") {
      throw "Required gate step '$($step.name)' is unavailable: $($step.command)"
    }

    $result = Invoke-ShellCommand -Name ("gate." + $step.name) -CommandText $step.command -WorkDir $repoPath -LogRoot $logRoot
    if ($result.exit_code -eq 0) {
      continue
    }

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
      throw "Gate step '$($step.name)' failed. log=$($result.log_path)"
    }
  }

  if (-not $SkipWorkIteration.IsPresent -and $MaxWorkIterationsPerCycle -gt 0) {
    Write-Host "WORK_ITERATION delegated_to_outer_ai_session (no-op)"
  }
}

Write-Host "STATUS: ITERATION_COMPLETE_CONTINUE"
Write-Host "target safe autopilot completed"
Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repoPath -IssueId $IssueId -Scenario $effectiveClarificationScenario -Mode "record" -Outcome "success" -PowerShellPath $psExe | Out-Null
