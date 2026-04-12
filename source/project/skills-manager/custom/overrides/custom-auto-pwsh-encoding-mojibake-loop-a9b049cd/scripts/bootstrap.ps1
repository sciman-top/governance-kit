param(
  [switch]$CheckOnly,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$overrideRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$guardScript = Join-Path $overrideRoot "custom-windows-encoding-guard\scripts\bootstrap.ps1"

if (-not (Test-Path -LiteralPath $guardScript -PathType Leaf)) {
  throw "canonical guard bootstrap not found: $guardScript"
}

$guardArgs = @{ AsJson = $true }
if ($CheckOnly) { $guardArgs.CheckOnly = $true }
$guardJson = & $guardScript @guardArgs
if ($LASTEXITCODE -ne 0) {
  throw "canonical guard bootstrap failed with exit code $LASTEXITCODE"
}
$guard = $guardJson | ConvertFrom-Json

$wrapperChanged = $false
$wrapperInstalled = $false
$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue

if (-not $CheckOnly -and $null -ne $pwshCommand) {
  $current = Get-Command powershell -ErrorAction SilentlyContinue
  $needsWrap = $true
  if ($null -ne $current -and $current.CommandType -eq 'Function') {
    $def = [string]$current.Definition
    if ($def -match '&\s+pwsh\b') { $needsWrap = $false }
  }
  if ($needsWrap) {
    $fnBody = "param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Args)`n& pwsh @Args"
    Set-Item -Path Function:\global:powershell -Value $fnBody -Force
    $wrapperChanged = $true
  }
}

$afterPowerShell = Get-Command powershell -ErrorAction SilentlyContinue
if ($null -ne $afterPowerShell -and $afterPowerShell.CommandType -eq 'Function' -and ([string]$afterPowerShell.Definition -match '&\s+pwsh\b')) {
  $wrapperInstalled = $true
}

$result = [ordered]@{
  check_only = [bool]$CheckOnly
  canonical_guard_skill = 'custom-windows-encoding-guard'
  canonical_guard_script = ($guardScript -replace '\\','/')
  canonical_guard_ok = [bool]$guard.compliant_after
  powershell_wrapper_installed = [bool]$wrapperInstalled
  powershell_wrapper_changed = [bool]$wrapperChanged
  pwsh_found = ($null -ne $pwshCommand)
  guard_result = $guard
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
} else {
  if ($result.canonical_guard_ok -and $result.powershell_wrapper_installed) {
    Write-Host "[PASS] UTF-8 + powershell wrapper guard is compliant."
  } else {
    Write-Host "[WARN] UTF-8 + powershell wrapper guard is not fully compliant."
  }
}

if ($result.canonical_guard_ok -and ($result.powershell_wrapper_installed -or -not $result.pwsh_found)) {
  exit 0
}
exit 2
