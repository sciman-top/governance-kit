param(
  [string]$FailureContextJson = "",
  [string]$LogPath = "",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"

function Get-JsonFromLog([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Log path not found: $Path"
  }

  $lines = Get-Content -LiteralPath $Path
  $marker = "[FAILURE_CONTEXT_JSON] "
  $matches = @($lines | Where-Object { ([string]$_).StartsWith($marker, [System.StringComparison]::Ordinal) })
  if ($matches.Count -eq 0) {
    throw "No failure context marker found in log: $Path"
  }

  $last = $matches[$matches.Count - 1]
  return $last.Substring($marker.Length)
}

if ([string]::IsNullOrWhiteSpace($FailureContextJson) -and [string]::IsNullOrWhiteSpace($LogPath)) {
  throw "Provide -FailureContextJson or -LogPath."
}

if (-not [string]::IsNullOrWhiteSpace($FailureContextJson) -and -not [string]::IsNullOrWhiteSpace($LogPath)) {
  throw "Use either -FailureContextJson or -LogPath, not both."
}

$jsonText = if (-not [string]::IsNullOrWhiteSpace($FailureContextJson)) { $FailureContextJson } else { Get-JsonFromLog -Path $LogPath }

try {
  $obj = $jsonText | ConvertFrom-Json
} catch {
  throw "Invalid failure context JSON."
}

$required = @(
  "failed_step",
  "command",
  "exit_code",
  "log_path",
  "repo_path",
  "gate_order",
  "retry_command",
  "policy_snapshot",
  "remediation_owner",
  "remediation_scope",
  "rerun_owner",
  "timestamp"
)

$missing = @()
foreach ($k in $required) {
  if (-not $obj.PSObject.Properties[$k]) {
    $missing += $k
    continue
  }
  $v = $obj.$k
  if ($null -eq $v) {
    $missing += $k
    continue
  }
  if ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) {
    $missing += $k
  }
}

$issues = @()
if ($missing.Count -gt 0) {
  $issues += ("missing_required_fields=" + ($missing -join ","))
}
if ($obj.remediation_owner -ne "outer-ai-session") {
  $issues += "remediation_owner must be outer-ai-session"
}
if ($obj.remediation_scope -ne "governance-kit-first") {
  $issues += "remediation_scope must be governance-kit-first"
}
if ($obj.rerun_owner -ne "outer-ai-session") {
  $issues += "rerun_owner must be outer-ai-session"
}
if ($obj.gate_order -ne "build -> test -> contract/invariant -> hotspot") {
  $issues += "gate_order must match fixed order"
}
if ($obj.exit_code -isnot [int] -and $obj.exit_code -isnot [long]) {
  $issues += "exit_code must be integer"
}

$ok = $issues.Count -eq 0

$result = [pscustomobject]@{
  valid = [bool]$ok
  issues = @($issues)
  required_fields = @($required)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6 | Write-Output
}

if ($ok) {
  Write-Host "Failure context validation passed."
  exit 0
}

foreach ($i in $issues) {
  Write-Host "[CONTRACT] $i"
}
Write-Host "Failure context validation failed."
exit 1
