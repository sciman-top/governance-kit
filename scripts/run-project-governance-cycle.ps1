param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$RepoName,
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
Write-ModeRisk -ScriptName "run-project-governance-cycle.ps1" -Mode $Mode

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
$effectiveSkipOptimize = $SkipOptimize.IsPresent
$effectiveSkipBackflow = $SkipBackflow.IsPresent

if ($AutoRemediate.IsPresent -or $NoAutoRemediate.IsPresent -or $PSBoundParameters.ContainsKey("CodexCommand") -or $PSBoundParameters.ContainsKey("MaxAutoFixAttempts")) {
  Write-Host "[DEPRECATED] in-script auto remediation options are ignored (-AutoRemediate/-NoAutoRemediate/-MaxAutoFixAttempts/-CodexCommand)."
  Write-Host "[POLICY] remediation owner=outer-ai-session (current chat agent), script role=gate orchestrator only."
}

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
    }
    remediation_owner = "outer-ai-session"
    timestamp = (Get-Date).ToString("o")
    failure_message = $FailureMessage
  }
  Write-Host ("[FAILURE_CONTEXT_JSON] " + ($context | ConvertTo-Json -Depth 8 -Compress))
}

function Step-OrFail([string]$Name, [string]$RetryCommand, [scriptblock]$Action) {
  try {
    Step $Name $Action
    return
  } catch {
    $failure = $_.Exception.Message
    Write-Host "[BLOCK] step failed; remediation must be performed by outer AI session."
    Write-FailureContext -StepName $Name -FailureMessage $failure -RetryCommand $RetryCommand
    throw "Step failed: $Name (outer-ai-session remediation required)"
  }
}

if (-not $SkipInstall) {
  $installRetry = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-project-governance-cycle.ps1 -RepoPath `"$($repo -replace '\\','/')`" -RepoName `"$RepoName`" -Mode $Mode"
  Step-OrFail "install" $installRetry {
    $argsInstall = @("-Mode", $Mode)
    if ($ShowScope) { $argsInstall += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsInstall
    Invoke-ChildScript (Join-Path $PSScriptRoot "install-extras.ps1") @("-Mode", $Mode)
  }
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
}

if (-not $effectiveSkipBackflow) {
  Step-OrFail "backflow-project-rules" ("powershell -NoProfile -ExecutionPolicy Bypass -File scripts/backflow-project-rules.ps1 -RepoPath `"$($repo -replace '\\','/')`" -RepoName `"$RepoName`" -Mode $Mode") {
    $argsBackflow = @("-RepoPath", $repo, "-RepoName", $RepoName, "-Mode", $Mode)
    if ($ShowScope) { $argsBackflow += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "backflow-project-rules.ps1") $argsBackflow
  }
}

if ($Mode -eq "safe") {
  Step-OrFail "re-distribute-and-verify" "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1" {
    $argsRedistribute = @("-Mode", "safe")
    if ($ShowScope) { $argsRedistribute += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsRedistribute
    Invoke-ChildScript (Join-Path $PSScriptRoot "doctor.ps1")
  }
}

Write-Host "run-project-governance-cycle completed: repo=$($repo -replace '\\','/') mode=$Mode"
