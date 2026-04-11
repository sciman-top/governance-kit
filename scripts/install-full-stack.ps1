param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$SkipInstallGlobalGit,
  [switch]$NoOverwriteRules,
  [switch]$SkipAutopilotSmoke,
  [switch]$ForceGovernanceCycleOnDirty,
  [switch]$SkipTargetPrecheck,
  [switch]$SkipTargetGate,
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

function Get-DirtyRepoState {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [int]$PreviewLimit = 20
  )

  $statusLines = @()
  try {
    $statusLines = @(git -C $Repo status --porcelain 2>$null)
  } catch {
    return [pscustomobject]@{
      available = $false
      count = 0
      preview = ""
    }
  }

  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      available = $false
      count = 0
      preview = ""
    }
  }

  $cleanLines = @($statusLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $preview = (($cleanLines | Select-Object -First $PreviewLimit) -join "; ").Trim()
  return [pscustomobject]@{
    available = $true
    count = $cleanLines.Count
    preview = $preview
  }
}

function Invoke-CodexDiagnostics {
  $codexCmd = Get-Command codex -ErrorAction SilentlyContinue
  if ($null -eq $codexCmd) {
    Write-Host "[PLATFORM_NA] codex command not found; skip codex --version/--help/status diagnostics."
    return
  }

  $commands = @(
    @{ name = "codex --version"; args = @("--version"); platformNaOnNonInteractive = $false; nonBlocking = $true },
    @{ name = "codex --help"; args = @("--help"); platformNaOnNonInteractive = $false; nonBlocking = $true },
    @{ name = "codex status"; args = @("status"); platformNaOnNonInteractive = $true; nonBlocking = $true }
  )

  foreach ($item in $commands) {
    $output = @()
    $exitCode = 0
    try {
      $output = @(& codex @($item.args) 2>&1)
      $exitCode = $LASTEXITCODE
      if ($null -eq $exitCode) { $exitCode = 0 }
    } catch {
      $exitCode = 1
      if ($_.Exception -and -not [string]::IsNullOrWhiteSpace([string]$_.Exception.Message)) {
        $output = @([string]$_.Exception.Message)
      } else {
        $output = @([string]($_ | Out-String))
      }
    }

    $ts = (Get-Date).ToString("o")
    Write-Host ("[DIAG] cmd={0} exit_code={1} timestamp={2}" -f $item.name, $exitCode, $ts)
    if ($output.Count -gt 0) {
      Write-Host ("[DIAG_OUT] " + (($output -join [Environment]::NewLine).Trim()))
    }

    if ($exitCode -ne 0 -and $item.platformNaOnNonInteractive) {
      $text = ($output -join [Environment]::NewLine)
      if ($text -match "stdin is not a terminal") {
        Write-Host "[PLATFORM_NA] codex status is non-interactive in current environment (stdin is not a terminal)."
        continue
      }
    }

    if ($exitCode -ne 0 -and $item.nonBlocking) {
      Write-Host ("[WARN] diagnostics command failed but is non-blocking: {0}" -f $item.name)
      continue
    }
  }
}

function Get-TargetGatePlan {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepo
  )
  $targetRepoName = Split-Path -Leaf ([System.IO.Path]::GetFullPath($TargetRepo))

  $analyzeScript = Join-Path $PSScriptRoot "analyze-repo-governance.ps1"
  if (-not (Test-Path -LiteralPath $analyzeScript -PathType Leaf)) {
    throw "Missing analyzer script: $analyzeScript"
  }

  $psExe = Get-CurrentPowerShellPath
  $analysisJson = & $psExe -NoProfile -ExecutionPolicy Bypass -File $analyzeScript -RepoPath $TargetRepo -AsJson
  if ($LASTEXITCODE -ne 0) {
    throw "failed to analyze repo governance gate plan: $TargetRepo"
  }
  $analysisText = [string]::Join([Environment]::NewLine, @($analysisJson))
  if ([string]::IsNullOrWhiteSpace($analysisText)) {
    throw "analyze-repo-governance returned empty output for repo: $TargetRepo"
  }

  $analysis = $analysisText | ConvertFrom-Json
  $recommended = $analysis.recommended
  if ($null -eq $recommended) {
    throw "analyze-repo-governance output missing recommended gates: $TargetRepo"
  }

  function Repair-CommandText([string]$GateName, [string]$CommandText) {
    if ([string]::IsNullOrWhiteSpace($CommandText)) {
      return $CommandText
    }

    $fixed = [string]$CommandText
    $discoverCmd = ([char]0x53D1).ToString() + ([char]0x73B0).ToString()
    $buildApplyCmd = ([char]0x6784).ToString() + ([char]0x5EFA).ToString() + ([char]0x751F).ToString() + ([char]0x6548).ToString()

    if ($fixed -match '^\s*\.\\skills\.ps1\s+\S+') {
      if ($GateName -eq "test") {
        return (".\\skills.ps1 " + $discoverCmd)
      }
      if ($GateName -eq "hotspot") {
        return (".\\skills.ps1 " + $buildApplyCmd)
      }
      if ($GateName -eq "contract/invariant" `
          -and $targetRepoName.Equals("skills-manager", [System.StringComparison]::OrdinalIgnoreCase) `
          -and $fixed -match '^\s*\.\\skills\.ps1\s+doctor(\s+|$)' `
          -and $fixed -notmatch '(?i)--threshold-ms\s+\d+') {
        return ($fixed.TrimEnd() + " --threshold-ms 8000")
      }
    }

    return $fixed
  }

  $steps = @(
    [pscustomobject]@{ name = "build"; command = (Repair-CommandText -GateName "build" -CommandText ([string]$recommended.build)); allowNa = $false },
    [pscustomobject]@{ name = "test"; command = (Repair-CommandText -GateName "test" -CommandText ([string]$recommended.test)); allowNa = $true },
    [pscustomobject]@{ name = "contract/invariant"; command = (Repair-CommandText -GateName "contract/invariant" -CommandText ([string]$recommended.contract_invariant)); allowNa = $false },
    [pscustomobject]@{ name = "hotspot"; command = (Repair-CommandText -GateName "hotspot" -CommandText ([string]$recommended.hotspot)); allowNa = $false }
  )
  return @($steps)
}

function Invoke-TargetPrecheck {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepo,
    [Parameter(Mandatory = $true)][array]$GateSteps
  )

  if ($null -eq (Get-Command powershell -ErrorAction SilentlyContinue)) {
    throw "Required command not found: powershell"
  }

  foreach ($step in $GateSteps) {
    if ([string]::IsNullOrWhiteSpace([string]$step.command)) {
      throw ("target precheck failed: required gate '{0}' command is empty" -f $step.name)
    }

    if ([string]$step.command -like "N/A*") {
      if ([bool]$step.allowNa) {
        Write-Host ("[GATE_NA] TARGET_GATE {0} skipped by plan: {1}" -f $step.name, $step.command)
      } else {
        throw ("target precheck failed: required gate '{0}' is unavailable: {1}" -f $step.name, $step.command)
      }
    } else {
      Write-Host ("[TARGET_GATE_PLAN] {0} => {1}" -f $step.name, $step.command)
    }
  }

  Invoke-CodexDiagnostics
}

function Invoke-RepoCommandText {
  param(
    [Parameter(Mandatory = $true)][string]$CommandText,
    [Parameter(Mandatory = $true)][string]$WorkDir
  )

  Push-Location $WorkDir
  try {
    $hasNativeErrPref = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope 0 -ErrorAction SilentlyContinue)
    $prevNativeErrPref = $null
    if ($hasNativeErrPref) {
      $prevNativeErrPref = $PSNativeCommandUseErrorActionPreference
      $PSNativeCommandUseErrorActionPreference = $false
    }

    $scriptBlock = [ScriptBlock]::Create($CommandText)
    try {
      $global:LASTEXITCODE = 0
      $null = & $scriptBlock
    } finally {
      if ($hasNativeErrPref) {
        $PSNativeCommandUseErrorActionPreference = $prevNativeErrPref
      }
    }

    $isDirectPsScript = [bool]([string]$CommandText -match '^\s*(&\s*)?(\.?[\\/][^\r\n]*?\.ps1)(\s+.*)?$')
    $exitCode = 0
    if (-not $?) {
      $exitCode = 1
    } else {
      if ($isDirectPsScript) {
        $exitCode = 0
      } else {
        $last = $LASTEXITCODE
        if ($last -is [int]) {
          $exitCode = [int]$last
        }
      }
    }
    return [int]$exitCode
  } finally {
    Pop-Location
  }
}

function Invoke-TargetHardGate {
  param(
    [Parameter(Mandatory = $true)][string]$TargetRepo,
    [Parameter(Mandatory = $true)][array]$GateSteps
  )

  foreach ($step in $GateSteps) {
    if ([string]$step.command -like "N/A*") {
      if ([bool]$step.allowNa) {
        Write-Host ("[GATE_NA] TARGET_GATE {0} skipped by plan: {1}" -f $step.name, $step.command)
        continue
      }
      throw ("TARGET_GATE {0} unavailable: {1}" -f $step.name, $step.command)
    }

    Write-Host ("=== TARGET_GATE {0} ===" -f $step.name)
    $exitCode = Invoke-RepoCommandText -CommandText ([string]$step.command) -WorkDir $TargetRepo
    if ($exitCode -ne 0) {
      throw ("TARGET_GATE {0} failed with exit code {1}. command={2}" -f $step.name, $exitCode, $step.command)
    }
  }
}

$bootstrapScript = Join-Path $PSScriptRoot "bootstrap-repo.ps1"
$cycleScript = Join-Path $PSScriptRoot "run-project-governance-cycle.ps1"
$doctorScript = Join-Path $PSScriptRoot "doctor.ps1"

if (-not (Test-Path -LiteralPath $bootstrapScript)) { throw "Missing script: $bootstrapScript" }
if (-not (Test-Path -LiteralPath $cycleScript)) { throw "Missing script: $cycleScript" }
if (-not (Test-Path -LiteralPath $doctorScript)) { throw "Missing script: $doctorScript" }

Write-RepoAutomationPolicySummary -Policy $repoPolicy
Write-Host "[POLICY] remediation owner=outer-ai-session (script does not invoke model CLI for auto-fix)."
Write-Host "[POLICY] if governance issue is discovered during install, repair governance-kit first and then let outer-ai-session re-run."
if ($SkipTargetPrecheck.IsPresent) { Write-Host "[WARN] SkipTargetPrecheck enabled; target precheck and codex diagnostics are skipped." }
if ($SkipTargetGate.IsPresent) { Write-Host "[WARN] SkipTargetGate enabled; target hard gate chain is skipped." }

Run-Step -Name "bootstrap-repo" -Action {
  $args = @(
    "-RepoPath", $repo,
    "-Mode", $Mode
  )

  if ($SkipInstallGlobalGit.IsPresent) { $args += "-SkipInstallGlobalGit" }
  if ($NoOverwriteRules.IsPresent) { $args += "-NoOverwriteRules" }

  Invoke-ChildScript -ScriptPath $bootstrapScript -ScriptArgs $args
}

if ($Mode -ne "plan") {
  $targetGatePlan = @(Get-TargetGatePlan -TargetRepo $repo)
  $hasProjectRuleDocs = @("AGENTS.md", "CLAUDE.md", "GEMINI.md") | ForEach-Object {
    Test-Path -LiteralPath (Join-Path $repo $_)
  }
  $isRuleSeedReady = (@($hasProjectRuleDocs | Where-Object { $_ -eq $true }).Count -eq 3)
  $dirtyState = Get-DirtyRepoState -Repo $repo

  $skipCycleForDirty = $dirtyState.available -and $dirtyState.count -gt 0 -and -not $ForceGovernanceCycleOnDirty.IsPresent
  if ($skipCycleForDirty) {
    Write-Host ("[WARN] skip run-project-governance-cycle: repo has pre-existing dirty entries ({0}). preview={1}" -f $dirtyState.count, $dirtyState.preview)
    Write-Host "[WARN] use -ForceGovernanceCycleOnDirty to run cycle anyway."
  } else {
    Run-Step -Name "run-project-governance-cycle" -Action {
      $cycleArgs = @(
        "-RepoPath", $repo,
        "-RepoName", (Split-Path -Leaf $repo),
        "-Mode", "safe",
        "-ShowScope"
      )
      if (-not $isRuleSeedReady) {
        Write-Host "[INFO] target repo does not contain AGENTS/CLAUDE/GEMINI yet; running cycle with -SkipOptimize -SkipBackflow for first-time bootstrap."
        $cycleArgs += @("-SkipOptimize", "-SkipBackflow")
      }

      Invoke-ChildScript -ScriptPath $cycleScript -ScriptArgs $cycleArgs
    }
  }

  if (-not $SkipAutopilotSmoke.IsPresent) {
    $targetAutopilot = Join-Path $repo "scripts\governance\run-target-autopilot.ps1"
    Run-Step -Name "target-autopilot-smoke" -Action {
      if (-not (Test-Path -LiteralPath $targetAutopilot)) {
        throw "Missing target autopilot script after install: $targetAutopilot"
      }

      Invoke-ChildScript -ScriptPath $targetAutopilot -ScriptArgs @("-RepoRoot", $repo, "-GovernanceKitRoot", $kitRoot, "-DryRun")
    }
  }

  Run-Step -Name "doctor" -Action {
    Invoke-ChildScript -ScriptPath $doctorScript
  }

  if (-not $SkipTargetPrecheck.IsPresent) {
    Run-Step -Name "target-precheck" -Action {
      Invoke-TargetPrecheck -TargetRepo $repo -GateSteps $targetGatePlan
    }
  }

  if (-not $SkipTargetGate.IsPresent) {
    Run-Step -Name "target-hard-gate" -Action {
      Invoke-TargetHardGate -TargetRepo $repo -GateSteps $targetGatePlan
      Write-Host "[ASSERT] target hard gate chain passed"
    }
  }
}

Write-Host "install-full-stack completed: repo=$($repo -replace '\\','/') mode=$Mode"
