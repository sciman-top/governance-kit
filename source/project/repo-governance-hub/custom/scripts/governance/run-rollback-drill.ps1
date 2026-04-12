param(
  [string]$RepoRoot = ".",
  [ValidateSet("safe", "plan")]
  [string]$Mode = "safe",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$repoWin = $repoPath -replace '/', '\\'
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  mode = $Mode
  status = "unknown"
  recovery_ms = 0
  target_path = ""
  snapshot_name = ""
  restore_exit_code = 0
  error = ""
}

if ($Mode -eq "plan") {
  $result.status = "planned"
  if ($AsJson) { $result | ConvertTo-Json -Depth 8 | Write-Output } else { Write-Host "rollback_drill.status=planned" }
  exit 0
}

$tmp = Join-Path $env:TEMP ("govkit-rollback-drill-" + [guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $tmp "backups") -Force | Out-Null

  Copy-Item -Path (Join-Path $repoWin "scripts\restore.ps1") -Destination (Join-Path $tmp "scripts\restore.ps1") -Force
  Copy-Item -Path (Join-Path $repoWin "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

  $targetPath = Join-Path $tmp "sandbox\target\demo.txt"
  New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
  Set-Content -Path $targetPath -Value "before-rollback-drill" -Encoding UTF8

  @(@{ source = "source/placeholder.txt"; target = $targetPath }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

  $snapshotName = "drill-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  $snapshotRoot = Join-Path $tmp ("backups\" + $snapshotName)
  $targetNorm = [System.IO.Path]::GetFullPath($targetPath)
  $drive = $targetNorm.Substring(0, 1)
  $rest = $targetNorm.Substring(3)
  $snapshotFile = Join-Path $snapshotRoot (Join-Path $drive $rest)
  New-Item -ItemType Directory -Path (Split-Path -Parent $snapshotFile) -Force | Out-Null
  Set-Content -Path $snapshotFile -Value "after-rollback-drill" -Encoding UTF8

  $restoreOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\restore.ps1") -BackupName $snapshotName 2>&1 | Out-String
  $restoreExit = $LASTEXITCODE
  $result.restore_exit_code = [int]$restoreExit

  if ($restoreExit -ne 0) {
    throw "restore drill failed with exit code $restoreExit output=$restoreOutput"
  }

  $actual = (Get-Content -Path $targetPath -Raw -Encoding UTF8).Trim()
  if ($actual -ne "after-rollback-drill") {
    throw "restore result mismatch expected=after-rollback-drill actual=$actual"
  }

  $sw.Stop()
  $result.status = "ok"
  $result.recovery_ms = [int]$sw.ElapsedMilliseconds
  $result.target_path = ($targetPath -replace '\\', '/')
  $result.snapshot_name = $snapshotName
}
catch {
  $sw.Stop()
  $result.status = "failed"
  $result.recovery_ms = [int]$sw.ElapsedMilliseconds
  $result.error = $_.Exception.Message
}
finally {
  if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
} else {
  Write-Host ("rollback_drill.status={0}" -f $result.status)
  Write-Host ("rollback_drill.recovery_ms={0}" -f [int]$result.recovery_ms)
  Write-Host ("rollback_drill.restore_exit_code={0}" -f [int]$result.restore_exit_code)
}

if ([string]$result.status -ne "ok" -and [string]$result.status -ne "planned") { exit 1 }
exit 0
