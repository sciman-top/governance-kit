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
  [switch]$AutoRemediate,
  [switch]$NoAutoRemediate,
  [ValidateRange(1, 10)]
  [int]$MaxAutoFixAttempts = 1,
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
$allowAutoFixByPolicy = [bool]$repoPolicy.allow_auto_fix
$forbidBreakingContract = [bool]$repoPolicy.forbid_breaking_contract
$effectiveSkipOptimize = $SkipOptimize.IsPresent
$effectiveSkipBackflow = $SkipBackflow.IsPresent

if ($AutoRemediate.IsPresent -and $NoAutoRemediate.IsPresent) {
  throw "Conflicting arguments: use either -AutoRemediate or -NoAutoRemediate, not both."
}

$requestedAutoRemediate = $false
if ($AutoRemediate.IsPresent) {
  $requestedAutoRemediate = $true
} elseif ($NoAutoRemediate.IsPresent) {
  $requestedAutoRemediate = $false
} else {
  # Default to autonomous remediation in safe mode.
  $requestedAutoRemediate = $Mode -eq "safe"
}

$enableAutoRemediate = $requestedAutoRemediate -and $allowAutoFixByPolicy
if (-not $allowProjectRules) {
  if (-not $effectiveSkipOptimize) {
    Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip optimize-project-rules."
  }
  if (-not $effectiveSkipBackflow) {
    Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip backflow-project-rules."
  }
  $effectiveSkipOptimize = $true
  $effectiveSkipBackflow = $true
}
if (-not $allowRuleOptimization -and -not $effectiveSkipOptimize) {
  Write-Host "[INFO] project rule optimization disabled by policy; auto-skip optimize-project-rules."
  $effectiveSkipOptimize = $true
}
if ($requestedAutoRemediate -and -not $allowAutoFixByPolicy) {
  Write-Host "[INFO] auto remediation requested but blocked by policy; continue without auto remediation."
}
if ($enableAutoRemediate -and -not (Get-Command $CodexCommand -ErrorAction SilentlyContinue)) {
  Write-Host "[WARN] codex command not found ($CodexCommand); continue without auto remediation."
  $enableAutoRemediate = $false
}

Write-Host ("[POLICY] allow_project_rules={0} allow_rule_optimization={1} allow_auto_fix={2} forbid_breaking_contract={3}" -f `
  $allowProjectRules, $allowRuleOptimization, $allowAutoFixByPolicy, $forbidBreakingContract)
Write-Host ("[AUTO_REMEDIATE] requested={0} effective={1}" -f $requestedAutoRemediate, $enableAutoRemediate)

function Invoke-CodexAutoFix([string]$StepName, [string]$FailureMessage, [int]$Attempt) {
  $logRoot = Join-Path $kitRoot ".locks\logs\project-governance-cycle"
  if (-not (Test-Path -LiteralPath $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
  }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $promptPath = Join-Path $logRoot ("$stamp-$($RepoName)-$($StepName -replace '[^a-zA-Z0-9._-]', '_')-attempt$Attempt.prompt.txt")
  $outputPath = Join-Path $logRoot ("$stamp-$($RepoName)-$($StepName -replace '[^a-zA-Z0-9._-]', '_')-attempt$Attempt.codex.log")

  $prompt = @"
You are authorized to run automatic remediation for governance-kit one-click install.

Task:
- fix failure step: $StepName
- target repository: $repo
- governance-kit root: $kitRoot
- mode: $Mode
- attempt: $Attempt/$MaxAutoFixAttempts

Failure:
$FailureMessage

Rules:
1) Keep gate order unchanged: build -> test -> contract/invariant -> hotspot.
2) Preserve backward compatibility for config and rule contracts.
3) Do not weaken, remove, or bypass validation checks.
4) Optimize legacy project rule files only when it preserves existing semantics.
5) Make minimal safe changes, then stop.
"@
  Set-Content -LiteralPath $promptPath -Value $prompt -Encoding UTF8

  Push-Location $kitRoot
  try {
    $args = @(
      "-a", "never",
      "-s", "workspace-write",
      "exec",
      "--cd", $kitRoot,
      "-"
    )
    Get-Content -LiteralPath $promptPath -Raw | & $CodexCommand @args *>&1 | Tee-Object -LiteralPath $outputPath | Out-Host
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }

  if ($null -eq $exitCode) {
    $exitCode = 0
  }
  return [pscustomobject]@{
    exit_code = [int]$exitCode
    prompt_path = $promptPath
    log_path = $outputPath
  }
}

function Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  & $Action
  Write-Host "[DONE] $Name"
}

function Step-WithAutoRemediate([string]$Name, [scriptblock]$Action) {
  try {
    Step $Name $Action
    return
  } catch {
    if (-not $enableAutoRemediate) {
      throw
    }

    $failure = $_.Exception.Message
    Write-Host "[AUTO_FIX] step failed: $Name"
    for ($attempt = 1; $attempt -le $MaxAutoFixAttempts; $attempt++) {
      Write-Host "[AUTO_FIX] attempt $attempt/$MaxAutoFixAttempts"
      $fix = Invoke-CodexAutoFix -StepName $Name -FailureMessage $failure -Attempt $attempt
      if ($fix.exit_code -ne 0) {
        Write-Host "[AUTO_FIX] codex invocation failed: $($fix.log_path)"
        continue
      }
      try {
        Step $Name $Action
        Write-Host "[AUTO_FIX] recovered by codex remediation"
        return
      } catch {
        $failure = $_.Exception.Message
        Write-Host "[AUTO_FIX] retry failed: $failure"
      }
    }

    throw "Step failed after auto remediation: $Name"
  }
}

if (-not $SkipInstall) {
  Step-WithAutoRemediate "install" {
    $argsInstall = @("-Mode", $Mode)
    if ($ShowScope) { $argsInstall += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsInstall
    Invoke-ChildScript (Join-Path $PSScriptRoot "install-extras.ps1") @("-Mode", $Mode)
  }
}

Step-WithAutoRemediate "analyze" {
  Invoke-ChildScript (Join-Path $PSScriptRoot "analyze-repo-governance.ps1") @("-RepoPath", $repo)
}

Step-WithAutoRemediate "custom-policy-check" {
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
  Step-WithAutoRemediate "optimize-project-rules" {
    $argsOptimize = @("-RepoPath", $repo, "-Mode", $Mode)
    if ($ShowScope) { $argsOptimize += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "optimize-project-rules.ps1") $argsOptimize
  }
}

if (-not $effectiveSkipBackflow) {
  Step-WithAutoRemediate "backflow-project-rules" {
    $argsBackflow = @("-RepoPath", $repo, "-RepoName", $RepoName, "-Mode", $Mode)
    if ($ShowScope) { $argsBackflow += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "backflow-project-rules.ps1") $argsBackflow
  }
}

if ($Mode -eq "safe") {
  Step-WithAutoRemediate "re-distribute-and-verify" {
    $argsRedistribute = @("-Mode", "safe")
    if ($ShowScope) { $argsRedistribute += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsRedistribute
    Invoke-ChildScript (Join-Path $PSScriptRoot "doctor.ps1")
  }
}

Write-Host "run-project-governance-cycle completed: repo=$($repo -replace '\\','/') mode=$Mode"
