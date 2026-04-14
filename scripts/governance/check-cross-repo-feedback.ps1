param(
  [string]$RepoRoot = ".",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-JsonLoose {
  param([string]$RawText)
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

function Invoke-StepText([string]$ScriptPath, [string[]]$Args) {
  $captured = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Args 2>&1
  $exitCode = $LASTEXITCODE
  return [pscustomobject]@{
    exit_code = [int]$exitCode
    output = ($captured | Out-String)
  }
}

$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$compatibilityScript = Join-Path $repoPath "scripts\governance\check-cross-repo-compatibility.ps1"
$rolloutMatrixScript = Join-Path $repoPath "scripts\governance\check-target-rollout-matrix.ps1"
$repositoriesPath = Join-Path $repoPath "config\repositories.json"
$compatibilitySignalPath = Join-Path $repoPath ".governance\cross-repo-compatibility-signal.json"
$feedbackSignalPath = Join-Path $repoPath ".governance\cross-repo-feedback-signal.json"
$feedbackReportPath = Join-Path $repoPath "docs\governance\cross-repo-feedback-report-latest.md"

if (-not (Test-Path -LiteralPath $compatibilityScript -PathType Leaf)) {
  throw "Missing compatibility script: $compatibilityScript"
}
if (-not (Test-Path -LiteralPath $rolloutMatrixScript -PathType Leaf)) {
  throw "Missing target rollout matrix script: $rolloutMatrixScript"
}

$compatibilityRaw = Invoke-StepText -ScriptPath $compatibilityScript -Args @("-RepoRoot", $repoPath, "-AsJson")
$compatibilityObj = Parse-JsonLoose -RawText ([string]$compatibilityRaw.output)

$matrixRaw = Invoke-StepText -ScriptPath $rolloutMatrixScript -Args @("-RepoRoot", $repoPath, "-AsJson")
$matrixObj = Parse-JsonLoose -RawText ([string]$matrixRaw.output)

$compatibilityStatus = "unknown"
$repoCount = 0
$repoFailureCount = 0
$missingRequiredFileCount = 0
$problematicRepos = [System.Collections.Generic.List[string]]::new()

if ($null -ne $compatibilityObj) {
  if ($compatibilityObj.PSObject.Properties.Name -contains "status") {
    $compatibilityStatus = [string]$compatibilityObj.status
  }
  if ($compatibilityObj.PSObject.Properties.Name -contains "repo_count") {
    try { $repoCount = [int]$compatibilityObj.repo_count } catch { $repoCount = 0 }
  }
  if ($compatibilityObj.PSObject.Properties.Name -contains "repo_failure_count") {
    try { $repoFailureCount = [int]$compatibilityObj.repo_failure_count } catch { $repoFailureCount = 0 }
  }
  if ($compatibilityObj.PSObject.Properties.Name -contains "missing_required_file_count") {
    try { $missingRequiredFileCount = [int]$compatibilityObj.missing_required_file_count } catch { $missingRequiredFileCount = 0 }
  }
  if ($compatibilityObj.PSObject.Properties.Name -contains "repos") {
    foreach ($item in @($compatibilityObj.repos)) {
      $itemStatus = ""
      $itemRepo = ""
      if ($null -ne $item.PSObject.Properties['status']) { $itemStatus = [string]$item.status }
      if ($null -ne $item.PSObject.Properties['repo']) { $itemRepo = [string]$item.repo }
      if (-not [string]::IsNullOrWhiteSpace($itemRepo) -and -not [string]::Equals($itemStatus, "ok", [System.StringComparison]::OrdinalIgnoreCase)) {
        [void]$problematicRepos.Add($itemRepo)
      }
    }
  }
}
if ($null -eq $compatibilityObj -and (Test-Path -LiteralPath $compatibilitySignalPath -PathType Leaf)) {
  try {
    $compatibilitySignalObj = Get-Content -LiteralPath $compatibilitySignalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $compatibilitySignalObj) {
      if ($compatibilitySignalObj.PSObject.Properties.Name -contains "status") {
        $compatibilityStatus = [string]$compatibilitySignalObj.status
      }
      if ($compatibilitySignalObj.PSObject.Properties.Name -contains "repo_count") {
        try { $repoCount = [int]$compatibilitySignalObj.repo_count } catch { $repoCount = 0 }
      }
      if ($compatibilitySignalObj.PSObject.Properties.Name -contains "repo_failure_count") {
        try { $repoFailureCount = [int]$compatibilitySignalObj.repo_failure_count } catch { $repoFailureCount = 0 }
      }
      if ($compatibilitySignalObj.PSObject.Properties.Name -contains "missing_required_file_count") {
        try { $missingRequiredFileCount = [int]$compatibilitySignalObj.missing_required_file_count } catch { $missingRequiredFileCount = 0 }
      }
    }
  } catch {
  }
}
if ($repoCount -le 0 -and (Test-Path -LiteralPath $repositoriesPath -PathType Leaf)) {
  try {
    $repoList = @(Get-Content -LiteralPath $repositoriesPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $repoCount = @($repoList | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
  } catch {
  }
}
if ($problematicRepos.Count -eq 0 -and $repoFailureCount -gt 0) {
  [void]$problematicRepos.Add("unknown:parse_from_compatibility_output_failed")
}

$rolloutMatrixMissingControlCount = 0
$rolloutMatrixMissingRepoStateCount = 0
if ($null -ne $matrixObj) {
  if ($matrixObj.PSObject.Properties.Name -contains "missing_control_count") {
    try { $rolloutMatrixMissingControlCount = [int]$matrixObj.missing_control_count } catch { $rolloutMatrixMissingControlCount = 0 }
  }
  if ($matrixObj.PSObject.Properties.Name -contains "missing_repo_state_count") {
    try { $rolloutMatrixMissingRepoStateCount = [int]$matrixObj.missing_repo_state_count } catch { $rolloutMatrixMissingRepoStateCount = 0 }
  }
}

$status = "ok"
if (
  $compatibilityRaw.exit_code -ne 0 -or
  $matrixRaw.exit_code -ne 0 -or
  $compatibilityStatus -ne "ok" -or
  $repoFailureCount -gt 0 -or
  $missingRequiredFileCount -gt 0 -or
  $rolloutMatrixMissingControlCount -gt 0 -or
  $rolloutMatrixMissingRepoStateCount -gt 0
) {
  $status = "alert"
}

$feedbackIngestedCount = [int]$repoCount
$compatibleRepoCount = [Math]::Max(0, [int]$repoCount - [int]$repoFailureCount)

$reportLines = [System.Collections.Generic.List[string]]::new()
[void]$reportLines.Add("# Cross Repo Feedback Report (Latest)")
[void]$reportLines.Add("")
[void]$reportLines.Add(("generated_at={0}" -f (Get-Date).ToString("o")))
[void]$reportLines.Add(("status={0}" -f $status))
[void]$reportLines.Add(("compatibility_status={0}" -f $compatibilityStatus))
[void]$reportLines.Add(("feedback_ingested_count={0}" -f [int]$feedbackIngestedCount))
[void]$reportLines.Add(("compatible_repo_count={0}" -f [int]$compatibleRepoCount))
[void]$reportLines.Add(("repo_failure_count={0}" -f [int]$repoFailureCount))
[void]$reportLines.Add(("missing_required_file_count={0}" -f [int]$missingRequiredFileCount))
[void]$reportLines.Add(("rollout_matrix_missing_control_count={0}" -f [int]$rolloutMatrixMissingControlCount))
[void]$reportLines.Add(("rollout_matrix_missing_repo_state_count={0}" -f [int]$rolloutMatrixMissingRepoStateCount))
if ($problematicRepos.Count -gt 0) {
  [void]$reportLines.Add("problematic_repos=")
  foreach ($repo in @($problematicRepos | Select-Object -First 10)) {
    [void]$reportLines.Add(("- " + [string]$repo))
  }
} else {
  [void]$reportLines.Add("problematic_repos=none")
}

$reportParent = Split-Path -Parent $feedbackReportPath
if (-not (Test-Path -LiteralPath $reportParent -PathType Container)) {
  New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
}
Set-Content -LiteralPath $feedbackReportPath -Value ($reportLines -join "`r`n") -Encoding UTF8

$signalParent = Split-Path -Parent $feedbackSignalPath
if (-not (Test-Path -LiteralPath $signalParent -PathType Container)) {
  New-Item -Path $signalParent -ItemType Directory -Force | Out-Null
}

$result = [pscustomobject]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = ($repoPath -replace '\\', '/')
  status = $status
  compatibility_status = $compatibilityStatus
  feedback_ingested_count = [int]$feedbackIngestedCount
  compatible_repo_count = [int]$compatibleRepoCount
  repo_count = [int]$repoCount
  repo_failure_count = [int]$repoFailureCount
  missing_required_file_count = [int]$missingRequiredFileCount
  rollout_matrix_missing_control_count = [int]$rolloutMatrixMissingControlCount
  rollout_matrix_missing_repo_state_count = [int]$rolloutMatrixMissingRepoStateCount
  problematic_repo_count = [int]$problematicRepos.Count
  problematic_repos = @($problematicRepos | Select-Object -First 20)
  compatibility_exit_code = [int]$compatibilityRaw.exit_code
  rollout_matrix_exit_code = [int]$matrixRaw.exit_code
  report_path = ($feedbackReportPath -replace '\\', '/')
  signal_path = ($feedbackSignalPath -replace '\\', '/')
}

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $feedbackSignalPath -Encoding UTF8

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  if ($status -eq "ok") { exit 0 }
  exit 1
}

Write-Host ("cross_repo_feedback.status={0}" -f $status)
Write-Host ("cross_repo_feedback.feedback_ingested_count={0}" -f [int]$feedbackIngestedCount)
Write-Host ("cross_repo_feedback.repo_failure_count={0}" -f [int]$repoFailureCount)
Write-Host ("cross_repo_feedback.rollout_matrix_missing_control_count={0}" -f [int]$rolloutMatrixMissingControlCount)
Write-Host ("cross_repo_feedback.rollout_matrix_missing_repo_state_count={0}" -f [int]$rolloutMatrixMissingRepoStateCount)
Write-Host ("cross_repo_feedback.report_path={0}" -f ($feedbackReportPath -replace '\\', '/'))

if ($status -eq "ok") { exit 0 }
exit 1
