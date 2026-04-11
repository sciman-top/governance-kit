param(
  [ValidateSet("plan", "safe")]
  [string]$Mode = "",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

function Get-DistributionPrunePolicy([string]$KitRoot) {
  $path = Join-Path $KitRoot "config\distribution-prune-policy.json"
  $raw = Read-JsonFile -Path $path -DefaultValue $null -DisplayName "distribution-prune-policy.json"
  if ($null -eq $raw) {
    return [pscustomobject]@{
      enabled = $false
      default_mode = "plan"
      enforce_after_days = 14
      ownership = [pscustomobject]@{
        required_for_delete = $true
        manifest_path = ".governance/distribution-state.json"
      }
      safety_guards = [pscustomobject]@{
        max_delete_per_run = 30
        max_delete_ratio = 0.2
        block_on_unmanaged_conflict = $true
        dry_run_required_before_safe = $true
      }
      protected_paths = @()
      protected_globs = @()
      gate = [pscustomobject]@{
        fail_on_delete_budget_exceeded = $true
        fail_on_orphans_in_enforce = $true
      }
      repo_overrides = @()
    }
  }

  if ($null -eq $raw.PSObject.Properties['enabled']) { $raw | Add-Member -NotePropertyName enabled -NotePropertyValue $true }
  if ($null -eq $raw.PSObject.Properties['default_mode']) { $raw | Add-Member -NotePropertyName default_mode -NotePropertyValue "plan" }
  if ($null -eq $raw.PSObject.Properties['enforce_after_days']) { $raw | Add-Member -NotePropertyName enforce_after_days -NotePropertyValue 14 }
  if ($null -eq $raw.PSObject.Properties['ownership']) {
    $raw | Add-Member -NotePropertyName ownership -NotePropertyValue ([pscustomobject]@{
      required_for_delete = $true
      manifest_path = ".governance/distribution-state.json"
    })
  }
  if ($null -eq $raw.ownership.PSObject.Properties['required_for_delete']) { $raw.ownership | Add-Member -NotePropertyName required_for_delete -NotePropertyValue $true }
  if ($null -eq $raw.ownership.PSObject.Properties['manifest_path']) { $raw.ownership | Add-Member -NotePropertyName manifest_path -NotePropertyValue ".governance/distribution-state.json" }
  if ($null -eq $raw.PSObject.Properties['safety_guards']) {
    $raw | Add-Member -NotePropertyName safety_guards -NotePropertyValue ([pscustomobject]@{
      max_delete_per_run = 30
      max_delete_ratio = 0.2
      block_on_unmanaged_conflict = $true
      dry_run_required_before_safe = $true
    })
  }
  if ($null -eq $raw.safety_guards.PSObject.Properties['max_delete_per_run']) { $raw.safety_guards | Add-Member -NotePropertyName max_delete_per_run -NotePropertyValue 30 }
  if ($null -eq $raw.safety_guards.PSObject.Properties['max_delete_ratio']) { $raw.safety_guards | Add-Member -NotePropertyName max_delete_ratio -NotePropertyValue 0.2 }
  if ($null -eq $raw.safety_guards.PSObject.Properties['block_on_unmanaged_conflict']) { $raw.safety_guards | Add-Member -NotePropertyName block_on_unmanaged_conflict -NotePropertyValue $true }
  if ($null -eq $raw.safety_guards.PSObject.Properties['dry_run_required_before_safe']) { $raw.safety_guards | Add-Member -NotePropertyName dry_run_required_before_safe -NotePropertyValue $true }
  if ($null -eq $raw.PSObject.Properties['protected_paths']) { $raw | Add-Member -NotePropertyName protected_paths -NotePropertyValue @() }
  if ($null -eq $raw.PSObject.Properties['protected_globs']) { $raw | Add-Member -NotePropertyName protected_globs -NotePropertyValue @() }
  if ($null -eq $raw.PSObject.Properties['gate']) {
    $raw | Add-Member -NotePropertyName gate -NotePropertyValue ([pscustomobject]@{
      fail_on_delete_budget_exceeded = $true
      fail_on_orphans_in_enforce = $true
    })
  }
  if ($null -eq $raw.gate.PSObject.Properties['fail_on_delete_budget_exceeded']) { $raw.gate | Add-Member -NotePropertyName fail_on_delete_budget_exceeded -NotePropertyValue $true }
  if ($null -eq $raw.gate.PSObject.Properties['fail_on_orphans_in_enforce']) { $raw.gate | Add-Member -NotePropertyName fail_on_orphans_in_enforce -NotePropertyValue $true }
  if ($null -eq $raw.PSObject.Properties['repo_overrides']) { $raw | Add-Member -NotePropertyName repo_overrides -NotePropertyValue @() }

  return $raw
}

function Get-EffectiveRepoPolicy([object]$Policy, [string]$RepoPath) {
  $repoNorm = Normalize-Repo $RepoPath
  $repoName = Split-Path -Leaf $repoNorm
  $effective = [pscustomobject]@{
    enabled = [bool]$Policy.enabled
    default_mode = [string]$Policy.default_mode
    enforce_after_days = [int]$Policy.enforce_after_days
    ownership = $Policy.ownership
    safety_guards = $Policy.safety_guards
    protected_paths = @($Policy.protected_paths)
    protected_globs = @($Policy.protected_globs)
    gate = $Policy.gate
  }

  foreach ($entry in @($Policy.repo_overrides)) {
    if ($null -eq $entry) { continue }
    $match = $false
    if ($entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
      if (Normalize-Repo ([string]$entry.repo) -eq $repoNorm) { $match = $true }
    }
    if (-not $match -and $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
      if (([string]$entry.repoName).Equals($repoName, [System.StringComparison]::OrdinalIgnoreCase)) { $match = $true }
    }
    if (-not $match) { continue }

    if ($entry.PSObject.Properties['enabled']) { $effective.enabled = [bool]$entry.enabled }
    if ($entry.PSObject.Properties['default_mode']) { $effective.default_mode = [string]$entry.default_mode }
    if ($entry.PSObject.Properties['enforce_after_days']) { $effective.enforce_after_days = [int]$entry.enforce_after_days }
    if ($entry.PSObject.Properties['safety_guards'] -and $null -ne $entry.safety_guards) {
      $merged = [pscustomobject]@{}
      foreach ($p in $effective.safety_guards.PSObject.Properties) {
        $merged | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
      }
      foreach ($p in $entry.safety_guards.PSObject.Properties) {
        if ($merged.PSObject.Properties[$p.Name]) {
          $merged.$($p.Name) = $p.Value
        } else {
          $merged | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
        }
      }
      $effective.safety_guards = $merged
    }
  }

  return $effective
}

function Is-ProtectedPath([string]$RelativePath, [object]$Policy) {
  $rel = ($RelativePath -replace '\\', '/').TrimStart('/')
  foreach ($p in @($Policy.protected_paths)) {
    $pp = ([string]$p -replace '\\', '/').TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($pp)) { continue }
    if ($pp.EndsWith('/')) {
      if ($rel.StartsWith($pp, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
      continue
    }
    if ($rel.Equals($pp, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  foreach ($g in @($Policy.protected_globs)) {
    $gg = ([string]$g -replace '\\', '/').Trim()
    if ([string]::IsNullOrWhiteSpace($gg)) { continue }
    $matcher = [System.Management.Automation.WildcardPattern]::new($gg, [System.Management.Automation.WildcardOptions]::IgnoreCase)
    if ($matcher.IsMatch($rel)) { return $true }
  }
  return $false
}

function Get-RepoByTarget([string]$TargetPath, [string[]]$RepoPathsSorted) {
  foreach ($repo in $RepoPathsSorted) {
    $prefix = $repo.TrimEnd('\') + '\'
    if ($TargetPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $repo
    }
  }
  return $null
}

function Read-ManifestManagedPaths([string]$ManifestPath) {
  if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { return @() }
  $manifest = Read-JsonFile -Path $ManifestPath -DefaultValue $null -DisplayName $ManifestPath
  if ($null -eq $manifest) { return @() }
  $paths = New-Object System.Collections.Generic.List[string]
  foreach ($item in @($manifest.managed_files)) {
    if ($null -eq $item) { continue }
    if ($item -is [string]) {
      if (-not [string]::IsNullOrWhiteSpace([string]$item)) { $paths.Add(([string]$item -replace '\\', '/').TrimStart('/')) | Out-Null }
      continue
    }
    if ($item.PSObject.Properties['path'] -and -not [string]::IsNullOrWhiteSpace([string]$item.path)) {
      $paths.Add((([string]$item.path -replace '\\', '/').TrimStart('/'))) | Out-Null
    }
  }
  return @($paths.ToArray())
}

function Write-Manifest([string]$ManifestPath, [string]$RepoRoot, [System.Collections.Generic.Dictionary[string,string]]$DesiredByRel) {
  $manifestDir = Split-Path -Parent $ManifestPath
  if (-not (Test-Path -LiteralPath $manifestDir -PathType Container)) {
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
  }

  $managed = New-Object System.Collections.Generic.List[object]
  $keys = @($DesiredByRel.Keys | Sort-Object)
  foreach ($rel in $keys) {
    $abs = Join-Path $RepoRoot ($rel -replace '/', '\')
    $sha = ""
    if (Test-Path -LiteralPath $abs -PathType Leaf) {
      $sha = Get-FileSha256 -Path $abs
    }
    $managed.Add([pscustomobject]@{
      path = $rel
      source = [string]$DesiredByRel[$rel]
      sha256 = $sha
    }) | Out-Null
  }

  $obj = [pscustomobject]@{
    version = 1
    tool = "repo-governance-hub"
    updated_at = (Get-Date).ToString("s")
    managed_count = $managed.Count
    managed_files = @($managed.ToArray())
  }
  $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
}

$policy = Get-DistributionPrunePolicy -KitRoot $kitRoot
if (-not [bool]$policy.enabled) {
  if ($AsJson) {
    @{
      mode = "skip"
      enabled = $false
      repo_count = 0
      total_orphan_candidates = 0
      total_pruned = 0
      should_fail_gate = $false
      repos = @()
    } | ConvertTo-Json -Depth 8 | Write-Output
  } else {
    Write-Host "[INFO] prune-target-orphans disabled by policy"
  }
  exit 0
}

$modeEffective = $Mode
if ([string]::IsNullOrWhiteSpace($modeEffective)) {
  $modeEffective = [string]$policy.default_mode
}
if (@("plan", "safe") -notcontains $modeEffective) {
  throw "invalid mode '$modeEffective' (expected plan|safe)"
}
$modePlan = $modeEffective -eq "plan"

$targetsPath = Join-Path $kitRoot "config\targets.json"
$reposPath = Join-Path $kitRoot "config\repositories.json"
if (-not (Test-Path -LiteralPath $targetsPath -PathType Leaf)) { throw "targets.json not found: $targetsPath" }
if (-not (Test-Path -LiteralPath $reposPath -PathType Leaf)) { throw "repositories.json not found: $reposPath" }

$targets = @(Read-JsonArray $targetsPath)
$repos = @()
foreach ($repo in @(Read-JsonArray $reposPath)) {
  if ([string]::IsNullOrWhiteSpace([string]$repo)) { continue }
  $rp = [System.IO.Path]::GetFullPath(([string]$repo -replace '/', '\'))
  if (Test-Path -LiteralPath $rp -PathType Container) {
    $repos += $rp
  }
}

$repoPathsSorted = @($repos | Sort-Object { $_.Length } -Descending)
$desiredByRepo = @{}
foreach ($t in $targets) {
  if ($null -eq $t) { continue }
  $srcRel = [string]$t.source
  $dstRaw = [string]$t.target
  if ([string]::IsNullOrWhiteSpace($srcRel) -or [string]::IsNullOrWhiteSpace($dstRaw)) { continue }
  $dst = [System.IO.Path]::GetFullPath(($dstRaw -replace '/', '\'))
  $repoRoot = Get-RepoByTarget -TargetPath $dst -RepoPathsSorted $repoPathsSorted
  if ($null -eq $repoRoot) { continue }
  $rel = Get-RelativePathSafe -BasePath $repoRoot -TargetPath $dst
  if (-not $desiredByRepo.ContainsKey($repoRoot)) {
    $desiredByRepo[$repoRoot] = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  }
  $desiredByRepo[$repoRoot][$rel] = $srcRel
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $kitRoot ("backups\target-orphan-prune-" + $timestamp)
$repoResults = New-Object System.Collections.Generic.List[object]
$totalCandidates = 0
$totalPruned = 0
$shouldFailGate = $false

foreach ($repoRoot in $repoPathsSorted) {
  if (-not $desiredByRepo.ContainsKey($repoRoot)) { continue }
  $desiredRel = $desiredByRepo[$repoRoot]
  $effectivePolicy = Get-EffectiveRepoPolicy -Policy $policy -RepoPath $repoRoot
  if (-not [bool]$effectivePolicy.enabled) { continue }

  $manifestRel = [string]$effectivePolicy.ownership.manifest_path
  if ([string]::IsNullOrWhiteSpace($manifestRel)) {
    $manifestRel = ".governance/distribution-state.json"
  }
  $manifestPath = Join-Path $repoRoot ($manifestRel -replace '/', '\')
  $previousManaged = @(Read-ManifestManagedPaths -ManifestPath $manifestPath)
  $prevSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($p in $previousManaged) { [void]$prevSet.Add($p) }

  $candidates = New-Object System.Collections.Generic.List[string]
  foreach ($rel in $previousManaged) {
    if ($desiredRel.ContainsKey($rel)) { continue }
    $abs = Join-Path $repoRoot ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) { continue }
    $candidates.Add($rel) | Out-Null
  }

  $blockedByBudget = $false
  $candidateCount = $candidates.Count
  $prevCount = [Math]::Max(1, $previousManaged.Count)
  $ratio = [double]$candidateCount / [double]$prevCount
  $maxDelete = [int]$effectivePolicy.safety_guards.max_delete_per_run
  $maxRatio = [double]$effectivePolicy.safety_guards.max_delete_ratio
  if ($candidateCount -gt $maxDelete -or $ratio -gt $maxRatio) {
    $blockedByBudget = $true
    if ([bool]$effectivePolicy.gate.fail_on_delete_budget_exceeded) {
      $shouldFailGate = $true
    }
  }

  $pruned = 0
  $skippedProtected = 0
  $skippedBudget = 0
  $actions = New-Object System.Collections.Generic.List[object]

  foreach ($rel in $candidates) {
    $abs = Join-Path $repoRoot ($rel -replace '/', '\')
    if (Is-ProtectedPath -RelativePath $rel -Policy $effectivePolicy) {
      $skippedProtected++
      $actions.Add([pscustomobject]@{ action = "SKIP_PROTECTED"; path = $rel }) | Out-Null
      continue
    }
    if ($blockedByBudget) {
      $skippedBudget++
      $actions.Add([pscustomobject]@{ action = "SKIP_BUDGET"; path = $rel }) | Out-Null
      continue
    }
    if ($modePlan) {
      $actions.Add([pscustomobject]@{ action = "PLAN_PRUNE"; path = $rel }) | Out-Null
      continue
    }

    $backupPath = Join-Path $backupRoot ((Split-Path -Leaf $repoRoot) + "\" + ($rel -replace '/', '\'))
    $backupDir = Split-Path -Parent $backupPath
    if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) {
      New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $abs -Destination $backupPath -Force
    Remove-Item -LiteralPath $abs -Force
    $pruned++
    $actions.Add([pscustomobject]@{ action = "PRUNED"; path = $rel; backup = ($backupPath -replace '\\', '/') }) | Out-Null
  }

  if (-not $modePlan) {
    Write-Manifest -ManifestPath $manifestPath -RepoRoot $repoRoot -DesiredByRel $desiredRel
  }

  $totalCandidates += $candidateCount
  $totalPruned += $pruned
  if ([bool]$effectivePolicy.gate.fail_on_orphans_in_enforce -and $effectivePolicy.default_mode -eq "safe" -and $candidateCount -gt 0) {
    $shouldFailGate = $true
  }

  $repoResults.Add([pscustomobject]@{
    repo = ($repoRoot -replace '\\', '/')
    mode = $modeEffective
    manifest_path = ($manifestPath -replace '\\', '/')
    desired_count = $desiredRel.Count
    previous_managed_count = $previousManaged.Count
    orphan_candidates = $candidateCount
    pruned = $pruned
    skipped_protected = $skippedProtected
    skipped_budget = $skippedBudget
    blocked_by_budget = $blockedByBudget
    actions = @($actions.ToArray())
  }) | Out-Null
}

$result = [pscustomobject]@{
  mode = $modeEffective
  enabled = $true
  repo_count = $repoResults.Count
  total_orphan_candidates = $totalCandidates
  total_pruned = $totalPruned
  should_fail_gate = $shouldFailGate
  backup_root = if ($modePlan -or $totalPruned -eq 0) { "" } else { ($backupRoot -replace '\\', '/') }
  repos = @($repoResults.ToArray())
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 10 | Write-Output
} else {
  Write-Host ("prune_target_orphans.mode=" + $modeEffective)
  Write-Host ("prune_target_orphans.repo_count=" + $repoResults.Count)
  Write-Host ("prune_target_orphans.total_orphan_candidates=" + $totalCandidates)
  Write-Host ("prune_target_orphans.total_pruned=" + $totalPruned)
  if (-not [string]::IsNullOrWhiteSpace([string]$result.backup_root)) {
    Write-Host ("prune_target_orphans.backup_root=" + $result.backup_root)
  }
  if ($shouldFailGate) {
    Write-Host "prune_target_orphans.should_fail_gate=true"
  }
}

