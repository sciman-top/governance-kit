param(
  [string]$RepoRoot = ".",
  [string]$PolicyRelativePath = ".governance/failure-replay/policy.json",
  [string]$CasesRelativePath = ".governance/failure-replay/replay-cases.json",
  [string]$RegistryRelativePath = ".governance/skill-candidates/promotion-registry.json",
  [string]$EventsRelativePath = ".governance/skill-candidates/events.jsonl",
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

function Read-JsonLines([string]$PathText) {
  if (-not (Test-Path -LiteralPath $PathText -PathType Leaf)) { return @() }
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($line in @(Get-Content -LiteralPath $PathText -Encoding UTF8)) {
    if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
    try { $items.Add(($line | ConvertFrom-Json)) | Out-Null } catch { }
  }
  return @($items.ToArray())
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$policyPath = Join-Path ($repoPath -replace '/', '\\') ($PolicyRelativePath -replace '/', '\\')
$casesPath = Join-Path ($repoPath -replace '/', '\\') ($CasesRelativePath -replace '/', '\\')
$registryPath = Join-Path ($repoPath -replace '/', '\\') ($RegistryRelativePath -replace '/', '\\')
$eventsPath = Join-Path ($repoPath -replace '/', '\\') ($EventsRelativePath -replace '/', '\\')

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  policy_path = ($policyPath -replace '\\', '/')
  cases_path = ($casesPath -replace '\\', '/')
  status = "unknown"
  top_signature_target = 5
  observed_signature_count = 0
  catalog_case_count = 0
  top5_coverage_rate = 0
  missing_top5_count = 0
  missing_top5_signatures = @()
  top_signatures = @()
}

$policy = Read-Json -PathText $policyPath -DefaultValue $null
if ($null -eq $policy) {
  $result.status = "missing_policy"
  if ($AsJson) { $result | ConvertTo-Json -Depth 12 | Write-Output } else { Write-Host "failure_replay.status=missing_policy" }
  exit 1
}

$casesDoc = Read-Json -PathText $casesPath -DefaultValue $null
if ($null -eq $casesDoc -or $null -eq $casesDoc.PSObject.Properties['cases']) {
  $result.status = "missing_cases"
  if ($AsJson) { $result | ConvertTo-Json -Depth 12 | Write-Output } else { Write-Host "failure_replay.status=missing_cases" }
  exit 1
}

$targetTop = 5
if ($null -ne $policy.PSObject.Properties['max_top_signatures']) {
  try { $targetTop = [Math]::Max(1, [int]$policy.max_top_signatures) } catch { $targetTop = 5 }
}
$result.top_signature_target = [int]$targetTop

$scoreMap = @{}

$events = @(Read-JsonLines -PathText $eventsPath)
foreach ($e in $events) {
  if ($null -eq $e -or $null -eq $e.PSObject.Properties['issue_signature']) { continue }
  $sig = ([string]$e.issue_signature).Trim().ToLowerInvariant()
  if ([string]::IsNullOrWhiteSpace($sig)) { continue }
  if (-not $scoreMap.ContainsKey($sig)) { $scoreMap[$sig] = 0 }
  $scoreMap[$sig] = [int]$scoreMap[$sig] + 1
}

$registry = Read-Json -PathText $registryPath -DefaultValue $null
if ($null -ne $registry -and $null -ne $registry.PSObject.Properties['promoted']) {
  foreach ($p in @($registry.promoted)) {
    if ($null -eq $p -or $null -eq $p.PSObject.Properties['issue_signature']) { continue }
    $sig = ([string]$p.issue_signature).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($sig)) { continue }
    $hits = 1
    if ($null -ne $p.PSObject.Properties['hit_count']) {
      try { $hits = [Math]::Max(1, [int]$p.hit_count) } catch { $hits = 1 }
    }
    if (-not $scoreMap.ContainsKey($sig)) { $scoreMap[$sig] = 0 }
    $scoreMap[$sig] = [int]$scoreMap[$sig] + $hits
  }
}

$ranked = @($scoreMap.GetEnumerator() | Sort-Object -Property @{Expression='Value'; Descending=$true}, @{Expression='Name'; Descending=$false})
$topSignatures = New-Object System.Collections.Generic.List[string]
foreach ($entry in $ranked) {
  if ($topSignatures.Count -ge $targetTop) { break }
  $topSignatures.Add([string]$entry.Key) | Out-Null
}

$allowFallback = $true
if ($null -ne $policy.PSObject.Properties['allow_catalog_fallback_when_observed_insufficient']) {
  $allowFallback = [bool]$policy.allow_catalog_fallback_when_observed_insufficient
}

$cases = @($casesDoc.cases)
$result.catalog_case_count = @($cases).Count
if ($allowFallback -and $topSignatures.Count -lt $targetTop) {
  $catalogRanked = @($cases | Where-Object { [bool]$_.enabled -and -not [string]::IsNullOrWhiteSpace([string]$_.issue_signature) } | Sort-Object -Property @{Expression={ if ($null -ne $_.priority) { [int]$_.priority } else { 0 } }; Descending=$true}, @{Expression={ [string]$_.issue_signature }; Descending=$false})
  foreach ($c in $catalogRanked) {
    if ($topSignatures.Count -ge $targetTop) { break }
    $sig = ([string]$c.issue_signature).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($sig)) { continue }
    if ($topSignatures -contains $sig) { continue }
    $topSignatures.Add($sig) | Out-Null
  }
}

$result.observed_signature_count = $ranked.Count
$result.top_signatures = @($topSignatures.ToArray())

$missing = New-Object System.Collections.Generic.List[string]
foreach ($sig in @($topSignatures.ToArray())) {
  $matched = @($cases | Where-Object {
    [bool]$_.enabled -and
    ([string]$_.issue_signature).Trim().ToLowerInvariant() -eq $sig -and
    $null -ne $_.replay -and
    -not [string]::IsNullOrWhiteSpace([string]$_.replay.command) -and
    -not [string]::IsNullOrWhiteSpace([string]$_.replay.expected_pattern)
  })
  if ($matched.Count -eq 0) { $missing.Add($sig) | Out-Null }
}

$result.missing_top5_signatures = @($missing.ToArray())
$result.missing_top5_count = @($result.missing_top5_signatures).Count
if ($topSignatures.Count -gt 0) {
  $covered = $topSignatures.Count - $result.missing_top5_count
  $result.top5_coverage_rate = [Math]::Round(([double]$covered / [double]$topSignatures.Count), 6)
}

if ($topSignatures.Count -lt $targetTop) {
  $result.status = "insufficient_top_signatures"
} elseif ($result.missing_top5_count -gt 0) {
  $result.status = "missing_replay_cases"
} else {
  $result.status = "ok"
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 12 | Write-Output
} else {
  Write-Host ("failure_replay.status={0}" -f $result.status)
  Write-Host ("failure_replay.top_signature_target={0}" -f [int]$result.top_signature_target)
  Write-Host ("failure_replay.top5_coverage_rate={0}" -f $result.top5_coverage_rate)
  Write-Host ("failure_replay.missing_top5_count={0}" -f [int]$result.missing_top5_count)
}

if ([string]$result.status -ne "ok") { exit 1 }
exit 0
