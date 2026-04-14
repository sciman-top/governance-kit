param(
  [string]$TargetsPath = "",
  [string]$PolicyPath = "",
  [switch]$AsJson,
  [switch]$ShowPassItems,
  [switch]$NoFailOnViolation
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$commonPath = Join-Path $kitRoot "scripts\lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
function Get-BoundarySourceLayer([string]$Source) {
  $s = ([string]$Source -replace '\\', '/')
  if ($s.StartsWith("source/global/", [System.StringComparison]::OrdinalIgnoreCase)) {
    return "global"
  }
  if ($s.StartsWith("source/template/project/", [System.StringComparison]::OrdinalIgnoreCase)) {
    return "project"
  }
  if ($s.StartsWith("source/project/_common/", [System.StringComparison]::OrdinalIgnoreCase)) {
    return "shared-template"
  }
  if ($s.StartsWith("source/project/", [System.StringComparison]::OrdinalIgnoreCase)) {
    return "project"
  }
  return "unknown"
}

if ([string]::IsNullOrWhiteSpace($TargetsPath)) {
  $TargetsPath = Join-Path $kitRoot "config\targets.json"
}
if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
  $PolicyPath = Join-Path $kitRoot "config\boundary-classification-policy.json"
}
if (-not (Test-Path -LiteralPath $TargetsPath -PathType Leaf)) {
  throw "targets.json not found: $TargetsPath"
}
if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
  throw "boundary classification policy not found: $PolicyPath"
}

try {
  $targets = @(Read-JsonArray $TargetsPath)
} catch {
  throw "targets.json invalid JSON: $TargetsPath"
}

$policy = Read-JsonFile -Path $PolicyPath -DisplayName $PolicyPath
$repoRoots = @(Read-TargetRepoRoots -KitRoot $kitRoot)
$reviewTemplatePath = "docs/governance/boundary-review-template.zh-CN.md"

$globalTargetRegexes = @()
if ($null -ne $policy.PSObject.Properties["global_user_allowed_targets"] -and $policy.global_user_allowed_targets -is [System.Array]) {
  foreach ($r in @($policy.global_user_allowed_targets)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$r)) {
      $globalTargetRegexes += [string]$r
    }
  }
}

function Test-MatchAnyRegex {
  param(
    [string]$Text,
    [string[]]$Patterns
  )
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  foreach ($p in @($Patterns)) {
    if ([string]::IsNullOrWhiteSpace([string]$p)) { continue }
    if ($Text -match $p) { return $true }
  }
  return $false
}

function Get-RecommendedBoundaryAction {
  param(
    [string]$ExpectedBoundaryClass,
    [string]$SourceLayer,
    [string]$TargetLayer,
    [bool]$HasViolation
  )
  if (-not $HasViolation) {
    return [pscustomobject]@{
      recommendation = "keep"
      recommended_boundary_class = $ExpectedBoundaryClass
      fallback_class = ""
      rationale = "current_mapping_matches_expected_boundary"
    }
  }

  $fallbackClass = if ($SourceLayer -eq "shared-template") { "shared-template" } else { "project" }
  $rationale = switch ($ExpectedBoundaryClass) {
    "global-user" { "only_repo_agnostic_user_home_entry_files_may_be_global_user" }
    "shared-template" { "shared_template_sources_should_stay_repo_root_distributions_not_user_home_files" }
    "project" { "repo_dependent_or_repo_root_installed_files_should_remain_project_level" }
    default { "ambiguous_boundary_should_fallback_to_project" }
  }

  return [pscustomobject]@{
    recommendation = "align_to_expected_boundary_class_and_target_layer"
    recommended_boundary_class = if ([string]::IsNullOrWhiteSpace($ExpectedBoundaryClass) -or $ExpectedBoundaryClass -eq "unknown") { $fallbackClass } else { $ExpectedBoundaryClass }
    fallback_class = $fallbackClass
    rationale = $rationale
  }
}

$items = New-Object System.Collections.Generic.List[object]
$violations = 0

foreach ($entry in $targets) {
  if ($null -eq $entry) { continue }
  $source = ([string]$entry.source -replace '\\', '/')
  $target = ([string]$entry.target -replace '\\', '/')
  $actualBoundaryClass = ""
  if ($null -ne $entry.PSObject.Properties["boundary_class"]) {
    $actualBoundaryClass = ([string]$entry.boundary_class).Trim().ToLowerInvariant()
  }

  $expectedBoundaryClass = Get-ExpectedBoundaryClass -Source $source
  $mappingCheck = Get-BoundaryMappingCheck -Source $source -Target $target -RepoRoots $repoRoots
  $reasonCodes = New-Object System.Collections.Generic.List[string]

  if ([string]::IsNullOrWhiteSpace($actualBoundaryClass)) {
    [void]$reasonCodes.Add("missing_boundary_class")
  } elseif (-not (Test-BoundaryClassValue -BoundaryClass $actualBoundaryClass)) {
    [void]$reasonCodes.Add("invalid_boundary_class")
  } elseif ($expectedBoundaryClass -ne "unknown" -and $actualBoundaryClass -ne $expectedBoundaryClass) {
    [void]$reasonCodes.Add("boundary_class_mismatch")
  }

  if (-not $mappingCheck.allowed) {
    [void]$reasonCodes.Add("cross_layer_mapping_violation")
  }

  if ($expectedBoundaryClass -eq "global-user") {
    if (-not (Test-MatchAnyRegex -Text $target -Patterns $globalTargetRegexes)) {
      [void]$reasonCodes.Add("global_target_not_whitelisted")
    }
  }

  $hasViolation = ($reasonCodes.Count -gt 0)
  if ($hasViolation) { $violations++ }
  $recommendedAction = Get-RecommendedBoundaryAction -ExpectedBoundaryClass $expectedBoundaryClass -SourceLayer ([string]$mappingCheck.source_layer) -TargetLayer ([string]$mappingCheck.target_layer) -HasViolation $hasViolation

  $items.Add([pscustomobject]@{
    source = $source
    target = $target
    expected_boundary_class = $expectedBoundaryClass
    actual_boundary_class = $actualBoundaryClass
    source_layer = [string]$mappingCheck.source_layer
    target_layer = [string]$mappingCheck.target_layer
    allowed = [bool](-not $hasViolation)
    reason_codes = @($reasonCodes)
    recommendation = [string]$recommendedAction.recommendation
    recommended_boundary_class = [string]$recommendedAction.recommended_boundary_class
    fallback_class = [string]$recommendedAction.fallback_class
    rationale = [string]$recommendedAction.rationale
    review_template_path = $reviewTemplatePath
  }) | Out-Null
}

$summary = [pscustomobject]@{
  policy_path = ($PolicyPath -replace '\\', '/')
  targets_path = ($TargetsPath -replace '\\', '/')
  review_template_path = $reviewTemplatePath
  total = $items.Count
  violations = [int]$violations
  pass = [int]($items.Count - $violations)
}

if ($AsJson) {
  $payload = [ordered]@{
    summary = $summary
    items = @($items.ToArray())
  }
  $payload | ConvertTo-Json -Depth 8 | Write-Output
} else {
  Write-Host "boundary-classification-check summary"
  Write-Host ("total={0} pass={1} violations={2} review_template={3}" -f $summary.total, $summary.pass, $summary.violations, $summary.review_template_path)
  foreach ($it in $items) {
    if (-not $ShowPassItems.IsPresent -and $it.allowed) { continue }
    $codes = if (@($it.reason_codes).Count -gt 0) { (@($it.reason_codes) -join ",") } else { "none" }
    $statusText = if ($it.allowed) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] source={1} target={2} expected={3} actual={4} source_layer={5} target_layer={6} reason_codes={7} recommended_boundary_class={8} fallback_class={9} rationale={10}" -f `
      $statusText,
      $it.source,
      $it.target,
      $it.expected_boundary_class,
      $it.actual_boundary_class,
      $it.source_layer,
      $it.target_layer,
      $codes,
      $it.recommended_boundary_class,
      $it.fallback_class,
      $it.rationale)
  }
}

if (-not $NoFailOnViolation.IsPresent -and $violations -gt 0) {
  exit 1
}
exit 0
