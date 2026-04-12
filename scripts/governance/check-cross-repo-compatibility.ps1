param(
  [string]$RepoRoot = ".",
  [string]$PolicyRelativePath = ".governance/cross-repo-compatibility-policy.json",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

function Read-Json([string]$PathText, [object]$DefaultValue) {
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return $DefaultValue }
  try {
    return (Get-Content -LiteralPath $PathText -Raw -Encoding UTF8 | ConvertFrom-Json)
  } catch {
    return $DefaultValue
  }
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$repoWin = $repoPath -replace '/', '\'
$policyPath = Join-Path $repoWin ($PolicyRelativePath -replace '/', '\')
$repositoriesPath = Join-Path $repoWin "config\repositories.json"
$verifyReleaseProfileScript = Join-Path $repoWin "scripts\verify-release-profile.ps1"

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  policy_path = ($policyPath -replace '\\', '/')
  status = "unknown"
  repo_count = 0
  repo_failure_count = 0
  missing_required_file_count = 0
  signal_path = ""
  repos = @()
}

$policy = Read-Json -PathText $policyPath -DefaultValue $null
if ($null -eq $policy) {
  $result.status = "missing_policy"
  if ($AsJson) { $result | ConvertTo-Json -Depth 12 | Write-Output } else { Write-Host "cross_repo_compatibility.status=missing_policy" }
  exit 1
}

$enabled = $true
if ($null -ne $policy.PSObject.Properties['enabled']) { $enabled = [bool]$policy.enabled }
if (-not $enabled) {
  $result.status = "disabled"
  if ($AsJson) { $result | ConvertTo-Json -Depth 12 | Write-Output } else { Write-Host "cross_repo_compatibility.status=disabled" }
  exit 0
}

$reposRaw = Read-Json -PathText $repositoriesPath -DefaultValue @()
if ($null -eq $reposRaw) { $reposRaw = @() }
$repoList = @($reposRaw | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$result.repo_count = $repoList.Count

$requiredFiles = @()
if ($null -ne $policy.PSObject.Properties['required_relative_files']) {
  $requiredFiles = @($policy.required_relative_files | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
}
$runReleaseProfileValidation = $true
if ($null -ne $policy.PSObject.Properties['run_release_profile_validation']) {
  $runReleaseProfileValidation = [bool]$policy.run_release_profile_validation
}
$maxRepoFailureCount = 0
if ($null -ne $policy.PSObject.Properties['max_repo_failure_count']) { try { $maxRepoFailureCount = [int]$policy.max_repo_failure_count } catch { $maxRepoFailureCount = 0 } }
$maxMissingRequiredFileCount = 0
if ($null -ne $policy.PSObject.Properties['max_missing_required_file_count']) { try { $maxMissingRequiredFileCount = [int]$policy.max_missing_required_file_count } catch { $maxMissingRequiredFileCount = 0 } }
$signalRelative = ".governance/cross-repo-compatibility-signal.json"
if ($null -ne $policy.PSObject.Properties['emit_signal_file']) { $signalRelative = [string]$policy.emit_signal_file }
$signalPath = Join-Path $repoWin ($signalRelative -replace '/', '\')
$result.signal_path = ($signalPath -replace '\\', '/')

$repoResults = New-Object System.Collections.Generic.List[object]
$repoFailureCount = 0
$missingRequiredFileCount = 0

foreach ($repo in $repoList) {
  $repoText = ([string]$repo).Trim()
  $repoWinPath = $repoText -replace '/', '\'
  $repoStatus = "ok"
  $missingFiles = New-Object System.Collections.Generic.List[string]
  $releaseProfileStatus = "skipped"

  if (-not (Test-Path -LiteralPath $repoWinPath -PathType Container)) {
    $repoStatus = "repo_missing"
    $repoFailureCount++
  } else {
    foreach ($rel in $requiredFiles) {
      $abs = Join-Path $repoWinPath ($rel -replace '/', '\')
      if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
        $missingFiles.Add(($rel -replace '\\', '/')) | Out-Null
      }
    }
    $missingRequiredFileCount += $missingFiles.Count

    if ($runReleaseProfileValidation) {
      if (-not (Test-Path -LiteralPath $verifyReleaseProfileScript -PathType Leaf)) {
        $releaseProfileStatus = "verify_script_missing"
      } else {
        $profileRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File $verifyReleaseProfileScript -RepoPath $repoWinPath -AsJson 2>&1
        $releaseProfileStatus = if ($LASTEXITCODE -eq 0) { "ok" } else { "failed" }
        if ($releaseProfileStatus -ne "ok") {
          $repoStatus = "release_profile_failed"
        }
      }
    }

    if ($missingFiles.Count -gt 0 -and $repoStatus -eq "ok") {
      $repoStatus = "missing_required_files"
    }
    if ($repoStatus -ne "ok") { $repoFailureCount++ }
  }

  $repoResults.Add([pscustomobject]@{
    repo = ($repoText -replace '\\', '/')
    status = $repoStatus
    release_profile_status = $releaseProfileStatus
    missing_required_files = @($missingFiles.ToArray())
  }) | Out-Null
}

$result.repos = @($repoResults.ToArray())
$result.repo_failure_count = [int]$repoFailureCount
$result.missing_required_file_count = [int]$missingRequiredFileCount

$status = "ok"
if ($repoFailureCount -gt $maxRepoFailureCount) { $status = "repo_failure_violation" }
if ($status -eq "ok" -and $missingRequiredFileCount -gt $maxMissingRequiredFileCount) { $status = "required_file_violation" }
$result.status = $status

$signalObj = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  status = $status
  repo_count = [int]$result.repo_count
  repo_failure_count = [int]$result.repo_failure_count
  missing_required_file_count = [int]$result.missing_required_file_count
}
$signalParent = Split-Path -Parent $signalPath
if (-not (Test-Path -LiteralPath $signalParent -PathType Container)) {
  New-Item -Path $signalParent -ItemType Directory -Force | Out-Null
}
$signalObj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $signalPath -Encoding UTF8

if ($AsJson) {
  $result | ConvertTo-Json -Depth 12 | Write-Output
} else {
  Write-Host ("cross_repo_compatibility.status={0}" -f $result.status)
  Write-Host ("cross_repo_compatibility.repo_count={0}" -f [int]$result.repo_count)
  Write-Host ("cross_repo_compatibility.repo_failure_count={0}" -f [int]$result.repo_failure_count)
  Write-Host ("cross_repo_compatibility.missing_required_file_count={0}" -f [int]$result.missing_required_file_count)
  Write-Host ("cross_repo_compatibility.signal_path={0}" -f $result.signal_path)
}

if ([string]$result.status -ne "ok") { exit 1 }
exit 0
