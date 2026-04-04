param(
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

$repositoriesPath = Join-Path $kitRoot "config\repositories.json"
$verifyScript = Join-Path $PSScriptRoot "verify-release-profile.ps1"

if (-not (Test-Path -LiteralPath $repositoriesPath)) {
  throw "repositories.json not found: $repositoriesPath"
}
if (-not (Test-Path -LiteralPath $verifyScript)) {
  throw "verify-release-profile.ps1 not found: $verifyScript"
}

$repos = @(Read-JsonArray $repositoriesPath)
$results = [System.Collections.Generic.List[object]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($repo in $repos) {
  $repoText = [string]$repo
  if ([string]::IsNullOrWhiteSpace($repoText)) { continue }
  $repoResolved = Resolve-Path -LiteralPath $repoText -ErrorAction SilentlyContinue
  if ($null -eq $repoResolved) {
    $entry = [pscustomobject]@{
      repo = ($repoText -replace '\\', '/')
      status = "FAIL"
      reason = "repo path not found"
    }
    [void]$results.Add($entry)
    [void]$failed.Add($repoText)
    continue
  }

  $jsonRaw = Invoke-ChildScriptCapture -ScriptPath $verifyScript -ScriptArgs @("-RepoPath", $repoResolved.Path, "-AsJson")
  $obj = $jsonRaw | ConvertFrom-Json
  [void]$results.Add($obj)
  if ([string]$obj.status -ne "PASS") {
    [void]$failed.Add([string]$obj.repo)
  }
}

if ($AsJson) {
  [pscustomobject]@{
    schema_version = "1.0"
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    failed_count = $failed.Count
    failed_repos = @($failed)
    results = @($results)
  } | ConvertTo-Json -Depth 12 | Write-Output
  if ($failed.Count -eq 0) { exit 0 } else { exit 1 }
}

if ($failed.Count -eq 0) {
  Write-Host "[PASS] release-profile coverage"
  exit 0
}

Write-Host "[FAIL] release-profile coverage"
foreach ($item in @($results | Where-Object { $_.status -ne "PASS" })) {
  $repoName = if ($item.repo_name) { [string]$item.repo_name } else { [string]$item.repo }
  Write-Host " - repo=$repoName"
  if ($item.errors) {
    foreach ($err in @($item.errors)) {
      Write-Host "   * $err"
    }
  } elseif ($item.reason) {
    Write-Host "   * $($item.reason)"
  }
}
exit 1
