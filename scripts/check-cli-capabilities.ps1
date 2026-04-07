param(
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Invoke-CommandCapture {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,
    [int]$HeadLines = 20
  )

  $output = $null
  $exitCode = 0
  try {
    $output = Invoke-Expression $Command 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
  } catch {
    $output = $_.Exception.Message
    $exitCode = 1
  }

  $lines = @()
  if (-not [string]::IsNullOrWhiteSpace($output)) {
    $lines = @($output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First $HeadLines)
  }

  [pscustomobject]@{
    cmd = $Command
    exit_code = [int]$exitCode
    key_output = ($lines -join " | ")
    raw_output = [string]$output
    timestamp = (Get-Date).ToString("o")
  }
}

function New-PlatformNa {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Reason,
    [Parameter(Mandatory = $true)]
    [string]$AlternativeVerification
  )

  [pscustomobject]@{
    type = "platform_na"
    reason = $Reason
    alternative_verification = $AlternativeVerification
    evidence_link = "scripts/check-cli-capabilities.ps1 runtime output"
    expires_at = "N/A"
  }
}

function Test-TextMatch {
  param(
    [string]$Text,
    [string]$Pattern
  )

  if ([string]::IsNullOrEmpty($Text)) { return $false }
  return [bool]([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}

function Get-CliReport {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$Executable,
    [Parameter(Mandatory = $true)]
    [string[]]$CapabilityPatterns
  )

  $platformNa = @()
  $probes = @()
  $capabilities = @()
  $detected = [bool](Get-Command $Executable -ErrorAction SilentlyContinue)

  if (-not $detected) {
    $platformNa += New-PlatformNa -Reason "$Executable command not found." -AlternativeVerification "Skipped capability probes for $Name."
    return [pscustomobject]@{
      name = $Name
      executable = $Executable
      detected = $false
      version = $null
      probes = @()
      capabilities = @()
      platform_na = $platformNa
    }
  }

  $versionProbe = Invoke-CommandCapture -Command "$Executable --version"
  $helpProbe = Invoke-CommandCapture -Command "$Executable --help"
  $probes += @($versionProbe, $helpProbe)

  $version = $null
  if ($versionProbe.exit_code -eq 0) {
    $m = [regex]::Match($versionProbe.key_output, "([0-9]+\.[0-9]+(?:\.[0-9]+)?)")
    if ($m.Success) { $version = $m.Groups[1].Value }
  }

  $helpText = [string]$helpProbe.raw_output
  foreach ($cp in $CapabilityPatterns) {
    $parts = $cp -split "=", 2
    $cap = $parts[0]
    $pattern = $parts[1]
    $supported = $false
    if ($helpProbe.exit_code -eq 0) {
      $supported = Test-TextMatch -Text $helpText -Pattern $pattern
    }
    $capabilities += [pscustomobject]@{
      capability = $cap
      supported = [bool]$supported
      probe = "$Executable --help"
    }
  }

  if ($Name -eq "codex") {
    $statusProbe = Invoke-CommandCapture -Command "codex status"
    $probes += $statusProbe
    if ($statusProbe.exit_code -ne 0) {
      $reason = "codex status failed: $($statusProbe.key_output)"
      $alt = "Used codex --version and codex --help to verify CLI presence and capability surface."
      $platformNa += New-PlatformNa -Reason $reason -AlternativeVerification $alt
    }
  }

  [pscustomobject]@{
    name = $Name
    executable = $Executable
    detected = $true
    version = $version
    probes = $probes
    capabilities = $capabilities
    platform_na = $platformNa
  }
}

$reports = @(
  (Get-CliReport -Name "codex" -Executable "codex" -CapabilityPatterns @(
      "exec=\bexec\b",
      "review=\breview\b",
      "mcp=\bmcp\b",
      "sandbox=\bsandbox\b",
      "cloud=\bcloud\b",
      "app_server=\bapp-server\b",
      "features=\bfeatures\b",
      "web_search=--search"
    )),
  (Get-CliReport -Name "claude" -Executable "claude" -CapabilityPatterns @(
      "doctor=\bdoctor\b",
      "mcp=\bmcp\b",
      "plugins=\bplugin\b|\bplugins\b",
      "agents=\bagents\b",
      "permission_mode=--permission-mode",
      "worktree=--worktree",
      "headless_print=-p,\s*--print"
    )),
  (Get-CliReport -Name "gemini" -Executable "gemini" -CapabilityPatterns @(
      "mcp=\bmcp\b",
      "extensions=\bextensions\b",
      "skills=\bskills\b",
      "hooks=\bhooks\b",
      "approval_mode=--approval-mode",
      "sandbox=--sandbox",
      "policy=--policy",
      "admin_policy=--admin-policy",
      "headless_prompt=-p,\s*--prompt"
    ))
)

$allPlatformNa = @($reports | ForEach-Object { @($_.platform_na) })
$status = if ($allPlatformNa.Count -gt 0) { "WARN" } else { "PASS" }

$result = [pscustomobject]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  status = $status
  tools = $reports
  platform_na = $allPlatformNa
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8
  exit 0
}

Write-Host "cli capability report"
Write-Host "status=$status generated_at=$($result.generated_at)"
foreach ($tool in $reports) {
  $versionDisplay = if ([string]::IsNullOrWhiteSpace([string]$tool.version)) { "N/A" } else { [string]$tool.version }
  Write-Host ("- {0}: detected={1} version={2}" -f $tool.name, $tool.detected, $versionDisplay)
  foreach ($cap in $tool.capabilities) {
    Write-Host ("  capability.{0}={1}" -f $cap.capability, ($(if ($cap.supported) { "supported" } else { "not_detected" })))
  }
}
if ($allPlatformNa.Count -gt 0) {
  Write-Host "platform_na:"
  foreach ($na in $allPlatformNa) {
    Write-Host ("- reason={0}; alternative_verification={1}" -f $na.reason, $na.alternative_verification)
  }
}

exit 0
