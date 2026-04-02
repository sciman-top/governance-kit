param(
  [ValidateSet("plan", "smoke", "full")]
  [string]$Mode = "smoke",
  [string]$MatrixPath = "",
  [switch]$FailOnMissingRepo,
  [ValidateRange(10, 7200)]
  [int]$CommandTimeoutSeconds = 900,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

if ([string]::IsNullOrWhiteSpace($MatrixPath)) {
  $MatrixPath = Join-Path $kitRoot "config\real-repo-regression-matrix.json"
}

if (!(Test-Path -LiteralPath $MatrixPath)) {
  throw "Regression matrix not found: $MatrixPath"
}

try {
  $matrix = Get-Content -LiteralPath $MatrixPath -Raw | ConvertFrom-Json
} catch {
  throw "Regression matrix invalid JSON: $MatrixPath"
}

$repos = @($matrix.repos)
$results = [System.Collections.Generic.List[object]]::new()
$issues = [System.Collections.Generic.List[string]]::new()
$startedAt = Get-Date

function Invoke-RepoCommand([string]$RepoPath, [string]$CommandText, [int]$TimeoutSeconds) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "powershell"
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command $CommandText"
  $psi.WorkingDirectory = $RepoPath
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()
  if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
    try { $proc.Kill() } catch {}
    return [pscustomobject]@{
      exit_code = -1
      output = ""
      error = "timeout after ${TimeoutSeconds}s"
    }
  }

  return [pscustomobject]@{
    exit_code = $proc.ExitCode
    output = $proc.StandardOutput.ReadToEnd().TrimEnd()
    error = $proc.StandardError.ReadToEnd().TrimEnd()
  }
}

foreach ($entry in $repos) {
  $repoName = [string]$entry.repo_name
  $repoPath = Normalize-Repo ([string]$entry.repo)
  $repoWin = $repoPath -replace '/', '\'
  $requiredPaths = @($entry.required_paths)
  $smokeCommand = [string]$entry.smoke_command
  $fullCommand = [string]$entry.full_command

  $item = [ordered]@{
    repo_name = $repoName
    repo = $repoPath
    mode = $Mode
    status = "PASS"
    missing_repo = $false
    missing_paths = @()
    command = $null
    command_exit_code = $null
    command_output = ""
    command_error = ""
    skipped = $false
  }

  if (!(Test-Path -LiteralPath $repoWin -PathType Container)) {
    $item.missing_repo = $true
    $item.status = if ($FailOnMissingRepo) { "FAIL" } else { "SKIP" }
    $item.skipped = -not $FailOnMissingRepo
    [void]$results.Add([pscustomobject]$item)
    if ($FailOnMissingRepo) {
      [void]$issues.Add("repo missing: $repoPath")
    }
    continue
  }

  $missingPaths = [System.Collections.Generic.List[string]]::new()
  foreach ($rp in $requiredPaths) {
    $full = Join-Path $repoWin ($rp -replace '/', '\')
    if (!(Test-Path -LiteralPath $full)) {
      [void]$missingPaths.Add($rp)
    }
  }
  if ($missingPaths.Count -gt 0) {
    $item.status = "FAIL"
    $item.missing_paths = @($missingPaths)
    [void]$results.Add([pscustomobject]$item)
    [void]$issues.Add("$repoName missing required paths: $($missingPaths -join ',')")
    continue
  }

  if ($Mode -eq "plan") {
    [void]$results.Add([pscustomobject]$item)
    continue
  }

  $selectedCommand = $smokeCommand
  if ($Mode -eq "full" -and -not [string]::IsNullOrWhiteSpace($fullCommand)) {
    $selectedCommand = $fullCommand
  }
  if ([string]::IsNullOrWhiteSpace($selectedCommand)) {
    $item.status = "SKIP"
    $item.skipped = $true
    [void]$results.Add([pscustomobject]$item)
    continue
  }

  $item.command = $selectedCommand
  $cmdResult = Invoke-RepoCommand -RepoPath $repoWin -CommandText $selectedCommand -TimeoutSeconds $CommandTimeoutSeconds
  $item.command_exit_code = $cmdResult.exit_code
  $item.command_output = $cmdResult.output
  $item.command_error = $cmdResult.error
  if ($cmdResult.exit_code -ne 0) {
    $item.status = "FAIL"
    [void]$issues.Add("$repoName command failed: exit=$($cmdResult.exit_code)")
  }

  [void]$results.Add([pscustomobject]$item)
}

$failed = @($results | Where-Object { $_.status -eq "FAIL" }).Count
$summary = [pscustomobject]@{
  schema_version = "1.0"
  matrix_schema_version = [string]$matrix.schema_version
  generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  mode = $Mode
  status = if ($failed -eq 0) { "PASS" } else { "FAIL" }
  total = $results.Count
  failed = $failed
  skipped = @($results | Where-Object { $_.status -eq "SKIP" }).Count
  duration_seconds = [int][math]::Round(((Get-Date) - $startedAt).TotalSeconds)
  matrix_path = (Resolve-Path -LiteralPath $MatrixPath).Path -replace '\\','/'
  results = @($results)
  issues = @($issues)
}

if ($AsJson) {
  $summary | ConvertTo-Json -Depth 10 | Write-Output
  if ($failed -eq 0) { return } else { exit 1 }
}

Write-Host "real-repo-regression mode=$Mode total=$($summary.total) failed=$($summary.failed) skipped=$($summary.skipped)"
foreach ($r in $results) {
  if ($r.status -eq "PASS") {
    Write-Host "[PASS] $($r.repo_name)"
  } elseif ($r.status -eq "SKIP") {
    if ($r.missing_repo) {
      Write-Host "[SKIP] $($r.repo_name) repo missing: $($r.repo)"
    } else {
      Write-Host "[SKIP] $($r.repo_name)"
    }
  } else {
    if (@($r.missing_paths).Count -gt 0) {
      Write-Host "[FAIL] $($r.repo_name) missing_paths=$(@($r.missing_paths) -join ',')"
    } else {
      Write-Host "[FAIL] $($r.repo_name) exit=$($r.command_exit_code)"
    }
  }
}

if ($failed -gt 0) {
  exit 1
}
