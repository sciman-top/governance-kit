param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$RepoName,
  [string]$IssueId = "project-governance-cycle-default",
  [ValidateSet("auto", "plan", "requirement", "bugfix", "acceptance")]
  [string]$ClarificationScenario = "auto",
  [string]$ClarificationContextFile = "",
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [switch]$ShowScope,
  [switch]$SkipInstall,
  [switch]$SkipOptimize,
  [switch]$SkipBackflow,
  # Deprecated: remediation is now handled by the outer AI session.
  [switch]$AutoRemediate,
  # Deprecated: remediation is now handled by the outer AI session.
  [switch]$NoAutoRemediate,
  # Deprecated: kept for backward compatibility and ignored.
  [ValidateRange(1, 10)]
  [int]$MaxAutoFixAttempts = 1,
  # Deprecated: kept for backward compatibility and ignored.
  [string]$CodexCommand = "codex"
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
$clarificationTrackerScript = Join-Path $kitRoot "scripts\governance\track-issue-state.ps1"
Write-ModeRisk -ScriptName "run-project-governance-cycle.ps1" -Mode $Mode
if (-not (Test-Path -LiteralPath $clarificationTrackerScript)) {
  throw "Missing clarification tracker script: $clarificationTrackerScript"
}

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
if ([string]::IsNullOrWhiteSpace($RepoName)) {
  $RepoName = Split-Path -Leaf $repo
}
$repoPolicy = Get-RepoAutomationPolicy -KitRoot $kitRoot -Repo $repo
$allowProjectRules = [bool]$repoPolicy.allow_project_rules
$allowRuleOptimization = [bool]$repoPolicy.allow_rule_optimization
$allowLocalOptimizeWithoutBackflow = [bool]$repoPolicy.allow_local_optimize_without_backflow
$maxAutonomousIterations = [int]$repoPolicy.max_autonomous_iterations
$maxRepeatedFailurePerStep = [int]$repoPolicy.max_repeated_failure_per_step
$stopOnIrreversibleRisk = [bool]$repoPolicy.stop_on_irreversible_risk
$allowAutoFixByPolicy = [bool]$repoPolicy.allow_auto_fix
$forbidBreakingContract = [bool]$repoPolicy.forbid_breaking_contract
$autoCommitEnabled = [bool]$repoPolicy.auto_commit_enabled
$autoCommitOnCheckpoints = @($repoPolicy.auto_commit_on_checkpoints)
$autoCommitMessagePrefix = [string]$repoPolicy.auto_commit_message_prefix
$effectiveSkipOptimize = $SkipOptimize.IsPresent
$effectiveSkipBackflow = $SkipBackflow.IsPresent

if ($AutoRemediate.IsPresent -or $NoAutoRemediate.IsPresent -or $PSBoundParameters.ContainsKey("CodexCommand") -or $PSBoundParameters.ContainsKey("MaxAutoFixAttempts")) {
  Write-Host "[DEPRECATED] in-script auto remediation options are ignored (-AutoRemediate/-NoAutoRemediate/-MaxAutoFixAttempts/-CodexCommand)."
  Write-Host "[POLICY] remediation owner=outer-ai-session (current chat agent), script role=gate orchestrator only."
}
Write-Host "[POLICY] when governance issue is found, fix governance-kit first, then let outer-ai-session re-run the cycle."

if (-not $allowProjectRules) {
  if ($allowLocalOptimizeWithoutBackflow) {
    if (-not $effectiveSkipOptimize) {
      Write-Host "[INFO] project rules are not allow-listed for repo; policy allows local optimize without backflow."
    }
    if (-not $effectiveSkipBackflow) {
      Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip backflow-project-rules."
    }
    $effectiveSkipBackflow = $true
  } else {
    if (-not $effectiveSkipOptimize) {
      Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip optimize-project-rules."
    }
    if (-not $effectiveSkipBackflow) {
      Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip backflow-project-rules."
    }
    $effectiveSkipOptimize = $true
    $effectiveSkipBackflow = $true
  }
}
if (-not $allowRuleOptimization -and -not $effectiveSkipOptimize) {
  Write-Host "[INFO] project rule optimization disabled by policy; auto-skip optimize-project-rules."
  $effectiveSkipOptimize = $true
}

Write-Host ("[POLICY] allow_project_rules={0} allow_rule_optimization={1} allow_local_optimize_without_backflow={2} max_autonomous_iterations={3} max_repeated_failure_per_step={4} stop_on_irreversible_risk={5} allow_auto_fix={6} forbid_breaking_contract={7}" -f `
  $allowProjectRules, $allowRuleOptimization, $allowLocalOptimizeWithoutBackflow, $maxAutonomousIterations, $maxRepeatedFailurePerStep, $stopOnIrreversibleRisk, $allowAutoFixByPolicy, $forbidBreakingContract)
Write-Host ("[POLICY] auto_commit_enabled={0} auto_commit_checkpoints={1}" -f $autoCommitEnabled, (@($autoCommitOnCheckpoints) -join ","))

function Get-GitStatusLines() {
  if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    return @()
  }

  $status = (& git -C $repo status --porcelain)
  if ($LASTEXITCODE -ne 0) {
    throw "failed to read git status for repo: $repo"
  }

  $filtered = @()
  foreach ($line in @($status)) {
    $entry = [string]$line
    if ($entry.Length -lt 4) {
      $filtered += $entry
      continue
    }
    $pathPart = ($entry.Substring(3)).Trim()
    $pathNorm = ($pathPart -replace '\\', '/')
    if ($pathNorm.StartsWith(".codex/", [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }
    $filtered += $entry
  }

  return $filtered
}

function Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  & $Action
  Write-Host "[DONE] $Name"
}

function Write-FailureContext([string]$StepName, [string]$FailureMessage, [string]$RetryCommand) {
  $context = [pscustomobject]@{
    failed_step = $StepName
    command = $RetryCommand
    exit_code = 1
    log_path = "N/A (see current session output)"
    repo_path = ($repo -replace '\\', '/')
    repo_name = $RepoName
    gate_order = "build -> test -> contract/invariant -> hotspot"
    retry_command = $RetryCommand
    policy_snapshot = [pscustomobject]@{
      allow_project_rules = $allowProjectRules
      allow_rule_optimization = $allowRuleOptimization
      allow_local_optimize_without_backflow = $allowLocalOptimizeWithoutBackflow
      max_autonomous_iterations = $maxAutonomousIterations
      max_repeated_failure_per_step = $maxRepeatedFailurePerStep
      stop_on_irreversible_risk = $stopOnIrreversibleRisk
      allow_auto_fix = $allowAutoFixByPolicy
      forbid_breaking_contract = $forbidBreakingContract
      auto_commit_enabled = $autoCommitEnabled
      auto_commit_on_checkpoints = @($autoCommitOnCheckpoints)
      auto_commit_message_prefix = $autoCommitMessagePrefix
    }
    remediation_owner = "outer-ai-session"
    remediation_scope = "governance-kit-first"
    rerun_owner = "outer-ai-session"
    timestamp = (Get-Date).ToString("o")
    failure_message = $FailureMessage
  }
  Write-Host ("[FAILURE_CONTEXT_JSON] " + ($context | ConvertTo-Json -Depth 8 -Compress))
}

function Invoke-ClarificationTracker {
  param(
    [Parameter(Mandatory = $true)][string]$Mode,
    [string]$Outcome = "",
    [string]$Reason = ""
  )

  $args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $clarificationTrackerScript,
    "-RepoPath", $repo,
    "-IssueId", $IssueId,
    "-Scenario", $effectiveClarificationScenario,
    "-Mode", $Mode
  )
  if (-not [string]::IsNullOrWhiteSpace($Outcome)) {
    $args += @("-Outcome", $Outcome)
  }
  if (-not [string]::IsNullOrWhiteSpace($Reason)) {
    $args += @("-Reason", $Reason)
  }

  $json = & powershell @args
  if ($LASTEXITCODE -ne 0) {
    throw "clarification tracker failed with exit code $LASTEXITCODE"
  }

  return [string]::Join([Environment]::NewLine, @($json)) | ConvertFrom-Json
}

function Resolve-EffectiveClarificationScenario {
  param(
    [string]$RequestedScenario,
    [string]$CurrentMode,
    [string]$ContextFile
  )

  if ($RequestedScenario -ne "auto" -and -not [string]::IsNullOrWhiteSpace($RequestedScenario)) {
    return [pscustomobject]@{
      scenario = $RequestedScenario
      source = "param"
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($ContextFile) -and (Test-Path -LiteralPath $ContextFile)) {
    try {
      $ctx = Get-Content -LiteralPath $ContextFile -Raw | ConvertFrom-Json
      $ctxScenario = ""
      if ($null -ne $ctx.PSObject.Properties['clarification_scenario']) {
        $ctxScenario = [string]$ctx.clarification_scenario
      } elseif ($null -ne $ctx.PSObject.Properties['scenario']) {
        $ctxScenario = [string]$ctx.scenario
      }
      $valid = @("plan", "requirement", "bugfix", "acceptance")
      if ($valid -contains $ctxScenario) {
        return [pscustomobject]@{
          scenario = $ctxScenario
          source = "context_file"
        }
      }
    } catch {
      Write-Host ("[WARN] clarification context parse failed: {0}" -f $ContextFile)
    }
  }

  if ($CurrentMode -eq "plan") {
    return [pscustomobject]@{
      scenario = "plan"
      source = "mode"
    }
  }

  return [pscustomobject]@{
    scenario = "bugfix"
    source = "fallback"
  }
}

function Step-OrFail([string]$Name, [string]$RetryCommand, [scriptblock]$Action) {
  try {
    Step $Name $Action
    return
  } catch {
    $failure = $_.Exception.Message
    $clarificationState = Invoke-ClarificationTracker -Mode "record" -Outcome "failure" -Reason ("step={0}; {1}" -f $Name, $failure)
    Write-Host "[BLOCK] step failed; fix governance-kit first when the issue belongs to governance flow, then let outer AI session re-run."
    if ($clarificationState.clarification_required -eq $true) {
      Write-Host ("CLARIFICATION_REQUIRED issue_id={0} attempt_count={1} scenario={2}" -f $IssueId, $clarificationState.attempt_count, $clarificationState.scenario)
      Write-Host ("[CLARIFICATION_STATE_JSON] " + ($clarificationState | ConvertTo-Json -Depth 8 -Compress))
    }
    Write-FailureContext -StepName $Name -FailureMessage $failure -RetryCommand $RetryCommand
    throw "Step failed: $Name (outer-ai-session remediation required)"
  }
}

function Invoke-MilestoneAutoCommit([string]$Checkpoint) {
  if ($Mode -ne "safe") { return }
  if (-not $autoCommitEnabled) { return }
  if (@($autoCommitOnCheckpoints).Count -eq 0) { return }
  if (-not (@($autoCommitOnCheckpoints) -contains $Checkpoint)) { return }

  if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    Write-Host "[AUTO_COMMIT] skip (not a git repo): checkpoint=$Checkpoint repo=$repo"
    return
  }

  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if ($null -eq $gitCmd) {
    throw "auto commit requires git command, but git was not found."
  }

  $statusBefore = (& git -C $repo status --porcelain)
  if ($LASTEXITCODE -ne 0) {
    throw "auto commit failed to read git status at checkpoint '$Checkpoint'."
  }
  if (@($statusBefore).Count -eq 0) {
    Write-Host "[AUTO_COMMIT] no changes: checkpoint=$Checkpoint"
    return
  }

  $trackedScript = Join-Path $PSScriptRoot "governance\check-tracked-files.ps1"
  if (-not (Test-Path -LiteralPath $trackedScript -PathType Leaf)) {
    throw "auto commit precheck script not found: $trackedScript"
  }
  $trackedPolicyPath = Join-Path $repo ".governance\tracked-files-policy.json"
  $trackedResult = & powershell -NoProfile -ExecutionPolicy Bypass -File $trackedScript -RepoPath $repo -PolicyPath $trackedPolicyPath -Scope pending -AsJson
  $trackedExitCode = $LASTEXITCODE
  $trackedJsonText = [string]::Join([Environment]::NewLine, @($trackedResult))
  $trackedObj = $null
  if (-not [string]::IsNullOrWhiteSpace($trackedJsonText)) {
    try {
      $trackedObj = $trackedJsonText | ConvertFrom-Json
    } catch {
      $trackedObj = $null
    }
  }
  if ($null -ne $trackedObj -and $trackedObj.PSObject.Properties['blocked'] -and [bool]$trackedObj.blocked) {
    throw "auto commit blocked by tracked files policy at checkpoint '$Checkpoint'."
  }
  if ($trackedExitCode -eq 2) {
    throw "auto commit blocked by tracked files policy at checkpoint '$Checkpoint'."
  }
  if ($trackedExitCode -ne 0) {
    throw "auto commit precheck failed at checkpoint '$Checkpoint' (tracked files policy check)."
  }
  if (-not [string]::IsNullOrWhiteSpace([string]($trackedResult | Out-String))) {
    Write-Host ("[AUTO_COMMIT_PRECHECK] " + (($trackedResult | Out-String).Trim()))
  }

  & git -C $repo add -A
  if ($LASTEXITCODE -ne 0) {
    throw "auto commit failed at 'git add -A' for checkpoint '$Checkpoint'."
  }

  $statusStaged = (& git -C $repo status --porcelain)
  if ($LASTEXITCODE -ne 0) {
    throw "auto commit failed to read staged status at checkpoint '$Checkpoint'."
  }
  if (@($statusStaged).Count -eq 0) {
    Write-Host "[AUTO_COMMIT] no staged changes after add: checkpoint=$Checkpoint"
    return
  }

  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $prefix = if ([string]::IsNullOrWhiteSpace($autoCommitMessagePrefix)) { "治理里程碑自动提交" } else { $autoCommitMessagePrefix }
  $commitMsg = "$prefix：$RepoName [$Checkpoint] $ts"

  & git -C $repo commit -m $commitMsg | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "auto commit failed at checkpoint '$Checkpoint'."
  }

  $statusAfter = (& git -C $repo status --porcelain)
  if ($LASTEXITCODE -ne 0) {
    throw "auto commit failed to verify clean working tree at checkpoint '$Checkpoint'."
  }
  if (@($statusAfter).Count -gt 0) {
    throw "auto commit completed but working tree is not clean at checkpoint '$Checkpoint'."
  }

  Write-Host "[AUTO_COMMIT] committed and clean: checkpoint=$Checkpoint"
}

function Assert-CleanCheckpoint([string]$Checkpoint) {
  if ($Mode -ne "safe") { return }
  if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) { return }

  $statusLines = @(Get-GitStatusLines)
  if ($statusLines.Count -gt 0) {
    $preview = (@($statusLines | Select-Object -First 20) -join "; ")
    throw ("clean checkpoint failed at '{0}': working tree is not clean. dirty_entries={1}. preview={2}" -f $Checkpoint, $statusLines.Count, $preview)
  }

  Write-Host "[ASSERT] clean checkpoint passed: checkpoint=$Checkpoint"
}

function Assert-PreflightWorkspaceClean() {
  if ($Mode -ne "safe") { return }
  if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) { return }

  $statusLines = @(Get-GitStatusLines)
  if ($statusLines.Count -eq 0) {
    Write-Host "[ASSERT] preflight clean workspace passed"
    return
  }

  $preview = (@($statusLines | Select-Object -First 20) -join "; ")
  throw ("preflight failed: repo has pre-existing dirty entries ({0}). isolate non-governance changes before cycle. preview={1}" -f $statusLines.Count, $preview)
}

Assert-PreflightWorkspaceClean
$scenarioResolution = Resolve-EffectiveClarificationScenario -RequestedScenario $ClarificationScenario -CurrentMode $Mode -ContextFile $ClarificationContextFile
$effectiveClarificationScenario = [string]$scenarioResolution.scenario
$clarificationScenarioSource = [string]$scenarioResolution.source
Write-Host ("[CLARIFICATION] issue_id={0} scenario={1} source={2}" -f $IssueId, $effectiveClarificationScenario, $clarificationScenarioSource)
$clarificationState = Invoke-ClarificationTracker -Mode "evaluate"
if ($clarificationState.clarification_required -eq $true) {
  Write-Host ("CLARIFICATION_REQUIRED issue_id={0} attempt_count={1} scenario={2}" -f $IssueId, $clarificationState.attempt_count, $clarificationState.scenario)
}

if (-not $SkipInstall) {
  $installRetry = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-project-governance-cycle.ps1 -RepoPath `"$($repo -replace '\\','/')`" -RepoName `"$RepoName`" -Mode $Mode"
  Step-OrFail "install" $installRetry {
    $argsInstall = @("-Mode", $Mode)
    if ($ShowScope) { $argsInstall += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsInstall
    Invoke-ChildScript (Join-Path $PSScriptRoot "install-extras.ps1") @("-Mode", $Mode)
  }
  Invoke-MilestoneAutoCommit -Checkpoint "after_install"
}

Step-OrFail "analyze" ("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/analyze-repo-governance.ps1 -RepoPath `"$($repo -replace '\\','/')`"") {
  Invoke-ChildScript (Join-Path $PSScriptRoot "analyze-repo-governance.ps1") @("-RepoPath", $repo)
}

Step-OrFail "custom-policy-check" ("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/suggest-project-custom-files.ps1 -RepoPath `"$($repo -replace '\\','/')`" -RepoName `"$RepoName`"") {
  $customFiles = @(Get-ProjectCustomFilesForRepo -KitRoot $kitRoot -RepoPath $repo -RepoName $RepoName)
  if ($customFiles.Count -eq 0) {
    Write-Host "[WARN] custom policy is empty for repo: $RepoName"
    Write-Host "[ACTION] running candidate scan: suggest-project-custom-files.ps1"
    Invoke-ChildScript (Join-Path $PSScriptRoot "suggest-project-custom-files.ps1") @("-RepoPath", $repo, "-RepoName", $RepoName)
    Write-Host "[HINT] review candidates and update config/project-custom-files.json before backflow"
  } else {
    Write-Host "[INFO] custom policy files configured: $($customFiles.Count)"
  }
}

if (-not $effectiveSkipOptimize) {
  Step-OrFail "optimize-project-rules" ("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/optimize-project-rules.ps1 -RepoPath `"$($repo -replace '\\','/')`" -Mode $Mode") {
    $argsOptimize = @("-RepoPath", $repo, "-Mode", $Mode)
    if ($ShowScope) { $argsOptimize += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "optimize-project-rules.ps1") $argsOptimize
  }
  Invoke-MilestoneAutoCommit -Checkpoint "after_optimize"
}

if (-not $effectiveSkipBackflow) {
  Step-OrFail "backflow-project-rules" ("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/backflow-project-rules.ps1 -RepoPath `"$($repo -replace '\\','/')`" -RepoName `"$RepoName`" -Mode $Mode") {
    $argsBackflow = @("-RepoPath", $repo, "-RepoName", $RepoName, "-Mode", $Mode)
    if ($ShowScope) { $argsBackflow += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "backflow-project-rules.ps1") $argsBackflow
  }
  Invoke-MilestoneAutoCommit -Checkpoint "after_backflow"
}

if ($Mode -eq "safe") {
  Step-OrFail "re-distribute-and-verify" "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1" {
    $argsRedistribute = @("-Mode", "safe")
    if ($ShowScope) { $argsRedistribute += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsRedistribute
    Invoke-ChildScript (Join-Path $PSScriptRoot "doctor.ps1")
  }
  Invoke-MilestoneAutoCommit -Checkpoint "after_redistribute_verify"
}

Invoke-MilestoneAutoCommit -Checkpoint "cycle_complete"
Assert-CleanCheckpoint -Checkpoint "cycle_complete"

Write-Host "run-project-governance-cycle completed: repo=$($repo -replace '\\','/') mode=$Mode"
Invoke-ClarificationTracker -Mode "record" -Outcome "success" | Out-Null
