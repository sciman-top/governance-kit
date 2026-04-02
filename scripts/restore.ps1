param(
  [string]$BackupName,
  [switch]$AllowOutOfScope,
  [ValidateRange(1, 3600)]
  [int]$LockTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
$backupRoot = Join-Path $kitRoot "backups"
$targetsPath = Join-Path $kitRoot "config\targets.json"
$scriptLock = New-ScriptLock -KitRoot $kitRoot -LockName "restore" -TimeoutSeconds $LockTimeoutSeconds

try {

if (!(Test-Path $backupRoot)) {
  throw "Backup root not found: $backupRoot"
}
if (!(Test-Path $targetsPath)) {
  throw "targets.json not found: $targetsPath"
}

$targets = Get-Content -Path $targetsPath -Raw | ConvertFrom-Json
$allowedTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($t in $targets) {
  $norm = [System.IO.Path]::GetFullPath(($t.target -replace '/', '\'))
  [void]$allowedTargets.Add($norm)
}

if ([string]::IsNullOrWhiteSpace($BackupName)) {
  $latest = Get-ChildItem -Path $backupRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
  if ($null -eq $latest) { throw "No backup snapshots found under $backupRoot" }
  $snapshot = $latest.FullName
} else {
  $snapshot = Join-Path $backupRoot $BackupName
  if (!(Test-Path $snapshot)) { throw "Backup snapshot not found: $snapshot" }
}

$files = Get-ChildItem -Path $snapshot -File -Recurse
if ($files.Count -eq 0) { throw "No files found in snapshot: $snapshot" }

$restored = 0
foreach ($f in $files) {
  $relative = $f.FullName.Substring($snapshot.Length).TrimStart('\\')
  $parts = $relative -split '\\'
  if ($parts.Length -lt 2) { continue }

  $drive = $parts[0]
  if ($drive.Length -ne 1) { continue }

  $sub = ($parts[1..($parts.Length-1)] -join '\\')
  $target = "$drive`:\$sub"
  $targetNorm = [System.IO.Path]::GetFullPath($target)

  if (-not $AllowOutOfScope -and -not $allowedTargets.Contains($targetNorm)) {
    throw "Out-of-scope restore target blocked: $targetNorm. Use -AllowOutOfScope to override."
  }

  $targetDir = Split-Path -Parent $target
  if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  Copy-Item -Path $f.FullName -Destination $targetNorm -Force
  $restored++
  Write-Host "[RESTORED] $targetNorm"
}

Write-Host "Restore done. files=$restored snapshot=$snapshot"
} finally {
  Release-ScriptLock -LockHandle $scriptLock
}
