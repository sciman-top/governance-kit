param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

function Get-ReleaseSignals {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Repo
  )

  $signals = [System.Collections.Generic.List[string]]::new()

  if (Test-Path -LiteralPath (Join-Path $Repo "scripts\release\prepare-distribution.ps1")) {
    [void]$signals.Add("scripts/release/prepare-distribution.ps1")
  }
  if (Test-Path -LiteralPath (Join-Path $Repo "scripts\release\preflight-check.ps1")) {
    [void]$signals.Add("scripts/release/preflight-check.ps1")
  }
  $workflowDir = Join-Path $Repo ".github\workflows"
  if (Test-Path -LiteralPath $workflowDir -PathType Container) {
    foreach ($wf in @(Get-ChildItem -LiteralPath $workflowDir -File -Filter "release*.yml" -ErrorAction SilentlyContinue)) {
      $rel = Get-RelativePathSafe -BasePath $Repo -TargetPath $wf.FullName
      [void]$signals.Add(($rel -replace '\\', '/'))
    }
  }
  if (Test-Path -LiteralPath (Join-Path $Repo "docs\runbooks\release-prevention-checklist.md")) {
    [void]$signals.Add("docs/runbooks/release-prevention-checklist.md")
  }

  return @($signals | Select-Object -Unique)
}

function Validate-ReleaseProfile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Profile
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  if ([string]::IsNullOrWhiteSpace([string]$Profile.schema_version)) {
    [void]$errors.Add("schema_version is required")
  }
  if ([string]$Profile.schema_version -ne "1.0") {
    [void]$errors.Add("schema_version must be 1.0")
  }
  if ($Profile.release_enabled -isnot [bool]) {
    [void]$errors.Add("release_enabled must be boolean")
  }
  if ($null -eq $Profile.policies) {
    [void]$errors.Add("policies section is required")
  } else {
    if ($null -eq $Profile.policies.signing) {
      [void]$errors.Add("policies.signing is required")
    } else {
      if ($Profile.policies.signing.required -isnot [bool]) {
        [void]$errors.Add("policies.signing.required must be boolean")
      } elseif ([bool]$Profile.policies.signing.required) {
        [void]$errors.Add("policies.signing.required must be false for personal zero-cost distribution")
      }
      if ([string]::IsNullOrWhiteSpace([string]$Profile.policies.signing.mode)) {
        [void]$errors.Add("policies.signing.mode is required")
      }
    }

    if ($null -eq $Profile.policies.compatibility) {
      [void]$errors.Add("policies.compatibility is required")
    } else {
      if ($Profile.policies.compatibility.matrix_required -isnot [bool]) {
        [void]$errors.Add("policies.compatibility.matrix_required must be boolean")
      }
      if ($null -eq $Profile.policies.compatibility.minimum_os -or @($Profile.policies.compatibility.minimum_os).Count -eq 0) {
        [void]$errors.Add("policies.compatibility.minimum_os must contain at least one entry")
      }
      if ($null -eq $Profile.policies.compatibility.architectures -or @($Profile.policies.compatibility.architectures).Count -eq 0) {
        [void]$errors.Add("policies.compatibility.architectures must contain at least one entry")
      }
    }

    if ($null -eq $Profile.policies.packaging) {
      [void]$errors.Add("policies.packaging is required")
    } else {
      if ([string]::IsNullOrWhiteSpace([string]$Profile.policies.packaging.default_channel)) {
        [void]$errors.Add("policies.packaging.default_channel is required")
      }
      if ($null -eq $Profile.policies.packaging.channels -or @($Profile.policies.packaging.channels).Count -eq 0) {
        [void]$errors.Add("policies.packaging.channels must contain at least one entry")
      }
      foreach ($k in @("require_framework_dependent", "require_self_contained")) {
        if ($Profile.policies.packaging.$k -isnot [bool]) {
          [void]$errors.Add("policies.packaging.$k must be boolean")
        }
      }
    }

    if ($null -eq $Profile.policies.anti_false_positive) {
      [void]$errors.Add("policies.anti_false_positive is required")
    } else {
      foreach ($k in @("prefer_zip", "disallow_self_extracting_archive", "disallow_obfuscation", "disallow_runtime_downloader")) {
        if ($Profile.policies.anti_false_positive.$k -isnot [bool]) {
          [void]$errors.Add("policies.anti_false_positive.$k must be boolean")
        }
      }
    }

    if ($null -eq $Profile.policies.traceability) {
      [void]$errors.Add("policies.traceability is required")
    } else {
      foreach ($k in @("require_sha256", "require_release_manifest", "require_changelog")) {
        if ($Profile.policies.traceability.$k -isnot [bool]) {
          [void]$errors.Add("policies.traceability.$k must be boolean")
        }
      }
    }
  }
  if ($null -eq $Profile.gates) {
    [void]$errors.Add("gates section is required")
  } else {
    foreach ($key in @("build", "test", "contract_invariant", "hotspot")) {
      if ([string]::IsNullOrWhiteSpace([string]$Profile.gates.$key)) {
        [void]$errors.Add("gates.$key is required")
      }
    }
  }
  if ($null -eq $Profile.release) {
    [void]$errors.Add("release section is required")
  } else {
    $enabled = [bool]$Profile.release_enabled
    foreach ($key in @("preflight", "prepare", "output_root", "manifest")) {
      if ([string]::IsNullOrWhiteSpace([string]$Profile.release.$key)) {
        if ($enabled -or $key -in @("output_root", "manifest")) {
          [void]$errors.Add("release.$key is required")
        }
      }
    }
    if ([bool]$Profile.release_enabled -and ($null -eq $Profile.release.workflow_files -or @($Profile.release.workflow_files).Count -eq 0)) {
      [void]$errors.Add("release.workflow_files must contain at least one entry")
    }
  }

  return @($errors)
}

function Validate-ReleaseProfileAgainstRepo {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Profile,
    [Parameter(Mandatory = $true)]
    [string]$Repo
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $prepareScriptPath = Join-Path $Repo "scripts\release\prepare-distribution.ps1"
  $prepareScriptText = if (Test-Path -LiteralPath $prepareScriptPath) { Get-Content -LiteralPath $prepareScriptPath -Raw -Encoding UTF8 } else { "" }
  $releaseChecklistPath = Join-Path $Repo "docs\runbooks\release-prevention-checklist.md"

  if ($Profile.policies.compatibility.matrix_required -eq $true -and -not (Test-Path -LiteralPath $releaseChecklistPath)) {
    [void]$errors.Add("compatibility matrix is required but docs/runbooks/release-prevention-checklist.md is missing")
  }

  if ($Profile.policies.packaging.require_framework_dependent -eq $true -and -not $prepareScriptText.Contains('--self-contained", "false')) {
    [void]$errors.Add("framework-dependent packaging is required but prepare script does not include --self-contained false")
  }
  if ($Profile.policies.packaging.require_self_contained -eq $true -and -not $prepareScriptText.Contains('--self-contained", "true')) {
    [void]$errors.Add("self-contained packaging is required but prepare script does not include --self-contained true")
  }

  if ($Profile.policies.anti_false_positive.prefer_zip -eq $true -and -not $prepareScriptText.Contains('[string]$ArchiveFormat = "zip"')) {
    [void]$errors.Add("prefer_zip=true but prepare script default archive format is not zip")
  }

  if ($Profile.policies.traceability.require_sha256 -eq $true -and -not $prepareScriptText.Contains("Write-Sha256Sums")) {
    [void]$errors.Add("require_sha256=true but prepare script does not generate SHA256 sums")
  }
  if ($Profile.policies.traceability.require_release_manifest -eq $true -and -not $prepareScriptText.Contains("release-manifest.json")) {
    [void]$errors.Add("require_release_manifest=true but prepare script does not generate release-manifest.json")
  }
  if ($Profile.policies.traceability.require_changelog -eq $true -and -not (Test-Path -LiteralPath $releaseChecklistPath)) {
    [void]$errors.Add("require_changelog=true but release-prevention checklist is missing")
  }

  return @($errors)
}

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
$repoName = Split-Path -Leaf $repo
$profilePath = Join-Path $repo ".governance\release-profile.json"

$signals = @(Get-ReleaseSignals -Repo $repo)
$hasSignals = $signals.Count -gt 0
$profileExists = Test-Path -LiteralPath $profilePath
$errors = [System.Collections.Generic.List[string]]::new()
$status = "PASS"

if ($hasSignals -and -not $profileExists) {
  $status = "FAIL"
  [void]$errors.Add("release-profile missing while release signals are detected")
}

if ($profileExists) {
  try {
    $profileRaw = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8
    $profile = $profileRaw | ConvertFrom-Json
  }
  catch {
    $status = "FAIL"
    [void]$errors.Add("release-profile is not valid JSON")
    $profile = $null
  }

  if ($null -ne $profile) {
    foreach ($err in @(Validate-ReleaseProfile -Profile $profile)) {
      $status = "FAIL"
      [void]$errors.Add($err)
    }
    if ($errors.Count -eq 0 -and [bool]$profile.release_enabled) {
      foreach ($err in @(Validate-ReleaseProfileAgainstRepo -Profile $profile -Repo $repo)) {
        $status = "FAIL"
        [void]$errors.Add($err)
      }
    }
  }
}

$result = [pscustomobject]@{
  repo = ($repo -replace '\\', '/')
  repo_name = $repoName
  profile_path = ($profilePath -replace '\\', '/')
  profile_exists = [bool]$profileExists
  release_signals = @($signals)
  status = $status
  errors = @($errors)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  if ($status -eq "PASS") { exit 0 } else { exit 1 }
}

if ($status -eq "PASS") {
  Write-Host "[PASS] release-profile repo=$repoName"
  exit 0
}

Write-Host "[FAIL] release-profile repo=$repoName"
foreach ($err in @($errors)) {
  Write-Host " - $err"
}
exit 1
