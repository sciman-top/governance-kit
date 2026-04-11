param(
  [switch]$NoBackup,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$ShowScope,
  [switch]$NoOverwriteRules,
  [string]$NoOverwriteUnderRepo,
  [switch]$SkipTargetsRefresh,
  [switch]$FullCycle,
  [switch]$SkipPostGate,
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
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
$kitRoot = Split-Path -Parent $PSScriptRoot
$refreshScript = Join-Path $PSScriptRoot "refresh-targets.ps1"
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

if ($SkipPostGate.IsPresent) {
  Write-Host "[WARN] SkipPostGate enabled; full local gate chain after install is skipped."
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
      $repoItems = @(Read-JsonArray $repositoriesPath)
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

if (-not $SkipTargetsRefresh) {
  if (-not (Test-Path -LiteralPath $refreshScript -PathType Leaf)) {
    Write-Host "[INFO] skip targets refresh: refresh-targets.ps1 not found in current workspace"
  } else {
    $reposConfigPath = Join-Path $kitRoot "config\repositories.json"
    if (Test-Path -LiteralPath $reposConfigPath -PathType Leaf) {
      $refreshMode = if ($modePlan) { "plan" } else { "safe" }
      Invoke-ChildScript -ScriptPath $refreshScript -ScriptArgs @("-Mode", $refreshMode)
    } else {
      Write-Host "[INFO] skip targets refresh: repositories.json not found in current workspace"
    }
  }
}

try {
  $targets = @(Read-JsonArray $targetsPath)
} catch {
  throw "targets.json is not valid JSON: $targetsPath"
}

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
$pruneResult = $null

foreach ($item in $targets) {
  $srcRel = $item.source
  $dstRaw = $item.target
  $src = Join-Path $kitRoot $srcRel
  $dst = [System.IO.Path]::GetFullPath(($dstRaw -replace '/', '\'))
  $isSkillMarkdown = ([System.IO.Path]::GetFileName($src)).Equals("SKILL.md", [System.StringComparison]::OrdinalIgnoreCase)

  if (!(Test-Path $src)) {
    throw "Source not found: $src"
  }

  $dstExists = Test-Path $dst
  $same = $false
  if ($dstExists -and $isSkillMarkdown) {
    $srcNormalized = Read-SkillMarkdownNormalized $src
    $dstNormalized = Read-SkillMarkdownNormalized $dst
    $same = ($srcNormalized -ceq $dstNormalized)
  } elseif ($dstExists) {
    $same = Test-FileContentEqual -PathA $src -PathB $dst
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
    if ($isSkillMarkdown) {
      $srcNormalized = Read-SkillMarkdownNormalized $src
      Write-SkillMarkdownNormalized -Path $dst -Content $srcNormalized
    } else {
      Copy-Item -Path $src -Destination $dst -Force
    }
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
  $pruneScript = Join-Path $PSScriptRoot "prune-target-orphans.ps1"
  if (Test-Path -LiteralPath $pruneScript -PathType Leaf) {
    $pruneOutput = Invoke-ChildScriptCapture -ScriptPath $pruneScript -ScriptArgs @("-Mode", "plan", "-AsJson")
    $pruneText = ($pruneOutput | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($pruneText)) {
      $pruneResult = $pruneText | ConvertFrom-Json
      Write-Host ("[PLAN] PRUNE_TARGET_ORPHANS candidates=" + [int]$pruneResult.total_orphan_candidates)
    }
  } else {
    Write-Host "[INFO] skip target orphan prune: prune-target-orphans.ps1 not found in current workspace"
  }

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
      prune = $pruneResult
      items = @($records)
    } | ConvertTo-Json -Depth 6 | Write-Output
  }
  Write-Host "Plan done."
} else {
  $pruneScript = Join-Path $PSScriptRoot "prune-target-orphans.ps1"
  if (Test-Path -LiteralPath $pruneScript -PathType Leaf) {
    $pruneOutput = Invoke-ChildScriptCapture -ScriptPath $pruneScript -ScriptArgs @("-Mode", "safe", "-AsJson")
    $pruneText = ($pruneOutput | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($pruneText)) {
      $pruneResult = $pruneText | ConvertFrom-Json
      Write-Host ("[ASSERT] target orphan prune done. candidates=" + [int]$pruneResult.total_orphan_candidates + " pruned=" + [int]$pruneResult.total_pruned)
    }
  } else {
    Write-Host "[INFO] skip target orphan prune: prune-target-orphans.ps1 not found in current workspace"
  }

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

  if (-not $SkipPostGate) {
    $buildScript = Join-Path $PSScriptRoot "verify-kit.ps1"
    $testScript = Join-Path $kitRoot "tests\governance-kit.optimization.tests.ps1"
    $contractScript = Join-Path $PSScriptRoot "validate-config.ps1"
    $hotspotScript = Join-Path $PSScriptRoot "doctor.ps1"

    $gateScriptsReady = (Test-Path -LiteralPath $buildScript -PathType Leaf) -and
      (Test-Path -LiteralPath $testScript -PathType Leaf) -and
      (Test-Path -LiteralPath $contractScript -PathType Leaf) -and
      (Test-Path -LiteralPath $hotspotScript -PathType Leaf)

    if ($gateScriptsReady) {
      Write-Host "=== POST_GATE build ==="
      Invoke-ChildScript -ScriptPath $buildScript

      Write-Host "=== POST_GATE test ==="
      Invoke-ChildScript -ScriptPath $testScript

      Write-Host "=== POST_GATE contract/invariant ==="
      Invoke-ChildScript -ScriptPath $contractScript
      Invoke-ChildScript -ScriptPath (Join-Path $PSScriptRoot "verify.ps1")

      Write-Host "=== POST_GATE hotspot ==="
      Invoke-ChildScript -ScriptPath $hotspotScript
      Write-Host "[ASSERT] post-gate full chain passed"
    } else {
      Write-Host "[INFO] skip post-gate: required gate scripts not found in current workspace"
    }
  }

  if ($AsJson) {
    @{
      mode = $Mode
      copied = $copied
      backup = $backedUp
      skipped = $skipped
      prune = $pruneResult
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
    $cycleArgs = @(
      "-RepoPath", $repoPath,
      "-RepoName", (Split-Path -Leaf $repoPath),
      "-Mode", $fullCycleMode
    )
    if ($ShowScope) { $cycleArgs += "-ShowScope" }
    Invoke-ChildScript -ScriptPath $cycleScript -ScriptArgs $cycleArgs
  }
}
