param(
  [string]$OutPath = "",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $OutPath = Join-Path $kitRoot "docs\governance-readiness.md"
}

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,
    [string[]]$Args = @()
  )

  $name = Split-Path -Leaf $ScriptPath
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $psExe = Get-CurrentPowerShellPath
  & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Args | Out-Null
  $exitCode = $LASTEXITCODE
  $sw.Stop()
  return [pscustomobject]@{
    step = $name
    exit_code = $exitCode
    duration_ms = [int][math]::Round($sw.Elapsed.TotalMilliseconds)
    status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
  }
}

function Invoke-JsonStep {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,
    [string[]]$Args = @()
  )

  $out = Invoke-ChildScriptCapture -ScriptPath $ScriptPath -ScriptArgs $Args

  $text = ($out | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($text)) { return $null }
  try {
    return ($text | ConvertFrom-Json)
  } catch {
    return $null
  }
}

$targetsPath = Join-Path $kitRoot "config\targets.json"
$reposPath = Join-Path $kitRoot "config\repositories.json"
$customPath = Join-Path $kitRoot "config\project-custom-files.json"
$baselinePath = Join-Path $kitRoot "config\governance-baseline.json"

$targets = Read-JsonArray $targetsPath
$repos = Read-JsonArray $reposPath
$customCfg = if (Test-Path -LiteralPath $customPath) { Get-Content -LiteralPath $customPath -Raw | ConvertFrom-Json } else { $null }
$baselineCfg = if (Test-Path -LiteralPath $baselinePath) { Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json } else { $null }

$globalHomeCount = @($targets | Where-Object { ([string]$_.source).StartsWith("source/global/", [System.StringComparison]::OrdinalIgnoreCase) }).Count
$projectRuleCount = @($targets | Where-Object { ([string]$_.source) -match '^source/project/[^/]+/(AGENTS|CLAUDE|GEMINI)\.md$' }).Count
$projectCustomCount = @($targets | Where-Object { ([string]$_.source) -like 'source/project/*/custom/*' }).Count
$customPolicyCount = if ($null -ne $customCfg -and $null -ne $customCfg.repos) { @($customCfg.repos).Count } else { 0 }

$steps = @()
$steps += Invoke-Step -ScriptPath (Join-Path $PSScriptRoot "verify-kit.ps1")
$steps += Invoke-Step -ScriptPath (Join-Path $PSScriptRoot "validate-config.ps1")
$steps += Invoke-Step -ScriptPath (Join-Path $PSScriptRoot "verify.ps1") -Args @("-SkipConfigValidation")
$steps += Invoke-Step -ScriptPath (Join-Path $PSScriptRoot "check-orphan-custom-sources.ps1")
$orphanObj = Invoke-JsonStep -ScriptPath (Join-Path $PSScriptRoot "check-orphan-custom-sources.ps1") -Args @("-AsJson")
$orphanCount = if ($null -ne $orphanObj -and $null -ne $orphanObj.orphan_count) { [int]$orphanObj.orphan_count } else { 0 }

$failed = @($steps | Where-Object { $_.status -eq "FAIL" })
$overall = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
$warnings = @()
if ($orphanCount -gt 0) {
  $warnings += "orphan custom sources detected: $orphanCount"
}
if ($null -eq $orphanObj) {
  $warnings += "orphan custom source JSON parse fallback applied"
}

$result = [pscustomobject]@{
  generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  overall = $overall
  baseline = [pscustomobject]@{
    version = if ($baselineCfg) { [string]$baselineCfg.version } else { "" }
    frozen_at = if ($baselineCfg) { [string]$baselineCfg.frozen_at } else { "" }
  }
  stats = [pscustomobject]@{
    repositories = $repos.Count
    targets_total = $targets.Count
    targets_global_home = $globalHomeCount
    targets_project_rules = $projectRuleCount
    targets_project_custom = $projectCustomCount
    custom_policy_repo_entries = $customPolicyCount
    orphan_custom_sources = $orphanCount
  }
  steps = @($steps)
  warnings = @($warnings)
}

$outDir = Split-Path -Parent $OutPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and !(Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines = @()
$lines += "# Governance Readiness Report"
$lines += ""
$lines += "- generated_at: $($result.generated_at)"
$lines += "- overall: $($result.overall)"
$lines += "- baseline.version: $($result.baseline.version)"
$lines += "- baseline.frozen_at: $($result.baseline.frozen_at)"
$lines += ""
$lines += "## Stats"
$lines += ""
$lines += "- repositories: $($result.stats.repositories)"
$lines += "- targets_total: $($result.stats.targets_total)"
$lines += "- targets_global_home: $($result.stats.targets_global_home)"
$lines += "- targets_project_rules: $($result.stats.targets_project_rules)"
$lines += "- targets_project_custom: $($result.stats.targets_project_custom)"
$lines += "- custom_policy_repo_entries: $($result.stats.custom_policy_repo_entries)"
$lines += "- orphan_custom_sources: $($result.stats.orphan_custom_sources)"
$lines += ""
$lines += "## Warnings"
$lines += ""
if (@($result.warnings).Count -eq 0) {
  $lines += "- none"
} else {
  foreach ($w in $result.warnings) {
    if (-not [string]::IsNullOrWhiteSpace([string]$w)) { $lines += "- $w" }
  }
}
$lines += ""
$lines += "## Steps"
$lines += ""
foreach ($s in $result.steps) {
  $lines += "- $($s.step): $($s.status) (exit=$($s.exit_code), $($s.duration_ms)ms)"
}

Set-Content -Path $OutPath -Value ($lines -join "`r`n") -Encoding UTF8
Write-Host "audit-governance-readiness done. overall=$overall report=$OutPath"

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6 | Write-Output
}

if ($overall -ne "PASS") { exit 1 }
