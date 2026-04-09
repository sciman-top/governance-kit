param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$OutputPath = "",
  [switch]$WriteFile,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)

$analysisScript = Join-Path $PSScriptRoot "analyze-repo-governance.ps1"
$analysisRaw = Invoke-ChildScriptCapture -ScriptPath $analysisScript -ScriptArgs @("-RepoPath", $repo, "-AsJson")
$analysis = $analysisRaw | ConvertFrom-Json

function Test-IsWpfProject {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Repo
  )

  $csprojs = @(Get-ChildItem -LiteralPath $Repo -Recurse -Filter "*.csproj" -File -ErrorAction SilentlyContinue)
  foreach ($proj in $csprojs) {
    try {
      $text = Get-Content -LiteralPath $proj.FullName -Raw -Encoding UTF8
      if ($text -match "<UseWPF>\s*true\s*</UseWPF>") {
        return $true
      }
    } catch {
      continue
    }
  }
  return $false
}

function Get-ProjectArchetype {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    [Parameter(Mandatory = $true)]
    [bool]$ReleaseEnabled
  )

  $hasSln = @(Get-ChildItem -LiteralPath $Repo -Filter "*.sln" -File -ErrorAction SilentlyContinue).Count -gt 0
  $hasPackageJson = Test-Path -LiteralPath (Join-Path $Repo "package.json")
  $hasBuildPs1 = Test-Path -LiteralPath (Join-Path $Repo "build.ps1")

  if ($hasSln -and (Test-IsWpfProject -Repo $Repo)) {
    return "dotnet-wpf"
  }
  if ($hasSln -and $ReleaseEnabled) {
    return "dotnet"
  }
  if ($hasPackageJson -and $ReleaseEnabled) {
    return "node-app"
  }
  if ($hasBuildPs1 -and -not $hasSln -and -not $hasPackageJson) {
    return "script"
  }
  if ($hasSln) {
    return "dotnet"
  }
  if ($hasPackageJson) {
    return "node"
  }
  return "generic"
}

function Normalize-GateCommand {
  param(
    [string]$CommandText
  )

  if ([string]::IsNullOrWhiteSpace($CommandText)) {
    return "N/A (manual command required)"
  }

  if ($CommandText -match "[^\x00-\x7F]") {
    return "N/A (manual command required)"
  }

  return $CommandText
}

function Get-ReleaseDistributionPolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$KitRoot
  )

  $path = Join-Path $KitRoot "config\release-distribution-policy.json"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    return $null
  }
  try {
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Get-ReleaseDistributionPolicyForRepo {
  param(
    [object]$Policy,
    [Parameter(Mandatory = $true)]
    [string]$RepoName
  )

  if ($null -eq $Policy) { return $null }
  if ($null -eq $Policy.PSObject.Properties['repos'] -or $null -eq $Policy.repos) { return $null }
  return @($Policy.repos | Where-Object { $_ -ne $null -and $_.PSObject.Properties['repoName'] -and ([string]$_.repoName).Equals($RepoName, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)[0]
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $repo ".governance\release-profile.json"
}

$workflowFiles = [System.Collections.Generic.List[string]]::new()
$releaseWorkflowDir = Join-Path $repo ".github\workflows"
if (Test-Path -LiteralPath $releaseWorkflowDir -PathType Container) {
  $releaseCandidates = Get-ChildItem -LiteralPath $releaseWorkflowDir -File -Filter "release*.yml" -ErrorAction SilentlyContinue
  foreach ($item in @($releaseCandidates)) {
    $rel = Get-RelativePathSafe -BasePath $repo -TargetPath $item.FullName
    [void]$workflowFiles.Add(($rel -replace '\\', '/'))
  }
}

$preflightCommand = if (Test-Path -LiteralPath (Join-Path $repo "scripts\release\preflight-check.ps1")) {
  "powershell -File scripts/release/preflight-check.ps1 -SkipTests"
} else {
  "N/A"
}
$prepareCommand = if (Test-Path -LiteralPath (Join-Path $repo "scripts\release\prepare-distribution.ps1")) {
  "powershell -File scripts/release/prepare-distribution.ps1 -Version <version> -PackageMode both"
} else {
  "N/A"
}
$hasReleaseChecklist = Test-Path -LiteralPath (Join-Path $repo "docs\runbooks\release-prevention-checklist.md")
$releaseEnabled = ($preflightCommand -ne "N/A") -or ($prepareCommand -ne "N/A") -or ($workflowFiles.Count -gt 0) -or $hasReleaseChecklist
$projectType = Get-ProjectArchetype -Repo $repo -ReleaseEnabled $releaseEnabled
$releaseDecision = if ($releaseEnabled) { "enabled-by-signals" } else { "disabled-no-release-signals" }
$releaseSignals = [System.Collections.Generic.List[string]]::new()
if ($preflightCommand -ne "N/A") { [void]$releaseSignals.Add("scripts/release/preflight-check.ps1") }
if ($prepareCommand -ne "N/A") { [void]$releaseSignals.Add("scripts/release/prepare-distribution.ps1") }
if ($hasReleaseChecklist) { [void]$releaseSignals.Add("docs/runbooks/release-prevention-checklist.md") }
foreach ($wf in @($workflowFiles)) { [void]$releaseSignals.Add([string]$wf) }

$minimumOs = [object[]]@("Windows 10 22H2", "Windows 11 22H2")
$architectures = [object[]]@("x64")
$channels = if ($releaseEnabled) { [object[]]@("standard", "offline") } else { [object[]]@("none") }
$defaultChannel = if ($releaseEnabled) { "standard" } else { "none" }
$distributionForms = if ($releaseEnabled) { [object[]]@("installer", "portable") } else { [object[]]@("portable") }
$networkModes = if ($releaseEnabled) { [object[]]@("online", "offline") } else { [object[]]@("online") }
$requireFrameworkDependent = [bool]$releaseEnabled
$requireSelfContained = [bool]$releaseEnabled
$signingRequired = $false
$signingMode = "none-personal"
$allowPaidSigning = $false
$disallowRuntimeDownloader = [bool]$releaseEnabled

if ($projectType -eq "script" -or $projectType -eq "generic" -or $projectType -eq "node") {
  $minimumOs = [object[]]@("Windows 10 22H2")
}
if ($projectType -eq "node-app" -or $projectType -eq "node") {
  $architectures = [object[]]@("x64", "arm64")
}
if ($projectType -eq "dotnet-wpf" -or $projectType -eq "dotnet") {
  $disallowRuntimeDownloader = $false
}

$kitRoot = Split-Path -Parent $PSScriptRoot
$distributionPolicy = Get-ReleaseDistributionPolicy -KitRoot $kitRoot
$repoName = Split-Path -Leaf $repo
$repoDistributionPolicy = Get-ReleaseDistributionPolicyForRepo -Policy $distributionPolicy -RepoName $repoName
$effectiveDistributionPolicy = if ($null -ne $repoDistributionPolicy) { $repoDistributionPolicy } elseif ($null -ne $distributionPolicy) { $distributionPolicy.default } else { $null }
if ($null -ne $effectiveDistributionPolicy) {
  if ($effectiveDistributionPolicy.PSObject.Properties['signing'] -and $null -ne $effectiveDistributionPolicy.signing) {
    $signing = $effectiveDistributionPolicy.signing
    if ($signing.PSObject.Properties['required']) { $signingRequired = [bool]$signing.required }
    if ($signing.PSObject.Properties['mode'] -and -not [string]::IsNullOrWhiteSpace([string]$signing.mode)) { $signingMode = [string]$signing.mode }
    if ($signing.PSObject.Properties['allow_paid_signing']) { $allowPaidSigning = [bool]$signing.allow_paid_signing }
  }
  if ($effectiveDistributionPolicy.PSObject.Properties['packaging'] -and $null -ne $effectiveDistributionPolicy.packaging) {
    $packagingPolicy = $effectiveDistributionPolicy.packaging
    if ($packagingPolicy.PSObject.Properties['default_channel'] -and -not [string]::IsNullOrWhiteSpace([string]$packagingPolicy.default_channel)) {
      $defaultChannel = [string]$packagingPolicy.default_channel
    }
    if ($packagingPolicy.PSObject.Properties['channels'] -and $packagingPolicy.channels -is [System.Array] -and @($packagingPolicy.channels).Count -gt 0) {
      $channels = [object[]]@($packagingPolicy.channels)
    }
    if ($packagingPolicy.PSObject.Properties['distribution_forms'] -and $packagingPolicy.distribution_forms -is [System.Array] -and @($packagingPolicy.distribution_forms).Count -gt 0) {
      $distributionForms = [object[]]@($packagingPolicy.distribution_forms)
    }
    if ($packagingPolicy.PSObject.Properties['network_modes'] -and $packagingPolicy.network_modes -is [System.Array] -and @($packagingPolicy.network_modes).Count -gt 0) {
      $networkModes = [object[]]@($packagingPolicy.network_modes)
    }
    if ($packagingPolicy.PSObject.Properties['require_framework_dependent']) {
      $requireFrameworkDependent = [bool]$packagingPolicy.require_framework_dependent
    }
    if ($packagingPolicy.PSObject.Properties['require_self_contained']) {
      $requireSelfContained = [bool]$packagingPolicy.require_self_contained
    }
  }
}

$profile = [ordered]@{
  schema_version = "1.0"
  project_type = $projectType
  release_enabled = [bool]$releaseEnabled
  owner = (Split-Path -Leaf $repo)
  classification = [ordered]@{
    release_decision = $releaseDecision
    detected_release_signals = [object[]]@($releaseSignals | Select-Object -Unique)
  }
  policies = [ordered]@{
    signing = [ordered]@{
      required = [bool]$signingRequired
      mode = $signingMode
      allow_paid_signing = [bool]$allowPaidSigning
    }
    compatibility = [ordered]@{
      matrix_required = [bool]$releaseEnabled
      minimum_os = $minimumOs
      architectures = $architectures
    }
    packaging = [ordered]@{
      default_channel = $defaultChannel
      channels = $channels
      distribution_forms = $distributionForms
      network_modes = $networkModes
      require_framework_dependent = [bool]$requireFrameworkDependent
      require_self_contained = [bool]$requireSelfContained
    }
    anti_false_positive = [ordered]@{
      prefer_zip = [bool]$releaseEnabled
      disallow_self_extracting_archive = [bool]$releaseEnabled
      disallow_obfuscation = [bool]$releaseEnabled
      disallow_runtime_downloader = [bool]$disallowRuntimeDownloader
    }
    traceability = [ordered]@{
      require_sha256 = [bool]$releaseEnabled
      require_release_manifest = [bool]$releaseEnabled
      require_changelog = [bool]$releaseEnabled
    }
  }
  gates = [ordered]@{
    build = Normalize-GateCommand -CommandText ([string]$analysis.recommended.build)
    test = Normalize-GateCommand -CommandText ([string]$analysis.recommended.test)
    contract_invariant = Normalize-GateCommand -CommandText ([string]$analysis.recommended.contract_invariant)
    hotspot = Normalize-GateCommand -CommandText ([string]$analysis.recommended.hotspot)
  }
  release = [ordered]@{
    preflight = $preflightCommand
    prepare = $prepareCommand
    workflow_files = @($workflowFiles)
    output_root = "artifacts/release"
    manifest = "artifacts/release/<version>/release-manifest.json"
  }
}

$profileJson = $profile | ConvertTo-Json -Depth 8

if ($WriteFile) {
  $outputDir = Split-Path -Parent $OutputPath
  if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
  }
  Set-Content -LiteralPath $OutputPath -Value $profileJson -Encoding UTF8
}

if ($AsJson) {
  $profileObj = $profileJson | ConvertFrom-Json
  [pscustomobject]@{
    repo = ($repo -replace '\\', '/')
    output = ($OutputPath -replace '\\', '/')
    wrote_file = [bool]$WriteFile
    profile = $profileObj
  } | ConvertTo-Json -Depth 10 | Write-Output
  exit 0
}

if ($WriteFile) {
  Write-Host "Generated release profile: $OutputPath"
} else {
  Write-Output $profileJson
}
