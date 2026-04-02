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
  function Invoke-ChildScript([string]$ScriptPath, [string[]]$ScriptArgs = @()) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Script failed with exit code ${LASTEXITCODE}: $ScriptPath"
    }
  }
  function Invoke-ChildScriptCapture([string]$ScriptPath, [string[]]$ScriptArgs = @()) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
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

$steps = @(
  [pscustomobject]@{ name = "verify-kit"; script = (Join-Path $PSScriptRoot 'verify-kit.ps1'); args = @() },
  [pscustomobject]@{ name = "validate-config"; script = (Join-Path $PSScriptRoot 'validate-config.ps1'); args = @() },
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

if ($AsJson) {
  $jsonResult = [pscustomobject]@{
    schema_version = "1.0"
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    health = $health
    failed_steps = @($failedSteps)
    skipped_steps = @($skippedSteps)
    steps = @($stepResults)
  }
  $jsonResult | ConvertTo-Json -Depth 8 | Write-Output
  if ($ok) { return } else { exit 1 }
}

Write-Host "=== SUMMARY ==="
if ($ok) {
  Write-Host "HEALTH=GREEN"
  exit 0
}

Write-Host ("failed_steps=" + ($failedSteps -join ","))
Write-Host "HEALTH=RED"
exit 1
