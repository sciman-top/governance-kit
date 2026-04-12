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
  if ($null -eq $Profile.classification) {
    [void]$errors.Add("classification section is required")
  } else {
    if ([string]::IsNullOrWhiteSpace([string]$Profile.classification.release_decision)) {
      [void]$errors.Add("classification.release_decision is required")
    }
    if ($null -eq $Profile.classification.detected_release_signals) {
      [void]$errors.Add("classification.detected_release_signals is required")
    }
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
      if ($Profile.policies.signing.allow_paid_signing -isnot [bool]) {
        [void]$errors.Add("policies.signing.allow_paid_signing must be boolean")
      } elseif ([bool]$Profile.policies.signing.allow_paid_signing) {
        [void]$errors.Add("policies.signing.allow_paid_signing must be false")
      }
      $signingMode = ([string]$Profile.policies.signing.mode).ToLowerInvariant()
      foreach ($token in @("paid", "ev", "ov", "codesign-certificate", "cloud-hsm")) {
        if ($signingMode.Contains($token)) {
          [void]$errors.Add("policies.signing.mode must not require paid signing service")
          break
        }
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
      if ($null -eq $Profile.policies.packaging.distribution_forms -or @($Profile.policies.packaging.distribution_forms).Count -eq 0) {
        [void]$errors.Add("policies.packaging.distribution_forms must contain at least one entry")
      }
      if ($null -eq $Profile.policies.packaging.network_modes -or @($Profile.policies.packaging.network_modes).Count -eq 0) {
        [void]$errors.Add("policies.packaging.network_modes must contain at least one entry")
      }
      foreach ($k in @("require_framework_dependent", "require_self_contained")) {
        if ($Profile.policies.packaging.$k -isnot [bool]) {
          [void]$errors.Add("policies.packaging.$k must be boolean")
        }
      }
      $allowedForms = @("installer", "portable")
      foreach ($f in @($Profile.policies.packaging.distribution_forms)) {
        if ($allowedForms -notcontains [string]$f) {
          [void]$errors.Add("policies.packaging.distribution_forms contains unsupported value: $f")
        }
      }
      $allowedNetworkModes = @("online", "offline")
      foreach ($m in @($Profile.policies.packaging.network_modes)) {
        if ($allowedNetworkModes -notcontains [string]$m) {
          [void]$errors.Add("policies.packaging.network_modes contains unsupported value: $m")
        }
      }
      if (@($Profile.policies.packaging.channels) -notcontains [string]$Profile.policies.packaging.default_channel) {
        [void]$errors.Add("policies.packaging.default_channel must be included in policies.packaging.channels")
      }
      if ([bool]$Profile.release_enabled) {
        if (@($Profile.policies.packaging.distribution_forms) -notcontains "installer" -or @($Profile.policies.packaging.distribution_forms) -notcontains "portable") {
          [void]$errors.Add("release-enabled profile must support both distribution_forms: installer + portable")
        }
        if (@($Profile.policies.packaging.network_modes) -notcontains "online" -or @($Profile.policies.packaging.network_modes) -notcontains "offline") {
          [void]$errors.Add("release-enabled profile must support both network_modes: online + offline")
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

function Validate-CompatibilityMatrixPresence {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Profile,
    [Parameter(Mandatory = $true)]
    [string]$Repo
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Profile.policies -or $null -eq $Profile.policies.compatibility) {
    return @($errors)
  }
  if (-not [bool]$Profile.policies.compatibility.matrix_required) {
    return @($errors)
  }

  $checklistPath = Join-Path $Repo "docs\runbooks\release-prevention-checklist.md"
  if (-not (Test-Path -LiteralPath $checklistPath)) {
    [void]$errors.Add("compatibility matrix is required but docs/runbooks/release-prevention-checklist.md is missing")
    return @($errors)
  }

  $text = Get-Content -LiteralPath $checklistPath -Raw -Encoding UTF8
  function Test-ChecklistContainsOsHint {
    param([string]$ChecklistText, [string]$OsText)
    if ([string]::IsNullOrWhiteSpace($OsText)) { return $true }
    if ($ChecklistText.Contains($OsText)) { return $true }

    $hint = $OsText
    if ($hint -match "^Windows\s+(\d+)") {
      $hint = "Windows $($Matches[1])"
      if ($ChecklistText.Contains(("Win" + $Matches[1]))) {
        return $true
      }
    }
    return $ChecklistText.Contains($hint)
  }

  foreach ($os in @($Profile.policies.compatibility.minimum_os)) {
    $osText = [string]$os
    if (-not (Test-ChecklistContainsOsHint -ChecklistText $text -OsText $osText)) {
      [void]$errors.Add("compatibility matrix checklist missing minimum_os entry: $osText")
    }
  }
  foreach ($arch in @($Profile.policies.compatibility.architectures)) {
    $archText = [string]$arch
    if (-not [string]::IsNullOrWhiteSpace($archText)) {
      $textLower = $text.ToLowerInvariant()
      $archLower = $archText.ToLowerInvariant()
      $archPresent = $textLower.Contains($archLower)
      if (-not $archPresent -and $archLower -eq "x64") {
        $archPresent = $textLower.Contains("win-x64")
      }
      if (-not $archPresent) {
        [void]$errors.Add("compatibility matrix checklist missing architectures entry: $archText")
      }
    }
  }
  return @($errors)
}

function Validate-AntiFalsePositiveStatic {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Profile,
    [Parameter(Mandatory = $true)]
    [string]$Repo
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Profile.policies -or $null -eq $Profile.policies.anti_false_positive) {
    return @($errors)
  }
  $anti = $Profile.policies.anti_false_positive
  $preparePath = Join-Path $Repo "scripts\release\prepare-distribution.ps1"
  $prepareText = if (Test-Path -LiteralPath $preparePath) { Get-Content -LiteralPath $preparePath -Raw -Encoding UTF8 } else { "" }

  if ([bool]$anti.disallow_self_extracting_archive) {
    foreach ($token in @("iexpress", "7z.sfx", "self-extract", "selfextract")) {
      if ($prepareText -match [regex]::Escape($token)) {
        [void]$errors.Add("anti_false_positive.disallow_self_extracting_archive=true but prepare script contains token: $token")
      }
    }
  }
  if ([bool]$anti.disallow_obfuscation) {
    foreach ($token in @("confuser", "obfuscat", "upx", "dotfuscator")) {
      if ($prepareText -match [regex]::Escape($token)) {
        [void]$errors.Add("anti_false_positive.disallow_obfuscation=true but prepare script contains token: $token")
      }
    }
  }
  if ([bool]$anti.disallow_runtime_downloader) {
    foreach ($token in @("Invoke-WebRequest", "Start-BitsTransfer", "bitsadmin", "curl.exe", "wget")) {
      if ($prepareText -match [regex]::Escape($token)) {
        [void]$errors.Add("anti_false_positive.disallow_runtime_downloader=true but prepare script contains token: $token")
      }
    }
  }

  return @($errors)
}

function Get-StandaloneReleasePolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$KitRoot
  )

  $path = Join-Path $KitRoot "config\standalone-release-policy.json"
  return Read-JsonFile -Path $path -DefaultValue $null -UseCache -DisplayName "standalone-release-policy.json"
}

function Get-StandaloneReleasePolicyForRepo {
  param(
    [object]$Policy,
    [string]$RepoName
  )

  if ($null -eq $Policy) {
    return $null
  }

  $defaultPolicy = if ($Policy.PSObject.Properties['default']) { $Policy.default } else { $null }
  $repoOverride = $null
  if ($Policy.PSObject.Properties['repos'] -and $Policy.repos -is [System.Array]) {
    foreach ($entry in @($Policy.repos)) {
      if ($null -eq $entry) { continue }
      if ([string]$entry.repoName -eq [string]$RepoName) {
        $repoOverride = $entry
        break
      }
    }
  }

  if ($null -eq $defaultPolicy -and $null -eq $repoOverride) {
    return $null
  }
  if ($null -eq $defaultPolicy) {
    return $repoOverride
  }
  if ($null -eq $repoOverride) {
    return $defaultPolicy
  }

  $merged = [ordered]@{}
  foreach ($p in $defaultPolicy.PSObject.Properties) {
    $merged[$p.Name] = $p.Value
  }
  foreach ($p in $repoOverride.PSObject.Properties) {
    if ($p.Name -eq "repoName") { continue }
    $merged[$p.Name] = $p.Value
  }
  return [pscustomobject]$merged
}

function Validate-StandaloneReleaseDependencies {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Profile,
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    [string]$RepoName,
    [object]$StandalonePolicy
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $warnings = [System.Collections.Generic.List[string]]::new()
  $hits = [System.Collections.Generic.List[object]]::new()

  if ($null -eq $StandalonePolicy) {
    return [pscustomobject]@{
      errors = @($errors)
      warnings = @($warnings)
      hits = @($hits)
    }
  }

  $scanPaths = @()
  if ($StandalonePolicy.PSObject.Properties['scan_paths'] -and $StandalonePolicy.scan_paths -is [System.Array]) {
    $scanPaths = @($StandalonePolicy.scan_paths | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  if ($scanPaths.Count -eq 0) {
    return [pscustomobject]@{
      errors = @($errors)
      warnings = @($warnings)
      hits = @($hits)
    }
  }

  $patterns = @()
  if ($StandalonePolicy.PSObject.Properties['forbidden_path_patterns_regex'] -and $StandalonePolicy.forbidden_path_patterns_regex -is [System.Array]) {
    $patterns = @($StandalonePolicy.forbidden_path_patterns_regex | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }
  if ($patterns.Count -eq 0) {
    return [pscustomobject]@{
      errors = @($errors)
      warnings = @($warnings)
      hits = @($hits)
    }
  }

  foreach ($rel in $scanPaths) {
    $path = Join-Path $Repo ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }

    $text = ""
    try {
      $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    } catch {
      continue
    }

    foreach ($pattern in $patterns) {
      $m = [regex]::Match($text, $pattern)
      if ($m.Success) {
        $preview = [string]$m.Value
        if ($preview.Length -gt 120) {
          $preview = $preview.Substring(0, 120)
        }
        [void]$hits.Add([pscustomobject]@{
          file = ($rel -replace '\\', '/')
          pattern = $pattern
          sample = $preview
        })
      }
    }
  }

  if ($hits.Count -eq 0) {
    return [pscustomobject]@{
      errors = @($errors)
      warnings = @($warnings)
      hits = @($hits)
    }
  }

  $repoLabel = if ([string]::IsNullOrWhiteSpace($RepoName)) { "unknown" } else { [string]$RepoName }
  $enforceOnRelease = $true
  if ($StandalonePolicy.PSObject.Properties['enforce_when_release_enabled']) {
    $enforceOnRelease = [bool]$StandalonePolicy.enforce_when_release_enabled
  }
  $advisoryWhenDisabled = $true
  if ($StandalonePolicy.PSObject.Properties['advisory_when_release_disabled']) {
    $advisoryWhenDisabled = [bool]$StandalonePolicy.advisory_when_release_disabled
  }

  if ([bool]$Profile.release_enabled -and $enforceOnRelease) {
    [void]$errors.Add("standalone release dependency violation: external absolute repo paths found (repo=$repoLabel, hits=$($hits.Count)); move dependency to optional collaboration contract or disable release_enabled")
  } elseif (-not [bool]$Profile.release_enabled -and $advisoryWhenDisabled) {
    [void]$warnings.Add("standalone release dependency advisory: external absolute repo paths found while release_enabled=false (repo=$repoLabel, hits=$($hits.Count))")
  }

  return [pscustomobject]@{
    errors = @($errors)
    warnings = @($warnings)
    hits = @($hits)
  }
}

function Validate-ReleaseProfileAgainstRepo {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Profile,
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    [object]$DistributionPolicy
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $prepareScriptPath = Join-Path $Repo "scripts\release\prepare-distribution.ps1"
  $prepareScriptText = if (Test-Path -LiteralPath $prepareScriptPath) { Get-Content -LiteralPath $prepareScriptPath -Raw -Encoding UTF8 } else { "" }
  $releaseChecklistPath = Join-Path $Repo "docs\runbooks\release-prevention-checklist.md"

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

  foreach ($err in @(Validate-CompatibilityMatrixPresence -Profile $Profile -Repo $Repo)) {
    [void]$errors.Add($err)
  }
  foreach ($err in @(Validate-AntiFalsePositiveStatic -Profile $Profile -Repo $Repo)) {
    [void]$errors.Add($err)
  }

  if ($null -ne $DistributionPolicy) {
    if ($DistributionPolicy.PSObject.Properties['signing'] -and $null -ne $DistributionPolicy.signing) {
      $s = $DistributionPolicy.signing
      if ($s.PSObject.Properties['required'] -and [bool]$Profile.policies.signing.required -ne [bool]$s.required) {
        [void]$errors.Add("release profile signing.required does not match release-distribution-policy")
      }
      if ($s.PSObject.Properties['allow_paid_signing'] -and [bool]$Profile.policies.signing.allow_paid_signing -ne [bool]$s.allow_paid_signing) {
        [void]$errors.Add("release profile signing.allow_paid_signing does not match release-distribution-policy")
      }
      if ($s.PSObject.Properties['mode'] -and -not [string]::IsNullOrWhiteSpace([string]$s.mode) -and [string]$Profile.policies.signing.mode -ne [string]$s.mode) {
        [void]$errors.Add("release profile signing.mode does not match release-distribution-policy")
      }
    }
    if ($DistributionPolicy.PSObject.Properties['packaging'] -and $null -ne $DistributionPolicy.packaging) {
      $p = $DistributionPolicy.packaging
      if ($p.PSObject.Properties['default_channel'] -and [string]$Profile.policies.packaging.default_channel -ne [string]$p.default_channel) {
        [void]$errors.Add("release profile packaging.default_channel does not match release-distribution-policy")
      }
      if ($p.PSObject.Properties['require_framework_dependent'] -and [bool]$Profile.policies.packaging.require_framework_dependent -ne [bool]$p.require_framework_dependent) {
        [void]$errors.Add("release profile packaging.require_framework_dependent does not match release-distribution-policy")
      }
      if ($p.PSObject.Properties['require_self_contained'] -and [bool]$Profile.policies.packaging.require_self_contained -ne [bool]$p.require_self_contained) {
        [void]$errors.Add("release profile packaging.require_self_contained does not match release-distribution-policy")
      }
      if ($p.PSObject.Properties['channels'] -and $p.channels -is [System.Array]) {
        $expectedChannels = @($p.channels | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $actualChannels = @($Profile.policies.packaging.channels | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        if (($expectedChannels -join "|") -ne ($actualChannels -join "|")) {
          [void]$errors.Add("release profile packaging.channels does not match release-distribution-policy")
        }
      }
      if ($p.PSObject.Properties['distribution_forms'] -and $p.distribution_forms -is [System.Array]) {
        $expectedForms = @($p.distribution_forms | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $actualForms = @($Profile.policies.packaging.distribution_forms | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        if (($expectedForms -join "|") -ne ($actualForms -join "|")) {
          [void]$errors.Add("release profile packaging.distribution_forms does not match release-distribution-policy")
        }
      }
      if ($p.PSObject.Properties['network_modes'] -and $p.network_modes -is [System.Array]) {
        $expectedModes = @($p.network_modes | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $actualModes = @($Profile.policies.packaging.network_modes | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        if (($expectedModes -join "|") -ne ($actualModes -join "|")) {
          [void]$errors.Add("release profile packaging.network_modes does not match release-distribution-policy")
        }
      }
    }
  }

  return @($errors)
}

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
$repoName = Split-Path -Leaf $repo
$kitRoot = Split-Path -Parent $PSScriptRoot
$distributionPolicy = Get-ReleaseDistributionPolicy -KitRoot $kitRoot
$repoDistributionPolicy = Get-ReleaseDistributionPolicyForRepo -Policy $distributionPolicy -RepoName $repoName -FallbackToDefault
$standalonePolicy = Get-StandaloneReleasePolicy -KitRoot $kitRoot
$repoStandalonePolicy = Get-StandaloneReleasePolicyForRepo -Policy $standalonePolicy -RepoName $repoName
$profilePath = Join-Path $repo ".governance\release-profile.json"

$signals = @(Get-ReleaseSignals -Repo $repo)
$hasSignals = $signals.Count -gt 0
$profileExists = Test-Path -LiteralPath $profilePath
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
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
    if ($errors.Count -eq 0) {
      $expectedDecision = if ($hasSignals) { "enabled-by-signals" } else { "disabled-no-release-signals" }
      if ([bool]$profile.release_enabled -ne [bool]$hasSignals) {
        $status = "FAIL"
        [void]$errors.Add("release_enabled must match repository release signals")
      }
      if ([string]$profile.classification.release_decision -ne $expectedDecision) {
        $status = "FAIL"
        [void]$errors.Add("classification.release_decision must be $expectedDecision")
      }
    }
    if ($errors.Count -eq 0 -and [bool]$profile.release_enabled) {
      foreach ($err in @(Validate-ReleaseProfileAgainstRepo -Profile $profile -Repo $repo -DistributionPolicy $repoDistributionPolicy)) {
        $status = "FAIL"
        [void]$errors.Add($err)
      }
    } elseif ($errors.Count -eq 0) {
      foreach ($err in @(Validate-ReleaseProfileAgainstRepo -Profile $profile -Repo $repo -DistributionPolicy $repoDistributionPolicy)) {
        $status = "FAIL"
        [void]$errors.Add($err)
      }
    }
    if ($errors.Count -eq 0) {
      $standaloneCheck = Validate-StandaloneReleaseDependencies -Profile $profile -Repo $repo -RepoName $repoName -StandalonePolicy $repoStandalonePolicy
      foreach ($err in @($standaloneCheck.errors)) {
        $status = "FAIL"
        [void]$errors.Add([string]$err)
      }
      foreach ($warn in @($standaloneCheck.warnings)) {
        [void]$warnings.Add([string]$warn)
      }
      $standaloneHits = @($standaloneCheck.hits)
    } else {
      $standaloneHits = @()
    }
  }
}
if ($null -eq $standaloneHits) {
  $standaloneHits = @()
}

$result = [pscustomobject]@{
  repo = ($repo -replace '\\', '/')
  repo_name = $repoName
  profile_path = ($profilePath -replace '\\', '/')
  profile_exists = [bool]$profileExists
  expected_release_enabled = [bool]$hasSignals
  release_signals = @($signals)
  status = $status
  errors = @($errors)
  warnings = @($warnings)
  standalone_dependency_hits = @($standaloneHits)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  if ($status -eq "PASS") { exit 0 } else { exit 1 }
}

if ($status -eq "PASS") {
  Write-Host "[PASS] release-profile repo=$repoName"
  foreach ($warn in @($warnings)) {
    Write-Host " - WARN: $warn"
  }
  exit 0
}

Write-Host "[FAIL] release-profile repo=$repoName"
foreach ($err in @($errors)) {
  Write-Host " - $err"
}
exit 1
