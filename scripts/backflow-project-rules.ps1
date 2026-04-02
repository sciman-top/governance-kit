param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$RepoName,
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [switch]$ShowScope,
  [object]$IncludeCustomFiles = $true,
  [switch]$SkipCustomFiles,
  [switch]$IncludeCiSnapshot,
  [ValidateRange(1, 3600)]
  [int]$LockTimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "backflow-project-rules.ps1" -Mode $Mode
$scriptLock = New-ScriptLock -KitRoot $kitRoot -LockName "backflow-project-rules" -TimeoutSeconds $LockTimeoutSeconds

try {

function Convert-ToBool([object]$Value, [string]$ParameterName) {
  if ($Value -is [bool]) {
    return [bool]$Value
  }
  if ($Value -is [int]) {
    if ($Value -eq 1) { return $true }
    if ($Value -eq 0) { return $false }
  }
  $raw = [string]$Value
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Invalid value for -${ParameterName}: empty"
  }
  switch ($raw.Trim().ToLowerInvariant()) {
    "true" { return $true }
    "false" { return $false }
    "1" { return $true }
    "0" { return $false }
    '$true' { return $true }
    '$false' { return $false }
    default { throw "Invalid value for -${ParameterName}: '$raw' (expected true/false/1/0)" }
  }
}

$includeCustom = Convert-ToBool -Value $IncludeCustomFiles -ParameterName "IncludeCustomFiles"

if ($SkipCustomFiles -and $PSBoundParameters.ContainsKey('IncludeCustomFiles') -and $includeCustom) {
  throw "Conflicting arguments: use either -SkipCustomFiles or -IncludeCustomFiles, not both."
}

$shouldIncludeCustomFiles = $includeCustom -and (-not $SkipCustomFiles)

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
$repoNorm = ($repo -replace '\\', '/').TrimEnd('/')

if ([string]::IsNullOrWhiteSpace($RepoName)) {
  $RepoName = Split-Path -Leaf $repo
}

$sourceRepoRoot = Join-Path $kitRoot ("source\project\" + $RepoName)
$projectFiles = @("AGENTS.md", "CLAUDE.md", "GEMINI.md")
$customFiles = @()
if ($shouldIncludeCustomFiles) {
  $customFiles = @(Get-ProjectCustomFilesForRepo -KitRoot $kitRoot -RepoPath $repoNorm -RepoName $RepoName)
}
$modePlan = $Mode -eq "plan"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $kitRoot ("backups\backflow-" + $timestamp + "\" + $RepoName)
$sourceBeforeRoot = Join-Path $backupRoot "source-before"
$targetSnapshotRoot = Join-Path $backupRoot "target-snapshot"
$targetsPath = Join-Path $kitRoot "config\targets.json"

foreach ($f in $projectFiles) {
  $targetFile = Join-Path $repo $f
  if (!(Test-Path $targetFile)) {
    throw "Target project rule file missing: $targetFile"
  }
}

if ($ShowScope) {
  Write-Host "=== SCOPE backflow-project-rules ==="
  foreach ($f in $projectFiles) {
    Write-Host ("- RULE " + (Join-Path $repo $f))
  }
  if ($shouldIncludeCustomFiles) {
    if ($customFiles.Count -eq 0) {
      Write-Host "- CUSTOM (none configured)"
    } else {
      foreach ($rel in $customFiles) {
        Write-Host ("- CUSTOM " + (Join-Path $repo ($rel -replace '/', '\')))
      }
    }
  } else {
    Write-Host "- CUSTOM (disabled by -SkipCustomFiles or -IncludeCustomFiles:`$false)"
  }
}

if ($modePlan) {
  Write-Host "[PLAN] repo=$repo"
  Write-Host "[PLAN] repo_name=$RepoName"
  Write-Host "[PLAN] source_repo_root=$sourceRepoRoot"
  Write-Host "[PLAN] backup_root=$backupRoot"
}

if (-not $modePlan) {
  if (!(Test-Path $sourceRepoRoot)) {
    New-Item -ItemType Directory -Path $sourceRepoRoot -Force | Out-Null
  }
  New-Item -ItemType Directory -Path $sourceBeforeRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $targetSnapshotRoot -Force | Out-Null
}

function Ensure-ParentDir([string]$FilePath) {
  $parent = Split-Path -Parent $FilePath
  if (!(Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
}

function Ensure-TargetMapping([System.Collections.Generic.List[object]]$Targets, [string]$SourceRel, [string]$TargetAbs) {
  $targetNorm = ($TargetAbs -replace '\\', '/')
  $targetMatches = @($Targets | Where-Object { ([string]$_.target -eq $targetNorm) })
  if ($targetMatches.Count -gt 0) {
    $primary = $targetMatches[0]
    if ([string]$primary.source -eq $SourceRel) {
      return $false
    }

    $primary.source = $SourceRel
    return $true
  }

  [void]$Targets.Add([pscustomobject]@{
    source = $SourceRel
    target = $targetNorm
  })
  return $true
}

function Remove-DuplicateTargets([System.Collections.Generic.List[object]]$Targets) {
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $deduped = [System.Collections.Generic.List[object]]::new()
  $removed = 0

  foreach ($item in $Targets) {
    if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.target)) {
      continue
    }

    $targetNorm = [string]$item.target
    if ($seen.Add($targetNorm)) {
      [void]$deduped.Add($item)
      continue
    }

    $removed++
  }

  return [pscustomobject]@{
    items = @($deduped)
    removed = $removed
  }
}

$copied = 0
foreach ($f in $projectFiles) {
  $targetFile = Join-Path $repo $f
  $sourceFile = Join-Path $sourceRepoRoot $f
  $backupSourceFile = Join-Path $sourceBeforeRoot $f
  $backupTargetFile = Join-Path $targetSnapshotRoot $f

  if ($modePlan) {
    Write-Host "[PLAN] SNAPSHOT target: $targetFile -> $backupTargetFile"
    if (Test-Path $sourceFile) {
      Write-Host "[PLAN] BACKUP source-before: $sourceFile -> $backupSourceFile"
    }
    Write-Host "[PLAN] BACKFLOW copy: $targetFile -> $sourceFile"
    continue
  }

  Copy-Item -LiteralPath $targetFile -Destination $backupTargetFile -Force
  if (Test-Path $sourceFile) {
    Copy-Item -LiteralPath $sourceFile -Destination $backupSourceFile -Force
  }
  Copy-Item -LiteralPath $targetFile -Destination $sourceFile -Force
  $copied++
  Write-Host "[COPIED] $targetFile -> $sourceFile"
}

$customCopied = 0
$customSkipped = 0
$targetsAdded = 0
if ($shouldIncludeCustomFiles) {
  if ($customFiles.Count -eq 0) {
    Write-Host "[SKIP] no custom project files configured for repo: $RepoName"
    $suggestCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$kitRoot\scripts\suggest-project-custom-files.ps1`" -RepoPath `"$repo`" -RepoName `"$RepoName`""
    Write-Host "[WARN] custom policy for '$RepoName' is empty. Run candidate scan and review before next backflow."
    Write-Host "[HINT] $suggestCmd"
  } else {
    if ($modePlan) {
      Write-Host "[PLAN] custom_files_count=$($customFiles.Count)"
    }

    $targets = [System.Collections.Generic.List[object]]::new()
    if (-not $modePlan) {
      foreach ($t in @(Read-JsonArray $targetsPath)) {
        [void]$targets.Add($t)
      }
    }

    foreach ($rel in $customFiles) {
      $relWin = $rel -replace '/', '\'
      $targetFile = Join-Path $repo $relWin
      $sourceFile = Join-Path (Join-Path $sourceRepoRoot "custom") $relWin
      $backupSourceFile = Join-Path (Join-Path $sourceBeforeRoot "custom") $relWin
      $backupTargetFile = Join-Path (Join-Path $targetSnapshotRoot "custom") $relWin
      $sourceRel = "source/project/$RepoName/custom/$($rel -replace '\\','/')"
      $targetRel = "$repoNorm/$($rel -replace '\\','/')"

      if (!(Test-Path -LiteralPath $targetFile)) {
        if ($modePlan) {
          Write-Host "[PLAN] SKIP custom missing target: $targetFile"
        } else {
          Write-Host "[SKIP] custom missing target: $targetFile"
        }
        $customSkipped++
        continue
      }

      if ($modePlan) {
        Write-Host "[PLAN] SNAPSHOT custom target: $targetFile -> $backupTargetFile"
        if (Test-Path -LiteralPath $sourceFile) {
          Write-Host "[PLAN] BACKUP custom source-before: $sourceFile -> $backupSourceFile"
        }
        Write-Host "[PLAN] BACKFLOW custom copy: $targetFile -> $sourceFile"
        Write-Host "[PLAN] ENSURE target mapping: $sourceRel -> $targetRel"
        continue
      }

      Ensure-ParentDir -FilePath $sourceFile
      Ensure-ParentDir -FilePath $backupTargetFile
      Copy-Item -LiteralPath $targetFile -Destination $backupTargetFile -Force
      if (Test-Path -LiteralPath $sourceFile) {
        Ensure-ParentDir -FilePath $backupSourceFile
        Copy-Item -LiteralPath $sourceFile -Destination $backupSourceFile -Force
      }
      Copy-Item -LiteralPath $targetFile -Destination $sourceFile -Force
      $customCopied++
      if (Ensure-TargetMapping -Targets $targets -SourceRel $sourceRel -TargetAbs $targetRel) {
        $targetsAdded++
      }
      Write-Host "[COPIED] custom $targetFile -> $sourceFile"
    }

    if (-not $modePlan) {
      $dedupe = Remove-DuplicateTargets -Targets $targets
      $targets = [System.Collections.Generic.List[object]]::new()
      foreach ($item in @($dedupe.items)) {
        [void]$targets.Add($item)
      }

      if ($targetsAdded -gt 0 -or [int]$dedupe.removed -gt 0) {
        Write-JsonArray -Path $targetsPath -Items @($targets) -Depth 8
      }
      if ($targetsAdded -gt 0) {
        Write-Host "[UPDATED] targets.json added_or_updated_custom_mappings=$targetsAdded"
      }
      if ([int]$dedupe.removed -gt 0) {
        Write-Host "[UPDATED] targets.json removed_duplicate_targets=$([int]$dedupe.removed)"
      }
    }
  }
}

if ($IncludeCiSnapshot) {
  $ciFiles = @(
    ".github\workflows\quality-gates.yml",
    "azure-pipelines.yml",
    ".gitlab-ci.yml"
  )
  $ciSnapshotRoot = Join-Path $backupRoot "ci-snapshot"
  if (-not $modePlan) {
    New-Item -ItemType Directory -Path $ciSnapshotRoot -Force | Out-Null
  }

  foreach ($rel in $ciFiles) {
    $targetCi = Join-Path $repo $rel
    if (!(Test-Path $targetCi)) { continue }
    $dst = Join-Path $ciSnapshotRoot ($rel -replace '[\\/]', '__')
    if ($modePlan) {
      Write-Host "[PLAN] SNAPSHOT ci: $targetCi -> $dst"
    } else {
      Copy-Item -LiteralPath $targetCi -Destination $dst -Force
      Write-Host "[SNAPSHOT] ci: $targetCi -> $dst"
    }
  }
}

if ($modePlan) {
  Write-Host "Plan done. copied_rules=$copied custom_copied=$customCopied custom_skipped=$customSkipped targets_added=$targetsAdded"
  return
}

Write-Host "Done. copied_rules=$copied custom_copied=$customCopied custom_skipped=$customSkipped targets_added=$targetsAdded backup_root=$backupRoot"
Write-Host "[NOTE] global user-level files are intentionally excluded."
} finally {
  Release-ScriptLock -LockHandle $scriptLock
}
