param(
  [switch]$AsJson,
  [switch]$FailOnDrift
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

function Parse-SemVer {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
  $m = [regex]::Match($Text, "([0-9]+\.[0-9]+\.[0-9]+)")
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function New-CheckResult {
  param(
    [string]$Name,
    [string]$Executable,
    [string]$PackageName
  )

  $platformNa = @()
  $detected = [bool](Get-Command $Executable -ErrorAction SilentlyContinue)

  if (-not $detected) {
    $platformNa += [pscustomobject]@{
      type = "platform_na"
      reason = "$Executable command not found."
      alternative_verification = "Only npm package version was checked."
      evidence_link = "scripts/check-cli-version-drift.ps1 runtime output"
      expires_at = "N/A"
    }
  }

  $localVersion = $null
  $localProbe = $null
  if ($detected) {
    $localProbe = Invoke-CommandCapture -Command "$Executable --version"
    if ($localProbe.exit_code -eq 0) {
      $localVersion = Parse-SemVer -Text $localProbe.output
    }
  }

  $npmProbe = Invoke-CommandCapture -Command "npm view $PackageName version"
  $stableVersion = $null
  if ($npmProbe.exit_code -eq 0) {
    $stableVersion = Parse-SemVer -Text $npmProbe.output
  } else {
    $platformNa += [pscustomobject]@{
      type = "platform_na"
      reason = ("npm view failed for {0}: {1}" -f $PackageName, $npmProbe.output)
      alternative_verification = "Local CLI version only."
      evidence_link = "scripts/check-cli-version-drift.ps1 runtime output"
      expires_at = "N/A"
    }
  }

  $isDrift = $false
  if (-not [string]::IsNullOrWhiteSpace($localVersion) -and -not [string]::IsNullOrWhiteSpace($stableVersion)) {
    $isDrift = ($localVersion -ne $stableVersion)
  }

  return [pscustomobject]@{
    name = $Name
    executable = $Executable
    package = $PackageName
    detected = $detected
    local_version = $localVersion
    stable_version = $stableVersion
    drift = $isDrift
    probes = [pscustomobject]@{
      local = if ($null -ne $localProbe) { $localProbe } else { $null }
      npm = $npmProbe
    }
    platform_na = $platformNa
  }
}

$checks = @(
  (New-CheckResult -Name "codex" -Executable "codex" -PackageName "@openai/codex"),
  (New-CheckResult -Name "claude" -Executable "claude" -PackageName "@anthropic-ai/claude-code"),
  (New-CheckResult -Name "gemini" -Executable "gemini" -PackageName "@google/gemini-cli")
)

$driftItems = @($checks | Where-Object { $_.drift -eq $true })
$platformNa = @($checks | ForEach-Object { @($_.platform_na) })
$status = if ($driftItems.Count -gt 0) { "DRIFT" } elseif ($platformNa.Count -gt 0) { "WARN" } else { "PASS" }

$result = [pscustomobject]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  status = $status
  drift_count = $driftItems.Count
  checks = $checks
  platform_na = $platformNa
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Host "cli version drift report"
  Write-Host "status=$status generated_at=$($result.generated_at)"
  foreach ($item in $checks) {
    $localDisplay = if ([string]::IsNullOrWhiteSpace([string]$item.local_version)) { "N/A" } else { [string]$item.local_version }
    $stableDisplay = if ([string]::IsNullOrWhiteSpace([string]$item.stable_version)) { "N/A" } else { [string]$item.stable_version }
    Write-Host ("- {0}: local={1}; stable={2}; drift={3}" -f $item.name, $localDisplay, $stableDisplay, $item.drift)
  }
  if ($platformNa.Count -gt 0) {
    Write-Host "platform_na:"
    foreach ($na in $platformNa) {
      Write-Host ("- reason={0}; alternative_verification={1}" -f $na.reason, $na.alternative_verification)
    }
  }
}

if ($FailOnDrift -and $driftItems.Count -gt 0) {
  exit 1
}
exit 0
