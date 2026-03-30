param(
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

$modePlan = $Mode -eq "plan"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $kitRoot ("backups\orphan-custom-prune-" + $timestamp)

$orphanJson = Invoke-ChildScriptCapture -ScriptPath (Join-Path $PSScriptRoot "check-orphan-custom-sources.ps1") -ScriptArgs @("-AsJson")
$orphan = $orphanJson | ConvertFrom-Json
$items = @($orphan.items)

$removed = 0
$skipped = 0
$actions = @()

if ($items.Count -eq 0) {
  if (-not $AsJson) { Write-Host "prune-orphan-custom-sources: no orphan files" }
  if ($AsJson) {
    @{
      mode = $Mode
      removed = 0
      skipped = 0
      backup_root = ""
      items = @()
    } | ConvertTo-Json -Depth 6 | Write-Output
  }
  exit 0
}

foreach ($it in $items) {
  $path = [string]$it.path
  if ([string]::IsNullOrWhiteSpace($path) -or !(Test-Path -LiteralPath $path)) {
    $skipped++
    $actions += [pscustomobject]@{ action = "SKIP_MISSING"; path = $path }
    continue
  }

  $rel = $path.Substring($kitRoot.Length).TrimStart('\')
  $backupPath = Join-Path $backupRoot $rel
  if ($modePlan) {
    if (-not $AsJson) {
      Write-Host "[PLAN] PRUNE $path"
      Write-Host "[PLAN] BACKUP $path -> $backupPath"
    }
    $actions += [pscustomobject]@{ action = "PLAN_PRUNE"; path = $path; backup = $backupPath }
    continue
  }

  $backupDir = Split-Path -Parent $backupPath
  if (!(Test-Path -LiteralPath $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  }
  Copy-Item -LiteralPath $path -Destination $backupPath -Force
  try {
    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Normal)
  } catch {}
  try {
    Remove-Item -LiteralPath $path -Force -ErrorAction Stop
    if (-not $AsJson) { Write-Host "[PRUNED] $path" }
    $removed++
    $actions += [pscustomobject]@{ action = "PRUNED"; path = $path; backup = $backupPath }
  } catch {
    if (-not $AsJson) { Write-Host "[SKIP] delete failed: $path" }
    $skipped++
    $actions += [pscustomobject]@{ action = "SKIP_DELETE_FAILED"; path = $path; backup = $backupPath; error = $_.Exception.Message }
  }
}

if ($modePlan) {
  if (-not $AsJson) { Write-Host "Plan done. orphan_count=$($items.Count)" }
} else {
  if (-not $AsJson) { Write-Host "Done. removed=$removed skipped=$skipped backup_root=$backupRoot" }
}

if ($AsJson) {
  @{
    mode = $Mode
    removed = $removed
    skipped = $skipped
    backup_root = if ($modePlan) { "" } else { ($backupRoot -replace '\\', '/') }
    items = @($actions)
  } | ConvertTo-Json -Depth 6 | Write-Output
}
