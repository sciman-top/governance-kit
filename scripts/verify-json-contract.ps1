param(
  [string]$ExpectedSchemaVersion = "1.0",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

function Read-StepJson([string]$ScriptName) {
  $path = Join-Path $PSScriptRoot $ScriptName
  $out = Invoke-ChildScriptCapture -ScriptPath $path -ScriptArgs @("-AsJson")
  $text = ($out | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($text)) {
    throw "JSON output empty: $ScriptName"
  }
  try {
    return ($text | ConvertFrom-Json)
  } catch {
    throw "JSON parse failed: $ScriptName"
  }
}

function Assert-HasProperties([object]$Obj, [string[]]$Names, [string]$Label) {
  $missing = @()
  foreach ($n in $Names) {
    if (-not $Obj.PSObject.Properties[$n]) {
      $missing += $n
    }
  }
  if ($missing.Count -gt 0) {
    throw "$Label missing fields: $($missing -join ',')"
  }
}

$issues = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()

try {
  $statusObj = Read-StepJson -ScriptName "status.ps1"
  Assert-HasProperties -Obj $statusObj -Names @("schema_version","repositories","targets","repos","global_home_targets","missing_repositories","orphan_targets","codex_runtime","warnings") -Label "status.ps1"
  Assert-HasProperties -Obj $statusObj.codex_runtime -Names @("policy_found","enabled_by_default","policy_repo_entries","enabled_repo_entries","codex_target_mappings","codex_home_target_mappings","codex_repo_target_mappings") -Label "status.ps1.codex_runtime"
  if ([string]$statusObj.schema_version -ne $ExpectedSchemaVersion) {
    throw "status.ps1 schema_version mismatch: actual=$($statusObj.schema_version) expected=$ExpectedSchemaVersion"
  }
  [void]$results.Add([pscustomobject]@{ step = "status.ps1"; status = "PASS" })
} catch {
  [void]$issues.Add($_.Exception.Message)
  [void]$results.Add([pscustomobject]@{ step = "status.ps1"; status = "FAIL"; error = $_.Exception.Message })
}

try {
  $rolloutObj = Read-StepJson -ScriptName "rollout-status.ps1"
  Assert-HasProperties -Obj $rolloutObj -Names @("schema_version","default_phase","default_block_expired_waiver","observe","enforce","observe_overdue","repos","warnings") -Label "rollout-status.ps1"
  if ([string]$rolloutObj.schema_version -ne $ExpectedSchemaVersion) {
    throw "rollout-status.ps1 schema_version mismatch: actual=$($rolloutObj.schema_version) expected=$ExpectedSchemaVersion"
  }
  [void]$results.Add([pscustomobject]@{ step = "rollout-status.ps1"; status = "PASS" })
} catch {
  [void]$issues.Add($_.Exception.Message)
  [void]$results.Add([pscustomobject]@{ step = "rollout-status.ps1"; status = "FAIL"; error = $_.Exception.Message })
}

try {
  $doctorObj = Read-StepJson -ScriptName "doctor.ps1"
  Assert-HasProperties -Obj $doctorObj -Names @("schema_version","generated_at","health","failed_steps","skipped_steps","steps") -Label "doctor.ps1"
  if ([string]$doctorObj.schema_version -ne $ExpectedSchemaVersion) {
    throw "doctor.ps1 schema_version mismatch: actual=$($doctorObj.schema_version) expected=$ExpectedSchemaVersion"
  }
  [void]$results.Add([pscustomobject]@{ step = "doctor.ps1"; status = "PASS" })
} catch {
  [void]$issues.Add($_.Exception.Message)
  [void]$results.Add([pscustomobject]@{ step = "doctor.ps1"; status = "FAIL"; error = $_.Exception.Message })
}

$ok = $issues.Count -eq 0
$summary = [pscustomobject]@{
  schema_version = "1.0"
  expected_schema_version = $ExpectedSchemaVersion
  status = if ($ok) { "PASS" } else { "FAIL" }
  steps = @($results)
  issues = @($issues)
}

if ($AsJson) {
  $summary | ConvertTo-Json -Depth 8 | Write-Output
  if ($ok) { return } else { exit 1 }
}

foreach ($r in $results) {
  if ($r.status -eq "PASS") {
    Write-Host "[PASS] $($r.step)"
  } else {
    Write-Host "[FAIL] $($r.step): $($r.error)"
  }
}

if ($ok) {
  Write-Host "JSON contract verification passed. schema_version=$ExpectedSchemaVersion"
  exit 0
}

Write-Host "JSON contract verification failed. issues=$($issues.Count)"
exit 1
