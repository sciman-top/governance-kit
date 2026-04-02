param(
  [ValidateSet("plan", "safe")]
  [string]$Mode = "plan",
  [ValidateRange(0, 3650)]
  [int]$RetainDays = 30,
  [ValidateRange(0, 10000)]
  [int]$RetainCount = 50,
  [string[]]$ProtectPrefixes = @(),
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$backupRoot = Join-Path $kitRoot "backups"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
if (-not $AsJson) {
  Write-ModeRisk -ScriptName "prune-backups.ps1" -Mode $Mode
}

if (!(Test-Path -LiteralPath $backupRoot)) {
  throw "Backup root not found: $backupRoot"
}

$dirs = @(Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object LastWriteTime -Descending)
$cutoff = (Get-Date).AddDays(-$RetainDays)
$backupRootNorm = [System.IO.Path]::GetFullPath($backupRoot).TrimEnd('\') + '\'

$removed = 0
$kept = 0
$actions = [System.Collections.Generic.List[object]]::new()
$protectList = @($ProtectPrefixes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim() })

for ($i = 0; $i -lt $dirs.Count; $i++) {
  $dir = $dirs[$i]
  $full = [System.IO.Path]::GetFullPath($dir.FullName)
  if (-not $full.StartsWith($backupRootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing out-of-scope prune path: $full"
  }

  $keepByCount = $RetainCount -gt 0 -and $i -lt $RetainCount
  $keepByDays = $RetainDays -gt 0 -and $dir.LastWriteTime -ge $cutoff
  $keepByPrefix = $false
  $matchedPrefix = $null
  foreach ($prefix in $protectList) {
    if ($dir.Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      $keepByPrefix = $true
      $matchedPrefix = $prefix
      break
    }
  }
  $shouldKeep = $keepByCount -or $keepByDays -or $keepByPrefix

  if ($shouldKeep) {
    $kept++
    $reason = "days"
    if ($keepByPrefix -and $keepByCount -and $keepByDays) {
      $reason = "prefix+count+days"
    } elseif ($keepByPrefix -and $keepByCount) {
      $reason = "prefix+count"
    } elseif ($keepByPrefix -and $keepByDays) {
      $reason = "prefix+days"
    } elseif ($keepByPrefix) {
      $reason = "prefix"
    } elseif ($keepByCount -and $keepByDays) {
      $reason = "count+days"
    } elseif ($keepByCount) {
      $reason = "count"
    }
    [void]$actions.Add([pscustomobject]@{
      action = "KEEP"
      path = $full
      reason = $reason
      protected_prefix = $matchedPrefix
      last_write_time = $dir.LastWriteTime.ToString("o")
    })
    continue
  }

  if ($Mode -eq "plan") {
    if (-not $AsJson) {
      Write-Host "[PLAN] PRUNE $full"
    }
  [void]$actions.Add([pscustomobject]@{
    action = "PLAN_PRUNE"
    path = $full
    reason = "expired"
    protected_prefix = $null
    last_write_time = $dir.LastWriteTime.ToString("o")
  })
    continue
  }

  Remove-Item -LiteralPath $full -Recurse -Force
  $removed++
  if (-not $AsJson) {
    Write-Host "[PRUNED] $full"
  }
  [void]$actions.Add([pscustomobject]@{
    action = "PRUNED"
    path = $full
    reason = "expired"
    protected_prefix = $null
    last_write_time = $dir.LastWriteTime.ToString("o")
  })
}

$summary = [pscustomobject]@{
  mode = $Mode
  total = $dirs.Count
  kept = $kept
  removed = $removed
  retain_days = $RetainDays
  retain_count = $RetainCount
  protect_prefixes = @($protectList)
  backup_root = ($backupRoot -replace '\\', '/')
  actions = @($actions)
}

if (-not $AsJson) {
  Write-Host "Done. total=$($dirs.Count) kept=$kept removed=$removed mode=$Mode retain_days=$RetainDays retain_count=$RetainCount"
}

if ($AsJson) {
  $summary | ConvertTo-Json -Depth 8 | Write-Output
}
