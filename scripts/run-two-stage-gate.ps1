param(
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
$psExe = Get-CurrentPowerShellPath

function Parse-JsonFromText([string]$RawText) {
  if ([string]::IsNullOrWhiteSpace($RawText)) { return $null }
  try {
    return ($RawText | ConvertFrom-Json)
  } catch {
    $start = $RawText.IndexOf("{")
    $end = $RawText.LastIndexOf("}")
    if ($start -ge 0 -and $end -ge $start) {
      try {
        return ($RawText.Substring($start, $end - $start + 1) | ConvertFrom-Json)
      } catch {
        return $null
      }
    }
  }
  return $null
}

function Run-DoctorStage([string]$StageName, [string[]]$StageArgs) {
  $doctorScript = Join-Path $PSScriptRoot "doctor.ps1"
  if (-not (Test-Path -LiteralPath $doctorScript -PathType Leaf)) {
    throw "Missing doctor script: $doctorScript"
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $raw = ""
  $parsed = $null
  $exitCode = 1
  $status = "FAIL"
  $errorText = $null
  try {
    $captured = & $psExe -NoProfile -ExecutionPolicy Bypass -File $doctorScript @StageArgs 2>&1
    $raw = ($captured | Out-String).TrimEnd()
    $exitCode = [int]$LASTEXITCODE
    $parsed = Parse-JsonFromText -RawText $raw
    if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties["health"] -and -not [string]::IsNullOrWhiteSpace([string]$parsed.health)) {
      $status = if ([string]$parsed.health -eq "GREEN") { "PASS" } else { "FAIL" }
      if ($status -eq "PASS") { $exitCode = 0 }
    } else {
      $status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
    }
  } catch {
    $errorText = $_.Exception.Message
    $status = "FAIL"
    $exitCode = 1
  } finally {
    $sw.Stop()
  }

  return [pscustomobject]@{
    stage = $StageName
    status = $status
    exit_code = $exitCode
    elapsed_ms = [int]$sw.ElapsedMilliseconds
    health = if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties["health"]) { [string]$parsed.health } else { "UNKNOWN" }
    failed_steps = if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties["failed_steps"]) { @($parsed.failed_steps) } else { @() }
    slow_steps_top3 = if ($null -ne $parsed -and $null -ne $parsed.PSObject.Properties["slow_steps_top3"]) { @($parsed.slow_steps_top3) } else { @() }
    error = $errorText
    raw = $raw
  }
}

$overallSw = [System.Diagnostics.Stopwatch]::StartNew()
$fastStage = Run-DoctorStage -StageName "fast_precheck" -StageArgs @("-SkipVerifyTargets", "-AsJson")
$fullStage = Run-DoctorStage -StageName "full_gate" -StageArgs @("-AsJson")
$overallSw.Stop()

$ok = ($fastStage.exit_code -eq 0 -and $fullStage.exit_code -eq 0)
$summary = [pscustomobject]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  ok = $ok
  elapsed_ms = [int]$overallSw.ElapsedMilliseconds
  fast_precheck = $fastStage
  full_gate = $fullStage
}

if ($AsJson) {
  $summary | ConvertTo-Json -Depth 8 | Write-Output
} else {
  Write-Host "=== TWO_STAGE_GATE ==="
  Write-Host ("fast_precheck.status={0} elapsed_ms={1}" -f $fastStage.status, $fastStage.elapsed_ms)
  Write-Host ("full_gate.status={0} elapsed_ms={1}" -f $fullStage.status, $fullStage.elapsed_ms)
  Write-Host ("overall.elapsed_ms={0}" -f [int]$overallSw.ElapsedMilliseconds)
  if (@($fullStage.slow_steps_top3).Count -gt 0) {
    $slowSummary = @($fullStage.slow_steps_top3 | ForEach-Object { "{0}:{1}" -f $_.step, $_.duration_ms }) -join ","
    Write-Host ("full_gate.slow_steps_top3=" + $slowSummary)
  }
  if (-not $ok) {
    $failed = @()
    if ($fastStage.exit_code -ne 0) { $failed += "fast_precheck" }
    if ($fullStage.exit_code -ne 0) { $failed += "full_gate" }
    Write-Host ("failed_stages=" + ($failed -join ","))
  }
}

if ($ok) { exit 0 }
exit 1
