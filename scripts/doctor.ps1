param(
  [switch]$SkipVerifyTargets
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
}

function Run-Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  try {
    & $Action | Out-Host
    Write-Host "[PASS] $Name"
    return $true
  } catch {
    Write-Host "[FAIL] $Name"
    Write-Host $_
    return $false
  }
}

$ok = $true
$failedSteps = @()

$steps = @(
  @{ name = "verify-kit"; action = { Invoke-ChildScript (Join-Path $PSScriptRoot 'verify-kit.ps1') } },
  @{ name = "validate-config"; action = { Invoke-ChildScript (Join-Path $PSScriptRoot 'validate-config.ps1') } },
  @{ name = "waiver-check"; action = { Invoke-ChildScript (Join-Path $PSScriptRoot 'check-waivers.ps1') } },
  @{ name = "status"; action = { Invoke-ChildScript (Join-Path $PSScriptRoot 'status.ps1') } },
  @{ name = "rollout-status"; action = { Invoke-ChildScript (Join-Path $PSScriptRoot 'rollout-status.ps1') } }
)

if (-not $SkipVerifyTargets) {
  $steps = @(
    $steps[0],
    $steps[1],
    @{ name = "verify-targets"; action = { Invoke-ChildScript (Join-Path $PSScriptRoot 'verify.ps1') @('-SkipConfigValidation') } },
    $steps[2],
    $steps[3],
    $steps[4]
  )
} else {
  Write-Host "[SKIP] verify-targets (SkipVerifyTargets=true)"
}

foreach ($item in $steps) {
  $step = Run-Step $item.name $item.action
  $ok = [bool]$ok -and [bool]$step
  if (-not $step) {
    $failedSteps += $item.name
  }
}

Write-Host "=== SUMMARY ==="
if ($ok) {
  Write-Host "HEALTH=GREEN"
  exit 0
} else {
  Write-Host ("failed_steps=" + ($failedSteps -join ","))
  Write-Host "HEALTH=RED"
  exit 1
}
