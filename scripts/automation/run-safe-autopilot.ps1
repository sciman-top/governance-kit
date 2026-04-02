param(
  [string]$RepoRoot = ".",
  [string]$CodexCommand = "codex",
  [int]$MaxCycles = 20,
  [int]$MaxKitFixAttempts = 2,
  [switch]$RunTargetCycle,
  [string]$TargetRepoPath = "E:/CODE/ClassroomToolkit",
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

$runId = [guid]::NewGuid().ToString("n")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logRoot = Join-Path $repoPath (".locks/logs/safe-autopilot/" + $timestamp + "-" + $runId)
$scriptLock = $null

function Assert-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-LoggedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$WorkDir
  )

  $safeName = ($Name -replace '[^a-zA-Z0-9._-]', '_')
  $file = Join-Path $logRoot ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $safeName + ".log")

  Push-Location $WorkDir
  try {
    & $Action *>&1 | Tee-Object -LiteralPath $file | Out-Host
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if ($null -eq $exitCode) {
    $exitCode = 0
  }

  return [pscustomobject]@{
    name = $Name
    exit_code = [int]$exitCode
    log_path = $file
  }
}

function Invoke-CodexFix {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRoot,
    [Parameter(Mandatory = $true)][string]$Issue,
    [Parameter(Mandatory = $true)][string]$FailureLogPath,
    [Parameter(Mandatory = $true)][string]$Tag
  )

  $promptPath = Join-Path $logRoot ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $Tag + ".prompt.txt")
  $logPath = Join-Path $logRoot ((Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $Tag + ".codex.log")

  $prompt = @"
You are in autonomous remediation mode.

Goal:
- Fix the failure using the smallest safe code change.
- Keep governance semantics and gate order intact.
- Never bypass gates by deleting or weakening checks.

Context:
- issue: $Issue
- failure_log: $FailureLogPath
- target_root: $TargetRoot

Required:
1) Identify root cause from log.
2) Apply minimal fix.
3) Re-run relevant verification commands.
4) Output concise evidence with STATUS lines.
5) Continue autonomously; do not ask for routine confirmation unless blocked by irreversible risk or missing credentials.

Safety:
- Do not run destructive git commands.
- Preserve backwards compatibility for configuration contracts.
- Avoid speculative architecture changes or evidence-free optimization.
"@

  Set-Content -LiteralPath $promptPath -Value $prompt -Encoding UTF8

  Push-Location $TargetRoot
  try {
    $args = @(
      "-a", "never",
      "-s", "workspace-write",
      "exec",
      "--cd", $TargetRoot,
      "-"
    )

    Get-Content -LiteralPath $promptPath -Raw | & $CodexCommand @args *>&1 | Tee-Object -LiteralPath $logPath | Out-Host
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if ($null -eq $exitCode) {
    $exitCode = 0
  }

  return [pscustomobject]@{
    exit_code = [int]$exitCode
    prompt_path = $promptPath
    log_path = $logPath
  }
}

function Invoke-GovernanceGateChain {
  $steps = @(
    [pscustomobject]@{ name = "build.verify-kit"; workdir = $repoPath; action = { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/verify-kit.ps1") } },
    [pscustomobject]@{ name = "test.optimization"; workdir = $repoPath; action = { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "tests/governance-kit.optimization.tests.ps1") } },
    [pscustomobject]@{ name = "contract.validate-config"; workdir = $repoPath; action = { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/validate-config.ps1") } },
    [pscustomobject]@{ name = "contract.verify"; workdir = $repoPath; action = { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/verify.ps1") } },
    [pscustomobject]@{ name = "hotspot.doctor"; workdir = $repoPath; action = { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/doctor.ps1") } }
  )

  foreach ($step in $steps) {
    $result = Invoke-LoggedCommand -Name $step.name -Action $step.action -WorkDir $step.workdir
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
  param([string]$TargetRoot)

  return Invoke-LoggedCommand -Name "target.run-project-governance-cycle" -WorkDir $repoPath -Action {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoPath "scripts/run-project-governance-cycle.ps1") -RepoPath $TargetRoot -RepoName (Split-Path -Leaf $TargetRoot) -Mode safe -ShowScope
  }
}

Assert-Command -Name powershell
Assert-Command -Name $CodexCommand

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

  if ($DryRun) {
    Write-Host "dry_run=true"
    Write-Host "planned_order=build.verify-kit -> test.optimization -> contract.validate-config -> contract.verify -> hotspot.doctor"
    if ($RunTargetCycle.IsPresent) {
      Write-Host "target_cycle=run-project-governance-cycle($TargetRepoPath)"
    }
    return
  }

  for ($cycle = 1; $cycle -le $MaxCycles; $cycle++) {
    Write-Host ""
    Write-Host "=== cycle $cycle / $MaxCycles ==="

    $chain = Invoke-GovernanceGateChain
    if (-not $chain.ok) {
      $fixed = $false
      for ($attempt = 1; $attempt -le $MaxKitFixAttempts; $attempt++) {
        Write-Host "AUTO_FIX governance-kit attempt $attempt/$MaxKitFixAttempts"
        $fix = Invoke-CodexFix -TargetRoot $repoPath -Issue $chain.failed_step -FailureLogPath $chain.log_path -Tag ("kit-fix-" + $cycle + "-" + $attempt)
        if ($fix.exit_code -ne 0) {
          Write-Host "fix invocation failed: $($fix.log_path)"
          continue
        }

        $chain = Invoke-GovernanceGateChain
        if ($chain.ok) {
          $fixed = $true
          break
        }
      }

      if (-not $fixed -and -not $chain.ok) {
        throw "governance gate chain failed after auto-fix attempts. step=$($chain.failed_step) log=$($chain.log_path)"
      }
    }

    if ($RunTargetCycle.IsPresent) {
      $targetResolved = Resolve-Path -LiteralPath $TargetRepoPath -ErrorAction SilentlyContinue
      if ($null -eq $targetResolved) {
        throw "Target repo path not found: $TargetRepoPath"
      }

      $targetResult = Invoke-TargetCycle -TargetRoot $targetResolved.Path
      if ($targetResult.exit_code -ne 0) {
        $targetFixed = $false
        for ($attempt = 1; $attempt -le $MaxTargetFixAttempts; $attempt++) {
          Write-Host "AUTO_FIX target-repo attempt $attempt/$MaxTargetFixAttempts"
          $fix = Invoke-CodexFix -TargetRoot $targetResolved.Path -Issue "target.run-project-governance-cycle" -FailureLogPath $targetResult.log_path -Tag ("target-fix-" + $cycle + "-" + $attempt)
          if ($fix.exit_code -ne 0) {
            Write-Host "target fix invocation failed: $($fix.log_path)"
            continue
          }

          $targetResult = Invoke-TargetCycle -TargetRoot $targetResolved.Path
          if ($targetResult.exit_code -eq 0) {
            $targetFixed = $true
            break
          }
        }

        if (-not $targetFixed -and $targetResult.exit_code -ne 0) {
          throw "target cycle failed after auto-fix attempts. log=$($targetResult.log_path)"
        }
      }
    }
  }

  Write-Host "STATUS: ITERATION_COMPLETE_CONTINUE"
  Write-Host "safe-autopilot completed without unrecovered failures"
}
finally {
  Release-ScriptLock -LockHandle $scriptLock
}
