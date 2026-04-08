param(
  [switch]$SkipVerifyTargets,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (Test-Path -LiteralPath $commonPath) {
  . $commonPath
} else {
  $localPsExe = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
  if ([string]::IsNullOrWhiteSpace($localPsExe)) {
    $localPsExe = "powershell"
  }
  function Invoke-ChildScript([string]$ScriptPath, [string[]]$ScriptArgs = @()) {
    & $localPsExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Script failed with exit code ${LASTEXITCODE}: $ScriptPath"
    }
  }
  function Invoke-ChildScriptCapture([string]$ScriptPath, [string[]]$ScriptArgs = @()) {
    $out = & $localPsExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Script failed with exit code ${LASTEXITCODE}: $ScriptPath"
    }
    return $out
  }
}

function Run-Step([string]$Name, [string]$ScriptPath, [string[]]$ScriptArgs = @(), [switch]$CaptureOutput) {
  if (-not $CaptureOutput) {
    Write-Host "=== $Name ==="
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $pass = $false
  $errorText = $null
  $outputText = $null
  try {
    if ($CaptureOutput) {
      $captured = Invoke-ChildScriptCapture -ScriptPath $ScriptPath -ScriptArgs $ScriptArgs
      $outputText = ($captured | Out-String).TrimEnd()
    } else {
      Invoke-ChildScript -ScriptPath $ScriptPath -ScriptArgs $ScriptArgs
    }
    $pass = $true
    if (-not $CaptureOutput) {
      Write-Host "[PASS] $Name"
    }
  } catch {
    $errorText = $_.Exception.Message
    if (-not $CaptureOutput) {
      Write-Host "[FAIL] $Name"
      Write-Host $_
    }
  } finally {
    $sw.Stop()
  }

  return [pscustomobject]@{
    step = $Name
    status = if ($pass) { "PASS" } else { "FAIL" }
    duration_ms = [int][math]::Round($sw.Elapsed.TotalMilliseconds)
    error = $errorText
    output = $outputText
  }
}

function Get-ClarificationObservability([string]$KitRootPath) {
  $reposPath = Join-Path $KitRootPath "config\repositories.json"
  if (-not (Test-Path -LiteralPath $reposPath)) {
    return [pscustomobject]@{
      trigger_count = 0
      open_items = 0
      tracked_repos = 0
      tracked_files = 0
      issues = @()
    }
  }

  try {
    $repos = Get-Content -LiteralPath $reposPath -Raw | ConvertFrom-Json
  } catch {
    return [pscustomobject]@{
      trigger_count = 0
      open_items = 0
      tracked_repos = 0
      tracked_files = 0
      issues = @("[doctor] repositories.json parse failed")
    }
  }

  $triggerCount = 0
  $openItems = 0
  $trackedFiles = 0
  $trackedRepos = 0
  $issues = [System.Collections.Generic.List[string]]::new()

  foreach ($repo in @($repos)) {
    $repoPathText = [string]$repo
    if ([string]::IsNullOrWhiteSpace($repoPathText)) {
      continue
    }
    $repoPath = ($repoPathText -replace '/', '\')
    if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) {
      continue
    }
    $trackedRepos++
    $clarificationDir = Join-Path $repoPath ".codex\clarification"
    if (-not (Test-Path -LiteralPath $clarificationDir -PathType Container)) {
      continue
    }

    $files = @(Get-ChildItem -LiteralPath $clarificationDir -Filter "*.json" -File -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
      $trackedFiles++
      try {
        $state = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
      } catch {
        $issues.Add("invalid clarification state: $($file.FullName)") | Out-Null
        continue
      }

      if ($state.clarification_required -eq $true) {
        $openItems++
      }
      if ([int]$state.attempt_count -ge 2) {
        $triggerCount++
      }
    }
  }

  return [pscustomobject]@{
    trigger_count = $triggerCount
    open_items = $openItems
    tracked_repos = $trackedRepos
    tracked_files = $trackedFiles
    issues = @($issues)
  }
}

$steps = @(
  [pscustomobject]@{ name = "verify-kit"; script = (Join-Path $PSScriptRoot 'verify-kit.ps1'); args = @() },
  [pscustomobject]@{ name = "validate-config"; script = (Join-Path $PSScriptRoot 'validate-config.ps1'); args = @() },
  [pscustomobject]@{ name = "release-profile-coverage"; script = (Join-Path $PSScriptRoot 'check-release-profile-coverage.ps1'); args = @() },
  [pscustomobject]@{ name = "verify-targets"; script = (Join-Path $PSScriptRoot 'verify.ps1'); args = @('-SkipConfigValidation') },
  [pscustomobject]@{ name = "waiver-check"; script = (Join-Path $PSScriptRoot 'check-waivers.ps1'); args = @() },
  [pscustomobject]@{ name = "status"; script = (Join-Path $PSScriptRoot 'status.ps1'); args = @() },
  [pscustomobject]@{ name = "rollout-status"; script = (Join-Path $PSScriptRoot 'rollout-status.ps1'); args = @() }
)

$skippedSteps = [System.Collections.Generic.List[string]]::new()
if ($SkipVerifyTargets) {
  $steps = @($steps | Where-Object { $_.name -ne "verify-targets" })
  [void]$skippedSteps.Add("verify-targets")
  if (-not $AsJson) {
    Write-Host "[SKIP] verify-targets (SkipVerifyTargets=true)"
  }
}

$stepResults = [System.Collections.Generic.List[object]]::new()
$failedSteps = [System.Collections.Generic.List[string]]::new()

foreach ($item in $steps) {
  $result = Run-Step -Name $item.name -ScriptPath $item.script -ScriptArgs $item.args -CaptureOutput:$AsJson
  [void]$stepResults.Add($result)
  if ($result.status -ne "PASS") {
    [void]$failedSteps.Add($item.name)
  }
}

$ok = $failedSteps.Count -eq 0
$health = if ($ok) { "GREEN" } else { "RED" }
$clarification = Get-ClarificationObservability -KitRootPath $kitRoot

if ($AsJson) {
  $jsonResult = [pscustomobject]@{
    schema_version = "1.0"
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    health = $health
    failed_steps = @($failedSteps)
    skipped_steps = @($skippedSteps)
    clarification = $clarification
    steps = @($stepResults)
  }
  $jsonResult | ConvertTo-Json -Depth 8 | Write-Output
  if ($ok) { return } else { exit 1 }
}

Write-Host "=== SUMMARY ==="
Write-Host ("clarification_trigger_count=" + $clarification.trigger_count)
Write-Host ("clarification_open_items=" + $clarification.open_items)
Write-Host ("clarification_tracked_repos=" + $clarification.tracked_repos)
Write-Host ("clarification_tracked_files=" + $clarification.tracked_files)
if ($ok) {
  Write-Host "HEALTH=GREEN"
  exit 0
}

Write-Host ("failed_steps=" + ($failedSteps -join ","))
Write-Host "HEALTH=RED"
exit 1
