param(
  [switch]$FailOnViolation,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$commonPath = Join-Path $kitRoot "scripts\lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$projectRoot = Join-Path $kitRoot "source\project"
$customPolicyPath = Join-Path $kitRoot "config\project-custom-files.json"
$targetsPath = Join-Path $kitRoot "config\targets.json"
$distributionPolicyPath = Join-Path $kitRoot "config\custom-governance-distribution-policy.json"

if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
  throw "source/project not found: $projectRoot"
}
if (-not (Test-Path -LiteralPath $customPolicyPath -PathType Leaf)) {
  throw "project-custom-files.json not found: $customPolicyPath"
}
if (-not (Test-Path -LiteralPath $targetsPath -PathType Leaf)) {
  throw "targets.json not found: $targetsPath"
}

$customPolicy = Read-JsonFile -Path $customPolicyPath -DisplayName $customPolicyPath
$targets = @(Read-JsonArray $targetsPath)
$distributionPolicy = Read-JsonFile -Path $distributionPolicyPath -DefaultValue $null -DisplayName $distributionPolicyPath

function Add-NormalizedPathToSet {
  param(
    [Parameter(Mandatory = $true)]
    $Set,
    [AllowNull()]
    [object[]]$Items
  )
  if ($null -eq $Set) { return }
  foreach ($item in @($Items)) {
    $text = ([string]$item -replace '\\', '/').TrimStart('/')
    if (-not [string]::IsNullOrWhiteSpace($text)) {
      [void]$Set.Add($text)
    }
  }
}

$defaultFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($null -ne $customPolicy.default_layers) {
  foreach ($layerName in @("core", "default", "optional")) {
    $layerProp = $customPolicy.default_layers.PSObject.Properties[$layerName]
    if ($null -ne $layerProp) {
      Add-NormalizedPathToSet -Set $defaultFiles -Items @($layerProp.Value)
    }
  }
}
if ($defaultFiles.Count -eq 0 -and $null -ne $customPolicy.default) {
  Add-NormalizedPathToSet -Set $defaultFiles -Items @($customPolicy.default)
}

$repoPolicy = @{}
foreach ($repoEntry in @($customPolicy.repos)) {
  if ($null -eq $repoEntry) { continue }
  $repoName = [string]$repoEntry.repoName
  if ([string]::IsNullOrWhiteSpace($repoName)) { continue }
  if (-not $repoPolicy.ContainsKey($repoName)) {
    $repoPolicy[$repoName] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  }
  Add-NormalizedPathToSet -Set $repoPolicy[$repoName] -Items @($repoEntry.files)
}

$targetSourceSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($target in $targets) {
  if ($null -eq $target) { continue }
  $source = ([string]$target.source -replace '\\', '/').TrimStart('/')
  if (-not [string]::IsNullOrWhiteSpace($source)) {
    [void]$targetSourceSet.Add($source)
  }
}

$knownViolations = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$enforceNewOnly = $false
if ($null -ne $distributionPolicy) {
  if ($null -ne $distributionPolicy.PSObject.Properties['enforce_new_only']) {
    $enforceNewOnly = [bool]$distributionPolicy.enforce_new_only
  }
  foreach ($item in @($distributionPolicy.known_violations)) {
    $text = ([string]$item -replace '\\', '/').TrimStart('/')
    if (-not [string]::IsNullOrWhiteSpace($text)) {
      [void]$knownViolations.Add($text)
    }
  }
}

$violations = [System.Collections.Generic.List[object]]::new()
$actionableViolations = [System.Collections.Generic.List[object]]::new()
$scanned = 0
$repoDirs = @(Get-ChildItem -LiteralPath $projectRoot -Directory -ErrorAction SilentlyContinue)
foreach ($repoDir in $repoDirs) {
  $repoName = [string]$repoDir.Name
  $governanceDir = Join-Path $repoDir.FullName "custom\scripts\governance"
  if (-not (Test-Path -LiteralPath $governanceDir -PathType Container)) { continue }

  $files = @(Get-ChildItem -LiteralPath $governanceDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue)
  foreach ($file in $files) {
    $scanned++
    $relativeWithinCustom = "scripts/governance/" + $file.Name
    $sourceRel = ("source/project/{0}/custom/{1}" -f $repoName, $relativeWithinCustom) -replace '\\', '/'

    $inPolicy = $false
    if ($defaultFiles.Contains($relativeWithinCustom)) {
      $inPolicy = $true
    } elseif ($repoPolicy.ContainsKey($repoName) -and $repoPolicy[$repoName].Contains($relativeWithinCustom)) {
      $inPolicy = $true
    } elseif ($repoName.Equals("_common", [System.StringComparison]::OrdinalIgnoreCase)) {
      foreach ($kv in $repoPolicy.GetEnumerator()) {
        if ($kv.Value.Contains($relativeWithinCustom)) {
          $inPolicy = $true
          break
        }
      }
    }

    $inTargets = $targetSourceSet.Contains($sourceRel)

    if (-not $inPolicy -or -not $inTargets) {
      $reasons = [System.Collections.Generic.List[string]]::new()
      if (-not $inPolicy) { [void]$reasons.Add("missing_project_custom_files_mapping") }
      if (-not $inTargets) { [void]$reasons.Add("missing_targets_mapping") }
      $violation = [pscustomobject]@{
        repo = $repoName
        source = $sourceRel
        relative_custom_path = $relativeWithinCustom
        known_violation = $knownViolations.Contains($sourceRel)
        reasons = @($reasons)
      }
      $violations.Add($violation) | Out-Null
      if (-not ($enforceNewOnly -and $violation.known_violation)) {
        $actionableViolations.Add($violation) | Out-Null
      }
    }
  }
}

$summary = [pscustomobject]@{
  status = if ($actionableViolations.Count -eq 0) { "PASS" } else { "FAIL" }
  scanned = $scanned
  violation_count = $violations.Count
  actionable_violation_count = $actionableViolations.Count
  enforce_new_only = $enforceNewOnly
  violations = @($violations)
}

if ($AsJson) {
  $summary | ConvertTo-Json -Depth 8 | Write-Output
} else {
  foreach ($v in @($violations)) {
    $tag = if ($v.known_violation -and $enforceNewOnly) { "VIOLATION_BASELINE" } else { "VIOLATION" }
    Write-Host ("[{0}] repo={1} source={2} reasons={3}" -f $tag, $v.repo, $v.source, (@($v.reasons) -join ","))
  }
  Write-Host ("custom_governance_distribution.status={0}" -f $summary.status)
  Write-Host ("custom_governance_distribution.scanned={0}" -f $summary.scanned)
  Write-Host ("custom_governance_distribution.violation_count={0}" -f $summary.violation_count)
  Write-Host ("custom_governance_distribution.actionable_violation_count={0}" -f $summary.actionable_violation_count)
}

if ($FailOnViolation -and $actionableViolations.Count -gt 0) {
  exit 1
}
