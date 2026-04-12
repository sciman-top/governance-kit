param(
  [string]$RepoRoot = ".",
  [string]$PolicyRelativePath = ".governance/skill-family-health-policy.json",
  [string]$RegistryRelativePath = ".governance/skill-candidates/promotion-registry.json",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

function Read-Json([string]$PathText, [object]$DefaultValue) {
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return $DefaultValue }
  try {
    return (Get-Content -LiteralPath $PathText -Raw -Encoding UTF8 | ConvertFrom-Json)
  } catch {
    return $DefaultValue
  }
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$policyPath = Join-Path ($repoPath -replace '/', '\\') ($PolicyRelativePath -replace '/', '\\')
$registryPath = Join-Path ($repoPath -replace '/', '\\') ($RegistryRelativePath -replace '/', '\\')

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  policy_path = ($policyPath -replace '\\', '/')
  registry_path = ($registryPath -replace '\\', '/')
  status = "unknown"
  target_entry_count = 0
  active_family_duplicate_count = 0
  low_health_target_state_count = 0
  active_family_avg_health_score = 0
  missing_health_score_count = 0
  duplicate_families = @()
}

$policy = Read-Json -PathText $policyPath -DefaultValue $null
if ($null -eq $policy) {
  $result.status = "missing_policy"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_family_health.status=missing_policy" }
  exit 1
}

$registry = Read-Json -PathText $registryPath -DefaultValue $null
if ($null -eq $registry -or $null -eq $registry.PSObject.Properties['promoted']) {
  $result.status = "missing_registry"
  if ($AsJson) { $result | ConvertTo-Json -Depth 10 | Write-Output } else { Write-Host "skill_family_health.status=missing_registry" }
  exit 1
}

$targetStates = @("active", "approved")
if ($null -ne $policy.PSObject.Properties['target_states'] -and $policy.target_states -is [System.Array]) {
  $targetStates = @($policy.target_states | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
$targetStateSet = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in $targetStates) { $targetStateSet.Add($s) | Out-Null }

$requireHealth = $true
if ($null -ne $policy.PSObject.Properties['require_health_score_for_target_states']) {
  $requireHealth = [bool]$policy.require_health_score_for_target_states
}

$minHealth = 0.7
if ($null -ne $policy.PSObject.Properties['min_health_score_for_target_states']) {
  try { $minHealth = [double]$policy.min_health_score_for_target_states } catch { $minHealth = 0.7 }
}

$maxDup = 0
if ($null -ne $policy.PSObject.Properties['max_active_family_duplicates']) {
  try { $maxDup = [int]$policy.max_active_family_duplicates } catch { $maxDup = 0 }
}

$maxLowHealth = 0
if ($null -ne $policy.PSObject.Properties['max_low_health_target_state_count']) {
  try { $maxLowHealth = [int]$policy.max_low_health_target_state_count } catch { $maxLowHealth = 0 }
}

$familyCount = @{}
$duplicateFamilies = New-Object System.Collections.Generic.List[string]
$healthSum = 0.0
$healthCount = 0
$missingHealth = 0
$lowHealth = 0
$targetCount = 0

foreach ($entry in @($registry.promoted)) {
  if ($null -eq $entry) { continue }
  $state = ""
  if ($null -ne $entry.PSObject.Properties['lifecycle_state']) {
    $state = ([string]$entry.lifecycle_state).Trim().ToLowerInvariant()
  }
  if (-not $targetStateSet.Contains($state)) { continue }

  $family = ""
  if ($null -ne $entry.PSObject.Properties['family_signature']) {
    $family = ([string]$entry.family_signature).Trim().ToLowerInvariant()
  }
  if ([string]::IsNullOrWhiteSpace($family) -and $null -ne $entry.PSObject.Properties['issue_signature']) {
    $family = ([string]$entry.issue_signature).Trim().ToLowerInvariant()
  }
  if ([string]::IsNullOrWhiteSpace($family)) { $family = "<missing-family>" }

  if (-not $familyCount.ContainsKey($family)) { $familyCount[$family] = 0 }
  $familyCount[$family] = [int]$familyCount[$family] + 1

  $targetCount++

  $hasHealth = $false
  $health = 0.0
  if ($null -ne $entry.PSObject.Properties['health_score']) {
    try {
      $health = [double]$entry.health_score
      $hasHealth = $true
    } catch {
      $hasHealth = $false
    }
  }

  if (-not $hasHealth) {
    $missingHealth++
    continue
  }

  $healthSum += $health
  $healthCount++
  if ($health -lt $minHealth) {
    $lowHealth++
  }
}

foreach ($kv in $familyCount.GetEnumerator()) {
  if ([int]$kv.Value -gt 1) {
    $duplicateFamilies.Add([string]$kv.Key) | Out-Null
  }
}

$result.target_entry_count = [int]$targetCount
$result.active_family_duplicate_count = @($duplicateFamilies).Count
$result.low_health_target_state_count = [int]$lowHealth
$result.missing_health_score_count = [int]$missingHealth
$result.duplicate_families = @($duplicateFamilies.ToArray() | Sort-Object)
if ($healthCount -gt 0) {
  $result.active_family_avg_health_score = [Math]::Round(([double]$healthSum / [double]$healthCount), 6)
}

$status = "ok"
if ($result.active_family_duplicate_count -gt $maxDup) { $status = "duplicate_family_violation" }
if ($status -eq "ok" -and $requireHealth -and $result.missing_health_score_count -gt 0) { $status = "missing_health_score" }
if ($status -eq "ok" -and $result.low_health_target_state_count -gt $maxLowHealth) { $status = "low_health_violation" }
$result.status = $status

if ($AsJson) {
  $result | ConvertTo-Json -Depth 10 | Write-Output
} else {
  Write-Host ("skill_family_health.status={0}" -f $result.status)
  Write-Host ("skill_family_health.target_entry_count={0}" -f [int]$result.target_entry_count)
  Write-Host ("skill_family_health.active_family_duplicate_count={0}" -f [int]$result.active_family_duplicate_count)
  Write-Host ("skill_family_health.low_health_target_state_count={0}" -f [int]$result.low_health_target_state_count)
  Write-Host ("skill_family_health.active_family_avg_health_score={0}" -f $result.active_family_avg_health_score)
}

if ([string]$result.status -ne "ok") { exit 1 }
exit 0
