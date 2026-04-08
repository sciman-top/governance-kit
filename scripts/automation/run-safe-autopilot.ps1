param(
  [string]$RepoRoot = ".",
  # Deprecated: remediation is now handled by the outer AI session.
  [string]$CodexCommand = "codex",
  [int]$MaxCycles = 20,
  # Deprecated: kept for backward compatibility and ignored.
  [int]$MaxKitFixAttempts = 2,
  [switch]$RunTargetCycle,
  [string]$TargetRepoPath = "E:/CODE/ClassroomToolkit",
  # Deprecated: kept for backward compatibility and ignored.
  [int]$MaxTargetFixAttempts = 1,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$commonPath = Join-Path $repoPath "scripts/lib/common.ps1"
if (-not (Test-Path -LiteralPath $commonPath)) {
  throw "Missing common helper: $commonPath"
}

. $commonPath
$psExe = Get-CurrentPowerShellPath

$runId = [guid]::NewGuid().ToString("n")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logRoot = Join-Path $repoPath (".locks/logs/safe-autopilot/" + $timestamp + "-" + $runId)
$scriptLock = $null
$kitPolicy = $null
$kitAllowAutoFix = $true
$effectiveMaxCycles = 1
$effectiveMaxRepeatedFailurePerStep = 1
$stopOnIrreversibleRisk = $true
$failureCounts = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Invoke-GovernanceGateChain {
  $steps = @(
    [pscustomobject]@{ name = "build.verify-kit"; workdir = $repoPath; action = { & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/verify-kit.ps1") } },
    [pscustomobject]@{ name = "test.optimization"; workdir = $repoPath; action = { & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "tests/governance-kit.optimization.tests.ps1") } },
    [pscustomobject]@{ name = "contract.validate-config"; workdir = $repoPath; action = { & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/validate-config.ps1") } },
    [pscustomobject]@{ name = "contract.verify"; workdir = $repoPath; action = { & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/verify.ps1") } },
    [pscustomobject]@{ name = "hotspot.doctor"; workdir = $repoPath; action = { & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/doctor.ps1") } }
  )

  foreach ($step in $steps) {
    $result = Invoke-LoggedCommand -Name $step.name -Action $step.action -WorkDir $step.workdir -LogRoot $logRoot
    if ($result.exit_code -ne 0) {
      return [pscustomobject]@{
        ok = $false
        failed_step = $step.name
        log_path = $result.log_path
      }
    }
  }

  return [pscustomobject]@{
    ok = $true
    failed_step = ""
    log_path = ""
  }
}

function Invoke-TargetCycle {
  param(
    [string]$TargetRoot,
    [object]$TargetPolicy
  )

  $cycleArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $repoPath "scripts/run-project-governance-cycle.ps1"),
    "-RepoPath", $TargetRoot,
    "-RepoName", (Split-Path -Leaf $TargetRoot),
    "-Mode", "safe",
    "-ShowScope"
  )
  if ($null -ne $TargetPolicy -and -not [bool]$TargetPolicy.allow_rule_optimization) {
    $cycleArgs += "-SkipOptimize"
  }

  return Invoke-LoggedCommand -Name "target.run-project-governance-cycle" -WorkDir $repoPath -LogRoot $logRoot -Action {
    & $psExe @cycleArgs
  }
}

function Is-IrreversibleRiskBoundary {
  param([string]$FailedStep)

  if ([string]::IsNullOrWhiteSpace($FailedStep)) { return $false }
  return $FailedStep.StartsWith("contract.", [System.StringComparison]::OrdinalIgnoreCase)
}

function New-SafeAutopilotRetryCommand {
  param([string]$RepoPathText, [int]$MaxCyclesValue)
  return "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -RepoRoot `"$($RepoPathText -replace '\\','/')`" -MaxCycles $MaxCyclesValue"
}

function New-TargetCycleRetryCommand {
  param([string]$TargetRepoPathText)
  return "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-project-governance-cycle.ps1 -RepoPath `"$($TargetRepoPathText -replace '\\','/')`" -RepoName `"$((Split-Path -Leaf $TargetRepoPathText))`" -Mode safe -ShowScope"
}

function Write-FailureContextAndThrow {
  param(
    [Parameter(Mandatory = $true)][string]$FailedStep,
    [Parameter(Mandatory = $true)][int]$ExitCode,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$Command,
    [Parameter(Mandatory = $true)][string]$RetryCommand,
    [Parameter(Mandatory = $true)][object]$PolicySnapshot,
    [Parameter(Mandatory = $true)][string]$StopReason,
    [Parameter(Mandatory = $true)][string]$FailureMessage
  )

  $context = [pscustomobject]@{
    failed_step = $FailedStep
    command = $Command
    exit_code = $ExitCode
    log_path = $LogPath
    repo_path = ($repoPath -replace '\\', '/')
    gate_order = "build -> test -> contract/invariant -> hotspot"
    retry_command = $RetryCommand
    policy_snapshot = $PolicySnapshot
    remediation_owner = "outer-ai-session"
    remediation_scope = "governance-kit-first"
    rerun_owner = "outer-ai-session"
    timestamp = (Get-Date).ToString("o")
    stop_reason = $StopReason
    autonomous_limits = [pscustomobject]@{
      max_autonomous_iterations = $effectiveMaxCycles
      max_repeated_failure_per_step = $effectiveMaxRepeatedFailurePerStep
      stop_on_irreversible_risk = $stopOnIrreversibleRisk
    }
    failure_message = $FailureMessage
  }
  Write-Host "[BLOCK] governance execution stopped by policy boundary; fix governance-kit first when the issue belongs to governance flow, then let outer AI session re-run."
  Write-Host ("[FAILURE_CONTEXT_JSON] " + ($context | ConvertTo-Json -Depth 8 -Compress))
  throw $FailureMessage
}

Assert-Command -Name powershell
$kitPolicy = Get-RepoAutomationPolicy -KitRoot $repoPath -Repo $repoPath
$kitAllowAutoFix = [bool]$kitPolicy.allow_auto_fix
$policyMaxCycles = [Math]::Max(1, [int]$kitPolicy.max_autonomous_iterations)
$effectiveMaxCycles = [Math]::Min([Math]::Max(1, [int]$MaxCycles), $policyMaxCycles)
$effectiveMaxRepeatedFailurePerStep = [Math]::Max(1, [int]$kitPolicy.max_repeated_failure_per_step)
$stopOnIrreversibleRisk = [bool]$kitPolicy.stop_on_irreversible_risk
if ($PSBoundParameters.ContainsKey("CodexCommand") -or $PSBoundParameters.ContainsKey("MaxKitFixAttempts") -or $PSBoundParameters.ContainsKey("MaxTargetFixAttempts")) {
  Write-Host "[DEPRECATED] in-script auto remediation options are ignored (-CodexCommand/-MaxKitFixAttempts/-MaxTargetFixAttempts)."
  Write-Host "[POLICY] remediation owner=outer-ai-session (current chat agent), script role=gate orchestrator only."
}
Write-Host "[POLICY] when governance issue is found, fix governance-kit first, then let outer-ai-session re-run."

if (-not (Test-Path -LiteralPath (Join-Path $repoPath "scripts/verify-kit.ps1"))) { throw "Missing scripts/verify-kit.ps1" }
if (-not (Test-Path -LiteralPath (Join-Path $repoPath "tests/governance-kit.optimization.tests.ps1"))) { throw "Missing tests/governance-kit.optimization.tests.ps1" }
if (-not (Test-Path -LiteralPath (Join-Path $repoPath "scripts/validate-config.ps1"))) { throw "Missing scripts/validate-config.ps1" }
if (-not (Test-Path -LiteralPath (Join-Path $repoPath "scripts/verify.ps1"))) { throw "Missing scripts/verify.ps1" }
if (-not (Test-Path -LiteralPath (Join-Path $repoPath "scripts/doctor.ps1"))) { throw "Missing scripts/doctor.ps1" }

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$scriptLock = New-ScriptLock -KitRoot $repoPath -LockName "safe-autopilot" -TimeoutSeconds 15

try {
  Write-Host "SAFE_AUTOPILOT"
  Write-Host "run_id=$runId"
  Write-Host "repo_root=$repoPath"
  Write-Host "logs=$logRoot"
  Write-Host "target_cycle_enabled=$($RunTargetCycle.IsPresent)"
  Write-Host "policy.kit.allow_auto_fix=$kitAllowAutoFix"
  Write-Host "policy.kit.allow_rule_optimization=$($kitPolicy.allow_rule_optimization)"
  Write-Host "policy.kit.allow_local_optimize_without_backflow=$($kitPolicy.allow_local_optimize_without_backflow)"
  Write-Host "policy.kit.max_autonomous_iterations=$policyMaxCycles"
  Write-Host "policy.kit.max_repeated_failure_per_step=$effectiveMaxRepeatedFailurePerStep"
  Write-Host "policy.kit.stop_on_irreversible_risk=$stopOnIrreversibleRisk"
  if ($effectiveMaxCycles -lt $MaxCycles) {
    Write-Host "[LIMIT] requested MaxCycles=$MaxCycles capped to policy max_autonomous_iterations=$effectiveMaxCycles"
  }

  if ($DryRun) {
    Write-Host "dry_run=true"
    Write-Host "planned_order=build.verify-kit -> test.optimization -> contract.validate-config -> contract.verify -> hotspot.doctor"
    Write-Host "planned_limits.max_autonomous_iterations=$effectiveMaxCycles"
    Write-Host "planned_limits.max_repeated_failure_per_step=$effectiveMaxRepeatedFailurePerStep"
    Write-Host "planned_limits.stop_on_irreversible_risk=$stopOnIrreversibleRisk"
    if ($RunTargetCycle.IsPresent) {
      Write-Host "target_cycle=run-project-governance-cycle($TargetRepoPath)"
    }
    return
  }

  for ($cycle = 1; $cycle -le $effectiveMaxCycles; $cycle++) {
    Write-Host ""
    Write-Host "=== cycle $cycle / $effectiveMaxCycles ==="

    $chain = Invoke-GovernanceGateChain
    if (-not $chain.ok) {
      $stepName = [string]$chain.failed_step
      if (-not $failureCounts.ContainsKey($stepName)) { $failureCounts[$stepName] = 0 }
      $failureCounts[$stepName] = $failureCounts[$stepName] + 1
      $count = $failureCounts[$stepName]
      $retryCmd = New-SafeAutopilotRetryCommand -RepoPathText $repoPath -MaxCyclesValue $effectiveMaxCycles
      $policySnapshot = [pscustomobject]@{
        allow_auto_fix = $kitAllowAutoFix
        allow_rule_optimization = [bool]$kitPolicy.allow_rule_optimization
        allow_local_optimize_without_backflow = [bool]$kitPolicy.allow_local_optimize_without_backflow
        max_autonomous_iterations = $effectiveMaxCycles
        max_repeated_failure_per_step = $effectiveMaxRepeatedFailurePerStep
        stop_on_irreversible_risk = $stopOnIrreversibleRisk
      }

      if ($stopOnIrreversibleRisk -and (Is-IrreversibleRiskBoundary -FailedStep $stepName)) {
        Write-FailureContextAndThrow -FailedStep $stepName -ExitCode 1 -LogPath $chain.log_path -Command $retryCmd -RetryCommand $retryCmd -PolicySnapshot $policySnapshot -StopReason "IRREVERSIBLE_RISK_BOUNDARY" -FailureMessage "governance gate chain failed at irreversible boundary. step=$stepName log=$($chain.log_path)"
      }

      if ($count -lt $effectiveMaxRepeatedFailurePerStep) {
        Write-Host "[AUTO-RETRY] failed_step=$stepName attempt=$count/$effectiveMaxRepeatedFailurePerStep policy=repeat-failure-boundary"
        continue
      }

      Write-FailureContextAndThrow -FailedStep $stepName -ExitCode 1 -LogPath $chain.log_path -Command $retryCmd -RetryCommand $retryCmd -PolicySnapshot $policySnapshot -StopReason "REPEATED_FAILURE_LIMIT" -FailureMessage "governance gate chain failed. step=$stepName failures=$count/$effectiveMaxRepeatedFailurePerStep log=$($chain.log_path)"
    }

    $failureCounts.Clear()

    if ($RunTargetCycle.IsPresent) {
      $targetResolved = Resolve-Path -LiteralPath $TargetRepoPath -ErrorAction SilentlyContinue
      if ($null -eq $targetResolved) {
        throw "Target repo path not found: $TargetRepoPath"
      }
      $targetPolicy = Get-RepoAutomationPolicy -KitRoot $repoPath -Repo $targetResolved.Path
      $targetAllowAutoFix = [bool]$targetPolicy.allow_auto_fix
      Write-Host "policy.target.allow_auto_fix=$targetAllowAutoFix"
      Write-Host "policy.target.allow_rule_optimization=$($targetPolicy.allow_rule_optimization)"
      Write-Host "policy.target.allow_local_optimize_without_backflow=$($targetPolicy.allow_local_optimize_without_backflow)"
      Write-Host "policy.target.max_autonomous_iterations=$($targetPolicy.max_autonomous_iterations)"
      Write-Host "policy.target.max_repeated_failure_per_step=$($targetPolicy.max_repeated_failure_per_step)"
      Write-Host "policy.target.stop_on_irreversible_risk=$($targetPolicy.stop_on_irreversible_risk)"

      $targetResult = Invoke-TargetCycle -TargetRoot $targetResolved.Path -TargetPolicy $targetPolicy
      if ($targetResult.exit_code -ne 0) {
        $targetStepName = "target.run-project-governance-cycle"
        if (-not $failureCounts.ContainsKey($targetStepName)) { $failureCounts[$targetStepName] = 0 }
        $failureCounts[$targetStepName] = $failureCounts[$targetStepName] + 1
        $targetCount = $failureCounts[$targetStepName]
        $targetRetry = New-TargetCycleRetryCommand -TargetRepoPathText $targetResolved.Path
        $targetPolicySnapshot = [pscustomobject]@{
          allow_auto_fix = $targetAllowAutoFix
          allow_rule_optimization = [bool]$targetPolicy.allow_rule_optimization
          allow_local_optimize_without_backflow = [bool]$targetPolicy.allow_local_optimize_without_backflow
          max_autonomous_iterations = [int]$targetPolicy.max_autonomous_iterations
          max_repeated_failure_per_step = [int]$targetPolicy.max_repeated_failure_per_step
          stop_on_irreversible_risk = [bool]$targetPolicy.stop_on_irreversible_risk
        }
        if ($targetCount -lt $effectiveMaxRepeatedFailurePerStep) {
          Write-Host "[AUTO-RETRY] failed_step=$targetStepName attempt=$targetCount/$effectiveMaxRepeatedFailurePerStep policy=repeat-failure-boundary"
          continue
        }
        Write-FailureContextAndThrow -FailedStep $targetStepName -ExitCode ([int]$targetResult.exit_code) -LogPath $targetResult.log_path -Command $targetRetry -RetryCommand $targetRetry -PolicySnapshot $targetPolicySnapshot -StopReason "REPEATED_FAILURE_LIMIT" -FailureMessage "target cycle failed. failures=$targetCount/$effectiveMaxRepeatedFailurePerStep log=$($targetResult.log_path)"
      }
    }
  }

  Write-Host "STATUS: ITERATION_COMPLETE_CONTINUE"
  Write-Host "safe-autopilot completed without unrecovered failures"
}
finally {
  Release-ScriptLock -LockHandle $scriptLock
}
