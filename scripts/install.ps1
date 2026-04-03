param(
  [switch]$NoBackup,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$ShowScope,
  [switch]$NoOverwriteRules,
  [string]$NoOverwriteUnderRepo,
  [switch]$FullCycle,
  [switch]$AutoRemediate,
  [switch]$NoAutoRemediate,
  [ValidateRange(1, 10)]
  [int]$MaxAutoFixAttempts = 1,
  [switch]$SkipPostVerify,
  [switch]$AsJson,
  [ValidateRange(1, 3600)]
  [int]$LockTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
$kitRoot = Split-Path -Parent $PSScriptRoot
$targetsPath = Join-Path $kitRoot "config\targets.json"
if (!(Test-Path $targetsPath)) {
  throw "targets.json not found: $targetsPath"
}
Write-ModeRisk -ScriptName "install.ps1" -Mode $Mode
$scriptLock = New-ScriptLock -KitRoot $kitRoot -LockName "install" -TimeoutSeconds $LockTimeoutSeconds
$fullCycleTargets = @()
$modePlan = $Mode -eq "plan"
$fullCycleMode = if ($modePlan) { "plan" } else { "safe" }

if ($AutoRemediate.IsPresent -and $NoAutoRemediate.IsPresent) {
  Write-Host "[DEPRECATED] -AutoRemediate/-NoAutoRemediate are ignored. Remediation is handled by the outer AI session."
} elseif ($AutoRemediate.IsPresent -or $NoAutoRemediate.IsPresent) {
  Write-Host "[DEPRECATED] -AutoRemediate/-NoAutoRemediate are ignored. Remediation is handled by the outer AI session."
}
if ($PSBoundParameters.ContainsKey("MaxAutoFixAttempts")) {
  Write-Host "[DEPRECATED] -MaxAutoFixAttempts is ignored because in-script auto remediation is disabled."
}

function Get-FullCycleRepos {
  param(
    [Parameter(Mandatory = $true)][string]$KitRoot,
    [Parameter(Mandatory = $true)][array]$Targets
  )

  $repos = [System.Collections.Generic.List[string]]::new()
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $repositoriesPath = Join-Path $KitRoot "config\repositories.json"

  if (Test-Path -LiteralPath $repositoriesPath) {
    try {
      $repoRaw = Get-Content -Path $repositoriesPath -Raw | ConvertFrom-Json
      $repoItems = if ($repoRaw -is [System.Array]) { @($repoRaw) } elseif ($null -eq $repoRaw) { @() } else { @($repoRaw) }
      foreach ($repoItem in $repoItems) {
        if ([string]::IsNullOrWhiteSpace([string]$repoItem)) { continue }
        $full = [System.IO.Path]::GetFullPath(([string]$repoItem -replace '/', '\'))
        if ((Test-Path -LiteralPath $full -PathType Container) -and $seen.Add($full)) {
          $repos.Add($full)
        }
      }
    } catch {
      throw "repositories.json is not valid JSON: $repositoriesPath"
    }
  }

  if ($repos.Count -eq 0) {
    foreach ($item in $Targets) {
      if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.target)) { continue }
      $dst = [System.IO.Path]::GetFullPath(([string]$item.target -replace '/', '\'))
      $repoRoot = Split-Path -Parent (Split-Path -Parent $dst)
      if ([string]::IsNullOrWhiteSpace($repoRoot)) { continue }
      if ((Test-Path -LiteralPath $repoRoot -PathType Container) -and (Test-Path -LiteralPath (Join-Path $repoRoot ".git"))) {
        if ($seen.Add($repoRoot)) {
          $repos.Add($repoRoot)
        }
      }
    }
  }

  return @($repos)
}

try {

try {
  $raw = Get-Content -Path $targetsPath -Raw | ConvertFrom-Json
} catch {
  throw "targets.json is not valid JSON: $targetsPath"
}

$targets = if ($raw -is [System.Array]) { @($raw) } elseif ($null -eq $raw) { @() } else { @($raw) }
if ($targets.Count -eq 0) {
  throw "targets.json has no entries: $targetsPath"
}

if ($ShowScope) {
  Write-Host "=== SCOPE install ==="
  Write-Host "targets.count=$($targets.Count)"
  foreach ($item in $targets) {
    if ($null -eq $item) { continue }
    $srcRel = [string]$item.source
    $dstRaw = [string]$item.target
    if ([string]::IsNullOrWhiteSpace($srcRel) -or [string]::IsNullOrWhiteSpace($dstRaw)) { continue }
    Write-Host ("- " + $srcRel + " -> " + ($dstRaw -replace '/', '\'))
  }
}

$cfgFail = 0
$seenTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($item in $targets) {
  if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.source) -or [string]::IsNullOrWhiteSpace([string]$item.target)) {
    Write-Host "[CFG] invalid entry (missing source/target)"
    $cfgFail++
    continue
  }

  if ([System.IO.Path]::IsPathRooted([string]$item.source)) {
    Write-Host "[CFG] source must be relative path: $($item.source)"
    $cfgFail++
    continue
  }

  if (-not [System.IO.Path]::IsPathRooted(([string]$item.target -replace '/', '\'))) {
    Write-Host "[CFG] target must be absolute path: $($item.target)"
    $cfgFail++
    continue
  }

  $normTarget = [System.IO.Path]::GetFullPath(([string]$item.target -replace '/', '\'))
  if (-not $seenTargets.Add($normTarget)) {
    Write-Host "[CFG] duplicate target path: $normTarget"
    $cfgFail++
  }
}
if ($cfgFail -gt 0) {
  throw "targets.json validation failed: $cfgFail issue(s)"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $kitRoot ("backups\\" + $timestamp)

if ($Mode -eq "force") {
  if ($NoOverwriteRules -or -not [string]::IsNullOrWhiteSpace($NoOverwriteUnderRepo)) {
    Write-Host "[INFO] force mode ignores no-overwrite protections"
  }
  $NoOverwriteRules = $false
  $NoOverwriteUnderRepo = $null
}
$repoProtectPrefix = $null
if (-not [string]::IsNullOrWhiteSpace($NoOverwriteUnderRepo)) {
  $repoProtectPrefix = ([System.IO.Path]::GetFullPath(($NoOverwriteUnderRepo -replace '/', '\'))).TrimEnd('\') + '\'
}
$copied = 0
$backedUp = 0
$skipped = 0
$records = @()

foreach ($item in $targets) {
  $srcRel = $item.source
  $dstRaw = $item.target
  $src = Join-Path $kitRoot $srcRel
  $dst = [System.IO.Path]::GetFullPath(($dstRaw -replace '/', '\'))

  if (!(Test-Path $src)) {
    throw "Source not found: $src"
  }

  $dstExists = Test-Path $dst
  $same = $false
  if ($dstExists) {
    $h1 = (Get-FileHash -Path $src -Algorithm SHA256).Hash
    $h2 = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
    $same = $h1 -eq $h2
  }

  $protectByRepo = $false
  if ($null -ne $repoProtectPrefix) {
    $protectByRepo = $dst.StartsWith($repoProtectPrefix, [System.StringComparison]::OrdinalIgnoreCase)
  }

  if (($NoOverwriteRules -or $protectByRepo) -and $dstExists -and -not $same) {
    Write-Host "[SKIP] overwrite disabled: $srcRel -> $dst"
    $skipped++
    $records += [pscustomobject]@{
      source = $srcRel
      target = $dst
      action = "SKIP_OVERWRITE_DISABLED"
      mode = $Mode
    }
    continue
  }

  $action = if (-not $dstExists) { "CREATE" } elseif ($same) { "UNCHANGED" } else { "UPDATE" }
  if ($modePlan) {
    Write-Host "[PLAN] $action $srcRel -> $dst"
    $records += [pscustomobject]@{
      source = $srcRel
      target = $dst
      action = $action
      mode = $Mode
    }
    continue
  }

  $dstDir = Split-Path -Parent $dst
  if (!(Test-Path $dstDir)) {
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
  }

  if ($dstExists -and -not $NoBackup -and -not $same) {
    $rel = $dst.Replace(':', '').TrimStart('\\')
    $backupPath = Join-Path $backupRoot $rel
    $backupDir = Split-Path -Parent $backupPath
    if (!(Test-Path $backupDir)) {
      New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    Copy-Item -Path $dst -Destination $backupPath -Force
    $backedUp++
  }

  if (-not $same) {
    Copy-Item -Path $src -Destination $dst -Force
    $copied++
    Write-Host "[COPIED] $srcRel -> $dst"
    $records += [pscustomobject]@{
      source = $srcRel
      target = $dst
      action = $action
      mode = $Mode
    }
  } else {
    Write-Host "[SKIP] unchanged: $srcRel -> $dst"
    $skipped++
    $records += [pscustomobject]@{
      source = $srcRel
      target = $dst
      action = "UNCHANGED"
      mode = $Mode
    }
  }
}

if ($modePlan) {
  if ($FullCycle) {
    $fullCycleTargets = @(Get-FullCycleRepos -KitRoot $kitRoot -Targets $targets)
    foreach ($repoPath in $fullCycleTargets) {
      Write-Host ("[PLAN] FULL_CYCLE repo=" + ($repoPath -replace '\\', '/'))
    }
  }
  if ($AsJson) {
    @{
      mode = $Mode
      copied = 0
      backup = 0
      skipped = ($records | Where-Object { $_.action -like "SKIP*" -or $_.action -eq "UNCHANGED" }).Count
      items = @($records)
    } | ConvertTo-Json -Depth 6 | Write-Output
  }
  Write-Host "Plan done."
} else {
  Write-Host "Done. copied=$copied backup=$backedUp skipped=$skipped mode=$Mode"
  if (-not $NoBackup -and $backedUp -gt 0) {
    Write-Host "Backup root: $backupRoot"
  }

  if (-not $SkipPostVerify) {
    & "$PSScriptRoot\verify.ps1"
    if ($LASTEXITCODE -ne 0) {
      throw "Post-verify failed with exit code ${LASTEXITCODE}"
    }
    Write-Host "[ASSERT] post-verify passed"
  }

  if ($AsJson) {
    @{
      mode = $Mode
      copied = $copied
      backup = $backedUp
      skipped = $skipped
      items = @($records)
    } | ConvertTo-Json -Depth 6 | Write-Output
  }

  if ($FullCycle) {
    $fullCycleTargets = @(Get-FullCycleRepos -KitRoot $kitRoot -Targets $targets)
  }
}
} finally {
  Release-ScriptLock -LockHandle $scriptLock
}

if ($FullCycle) {
  $cycleScript = Join-Path $PSScriptRoot "run-project-governance-cycle.ps1"
  if (-not (Test-Path -LiteralPath $cycleScript)) {
    throw "Missing script: $cycleScript"
  }
  if ($fullCycleTargets.Count -eq 0) {
    Write-Host "[INFO] FULL_CYCLE requested but no repository targets discovered."
    return
  }
  foreach ($repoPath in $fullCycleTargets) {
    Write-Host ("=== FULL_CYCLE " + ($repoPath -replace '\\', '/') + " ===")
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $cycleScript,
      "-RepoPath", $repoPath,
      "-RepoName", (Split-Path -Leaf $repoPath),
      "-Mode", $fullCycleMode
    )
    if ($ShowScope) { $args += "-ShowScope" }

    & powershell @args
    if ($LASTEXITCODE -ne 0) {
      throw "run-project-governance-cycle failed for $repoPath with exit code $LASTEXITCODE"
    }
  }
}
