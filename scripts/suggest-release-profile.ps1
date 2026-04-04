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
$hasSln = @(Get-ChildItem -LiteralPath $repo -Filter "*.sln" -File -ErrorAction SilentlyContinue).Count -gt 0
$projectType = if ((Test-Path -LiteralPath (Join-Path $repo "src")) -and $hasSln) { "dotnet" } elseif (Test-Path -LiteralPath (Join-Path $repo "package.json")) { "node" } else { "generic" }

$profile = [ordered]@{
  schema_version = "1.0"
  project_type = $projectType
  release_enabled = [bool]$releaseEnabled
  owner = (Split-Path -Leaf $repo)
  policies = [ordered]@{
    signing = [ordered]@{
      required = $false
      mode = "none-personal"
    }
    compatibility = [ordered]@{
      matrix_required = [bool]$releaseEnabled
      minimum_os = @("Windows 10 22H2", "Windows 11 22H2")
      architectures = @("x64")
    }
    packaging = [ordered]@{
      default_channel = if ($releaseEnabled) { "standard" } else { "none" }
      channels = if ($releaseEnabled) { @("standard", "offline") } else { @("none") }
      require_framework_dependent = [bool]$releaseEnabled
      require_self_contained = [bool]$releaseEnabled
    }
    anti_false_positive = [ordered]@{
      prefer_zip = [bool]$releaseEnabled
      disallow_self_extracting_archive = [bool]$releaseEnabled
      disallow_obfuscation = [bool]$releaseEnabled
      disallow_runtime_downloader = [bool]$releaseEnabled
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
  [pscustomobject]@{
    repo = ($repo -replace '\\', '/')
    output = ($OutputPath -replace '\\', '/')
    wrote_file = [bool]$WriteFile
    profile = ($profile | ConvertFrom-Json -InputObject $profileJson)
  } | ConvertTo-Json -Depth 10 | Write-Output
  exit 0
}

if ($WriteFile) {
  Write-Host "Generated release profile: $OutputPath"
} else {
  Write-Output $profileJson
}
