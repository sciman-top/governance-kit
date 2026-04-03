param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$SkipInstallGlobalGit,
  [switch]$NoOverwriteRules,
  [switch]$SkipAutopilotSmoke,
  [switch]$AutoRemediate,
  [switch]$NoAutoRemediate,
  [ValidateRange(1, 10)]
  [int]$MaxAutoFixAttempts = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$kitRoot = Split-Path -Parent $PSScriptRoot
$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
$repoPolicy = Get-RepoAutomationPolicy -KitRoot $kitRoot -Repo $repo
if ($AutoRemediate.IsPresent -or $NoAutoRemediate.IsPresent) {
  Write-Host "[DEPRECATED] -AutoRemediate/-NoAutoRemediate are ignored. Remediation is handled by the outer AI session."
}

function Run-Step {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )

  Write-Host "=== $Name ==="
  & $Action
  Write-Host "[DONE] $Name"
}

$bootstrapScript = Join-Path $PSScriptRoot "bootstrap-repo.ps1"
$cycleScript = Join-Path $PSScriptRoot "run-project-governance-cycle.ps1"
$doctorScript = Join-Path $PSScriptRoot "doctor.ps1"

if (-not (Test-Path -LiteralPath $bootstrapScript)) { throw "Missing script: $bootstrapScript" }
if (-not (Test-Path -LiteralPath $cycleScript)) { throw "Missing script: $cycleScript" }
if (-not (Test-Path -LiteralPath $doctorScript)) { throw "Missing script: $doctorScript" }

Write-Host ("[POLICY] allow_project_rules={0} allow_rule_optimization={1} allow_local_optimize_without_backflow={2} max_autonomous_iterations={3} max_repeated_failure_per_step={4} stop_on_irreversible_risk={5} allow_auto_fix={6} forbid_breaking_contract={7}" -f `
  $repoPolicy.allow_project_rules, $repoPolicy.allow_rule_optimization, $repoPolicy.allow_local_optimize_without_backflow, $repoPolicy.max_autonomous_iterations, $repoPolicy.max_repeated_failure_per_step, $repoPolicy.stop_on_irreversible_risk, $repoPolicy.allow_auto_fix, $repoPolicy.forbid_breaking_contract)
Write-Host "[POLICY] remediation owner=outer-ai-session (script does not invoke model CLI for auto-fix)."

Run-Step -Name "bootstrap-repo" -Action {
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $bootstrapScript,
    "-RepoPath", $repo,
    "-Mode", $Mode
  )

  if ($SkipInstallGlobalGit.IsPresent) { $args += "-SkipInstallGlobalGit" }
  if ($NoOverwriteRules.IsPresent) { $args += "-NoOverwriteRules" }

  & powershell @args
  if ($LASTEXITCODE -ne 0) {
    throw "bootstrap-repo failed with exit code $LASTEXITCODE"
  }
}

if ($Mode -ne "plan") {
  $hasProjectRuleDocs = @("AGENTS.md", "CLAUDE.md", "GEMINI.md") | ForEach-Object {
    Test-Path -LiteralPath (Join-Path $repo $_)
  }
  $isRuleSeedReady = (@($hasProjectRuleDocs | Where-Object { $_ -eq $true }).Count -eq 3)

  Run-Step -Name "run-project-governance-cycle" -Action {
    $cycleArgs = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $cycleScript,
      "-RepoPath", $repo,
      "-RepoName", (Split-Path -Leaf $repo),
      "-Mode", "safe",
      "-ShowScope"
    )
    if (-not $isRuleSeedReady) {
      Write-Host "[INFO] target repo does not contain AGENTS/CLAUDE/GEMINI yet; running cycle with -SkipOptimize -SkipBackflow for first-time bootstrap."
      $cycleArgs += @("-SkipOptimize", "-SkipBackflow")
    }

    & powershell @cycleArgs
    if ($LASTEXITCODE -ne 0) {
      throw "run-project-governance-cycle failed with exit code $LASTEXITCODE"
    }
  }

  if (-not $SkipAutopilotSmoke.IsPresent) {
    $targetAutopilot = Join-Path $repo "scripts\governance\run-target-autopilot.ps1"
    Run-Step -Name "target-autopilot-smoke" -Action {
      if (-not (Test-Path -LiteralPath $targetAutopilot)) {
        throw "Missing target autopilot script after install: $targetAutopilot"
      }

      & powershell -NoProfile -ExecutionPolicy Bypass -File $targetAutopilot -RepoRoot $repo -GovernanceKitRoot $kitRoot -DryRun
      if ($LASTEXITCODE -ne 0) {
        throw "target autopilot dry-run failed with exit code $LASTEXITCODE"
      }
    }
  }

  Run-Step -Name "doctor" -Action {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $doctorScript
    if ($LASTEXITCODE -ne 0) {
      throw "doctor failed with exit code $LASTEXITCODE"
    }
  }
}

Write-Host "install-full-stack completed: repo=$($repo -replace '\\','/') mode=$Mode"
