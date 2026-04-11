$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$reposPath = Join-Path $kitRoot "config\repositories.json"
$targetsPath = Join-Path $kitRoot "config\targets.json"
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$projectRulePolicyPath = Get-ProjectRulePolicyPath $kitRoot
$projectCustomPath = Join-Path $kitRoot "config\project-custom-files.json"
$oneclickDistributionPolicyPath = Join-Path $kitRoot "config\oneclick-distribution-policy.json"
$releaseDistributionPolicyPath = Join-Path $kitRoot "config\release-distribution-policy.json"
$practiceStackPolicyPath = Join-Path $kitRoot "config\practice-stack-policy.json"
$clarificationPolicyPath = Join-Path $kitRoot "config\clarification-policy.json"
$codexProfileRegistryPath = Join-Path $kitRoot "config\codex-profile-registry.json"
$codexRuntimePolicyPath = Join-Path $kitRoot "config\codex-runtime-policy.json"
$growthPackPolicyPath = Join-Path $kitRoot "config\growth-pack-policy.json"

if (!(Test-Path $reposPath)) { throw "repositories.json not found: $reposPath" }
if (!(Test-Path $targetsPath)) { throw "targets.json not found: $targetsPath" }
if (!(Test-Path $rolloutPath)) { throw "rule-rollout.json not found: $rolloutPath" }
if (!(Test-Path $projectRulePolicyPath)) { throw "project-rule-policy.json not found: $projectRulePolicyPath" }
if (!(Test-Path $projectCustomPath)) { throw "project-custom-files.json not found: $projectCustomPath" }
if (!(Test-Path $releaseDistributionPolicyPath)) { throw "release-distribution-policy.json not found: $releaseDistributionPolicyPath" }
if (!(Test-Path $practiceStackPolicyPath)) { throw "practice-stack-policy.json not found: $practiceStackPolicyPath" }

$fail = 0

function Read-RequiredJsonConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$InvalidMessage
  )

  try {
    return Read-JsonFile -Path $Path -DisplayName $Path
  } catch {
    throw $InvalidMessage
  }
}

function Read-OptionalJsonConfig {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$InvalidNotice
  )

  try {
    return Read-JsonFile -Path $Path -DisplayName $Path
  } catch {
    Write-Host $InvalidNotice
    $script:fail++
    return $null
  }
}

function Validate-IntInRange {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][int]$Min,
    [Parameter(Mandatory = $true)][int]$Max,
    [Parameter(Mandatory = $true)][string]$IntegerMessage,
    [Parameter(Mandatory = $true)][string]$RangeMessage
  )

  if ($Value -isnot [int] -and $Value -isnot [long]) {
    Write-Host $IntegerMessage
    $script:fail++
    return $null
  }

  $normalized = [int]$Value
  if ($normalized -lt $Min -or $normalized -gt $Max) {
    Write-Host $RangeMessage
    $script:fail++
    return $null
  }

  return $normalized
}

function Validate-BooleanValue {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if ($Value -isnot [bool]) {
    Write-Host $Message
    $script:fail++
    return $false
  }

  return $true
}

function Validate-RequiredBooleanProperty {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [Parameter(Mandatory = $true)][string]$PropertyName,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if ($null -eq $Object.PSObject.Properties[$PropertyName]) {
    Write-Host $Message
    $script:fail++
    return $false
  }

  return (Validate-BooleanValue -Value $Object.$PropertyName -Message $Message)
}

function Validate-OptionalBooleanProperty {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [Parameter(Mandatory = $true)][string]$PropertyName,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if ($null -eq $Object.PSObject.Properties[$PropertyName]) {
    return $true
  }

  return (Validate-BooleanValue -Value $Object.$PropertyName -Message $Message)
}

function Validate-RequiredNonEmptyStringProperty {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [Parameter(Mandatory = $true)][string]$PropertyName,
    [Parameter(Mandatory = $true)][string]$MissingMessage
  )

  if ($null -eq $Object.PSObject.Properties[$PropertyName] -or [string]::IsNullOrWhiteSpace([string]$Object.$PropertyName)) {
    Write-Host $MissingMessage
    $script:fail++
    return $null
  }

  return [string]$Object.$PropertyName
}

function Validate-TokenBudgetModeValue {
  param(
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][string]$MessagePrefix
  )

  $allowed = @("lite", "standard", "deep")
  if ($allowed -notcontains $Value) {
    Write-Host ("{0} invalid: expected one of lite/standard/deep" -f $MessagePrefix)
    $script:fail++
    return $false
  }

  return $true
}

try {
  $repos = Read-JsonArray $reposPath
} catch {
  throw "repositories.json invalid JSON: $reposPath"
}

try {
  $targets = Read-JsonArray $targetsPath
} catch {
  throw "targets.json invalid JSON: $targetsPath"
}

$rollout = Read-RequiredJsonConfig -Path $rolloutPath -InvalidMessage "rule-rollout.json invalid JSON: $rolloutPath"
$projectRulePolicy = Read-RequiredJsonConfig -Path $projectRulePolicyPath -InvalidMessage "project-rule-policy.json invalid JSON: $projectRulePolicyPath"
$projectCustom = Read-RequiredJsonConfig -Path $projectCustomPath -InvalidMessage "project-custom-files.json invalid JSON: $projectCustomPath"
$oneclickDistributionPolicy = Read-OptionalJsonConfig -Path $oneclickDistributionPolicyPath -InvalidNotice "[CFG] oneclick-distribution-policy.json invalid JSON: $oneclickDistributionPolicyPath"
$releaseDistributionPolicy = Read-RequiredJsonConfig -Path $releaseDistributionPolicyPath -InvalidMessage "release-distribution-policy.json invalid JSON: $releaseDistributionPolicyPath"
$practiceStackPolicy = Read-RequiredJsonConfig -Path $practiceStackPolicyPath -InvalidMessage "practice-stack-policy.json invalid JSON: $practiceStackPolicyPath"
$growthPackPolicy = Read-OptionalJsonConfig -Path $growthPackPolicyPath -InvalidNotice "[CFG] growth-pack-policy.json invalid JSON: $growthPackPolicyPath"
if ($null -eq $growthPackPolicy) {
  $growthPackPolicy = [pscustomobject]@{
    schema_version = "compat-default"
    enabled = $false
    readme_quickstart_mode = "advisory"
    root_apply_enabled_by_default = $false
    default_tier = "starter"
    tiers = [pscustomobject]@{
      starter = @()
      advanced = @()
      integration = @()
    }
    repo_overrides = @()
  }
}

if (Test-Path $clarificationPolicyPath) {
  $clarificationPolicy = Read-RequiredJsonConfig -Path $clarificationPolicyPath -InvalidMessage "clarification-policy.json invalid JSON: $clarificationPolicyPath"
} else {
  Write-Host "[CFG] clarification-policy.json not found, using compatibility defaults"
  $clarificationPolicy = [pscustomobject]@{
    enabled = $true
    max_clarifying_questions = 3
    trigger_attempt_threshold = 2
    trigger_on_conflict_signal = $true
    auto_resume_after_clarification = $true
    default_scenario = "bugfix"
    scenarios = [pscustomobject]@{
      plan = [pscustomobject]@{
        goal = "align plan"
        question_prompts = @("q1", "q2", "q3")
      }
      requirement = [pscustomobject]@{
        goal = "align requirement"
        question_prompts = @("q1", "q2", "q3")
      }
      bugfix = [pscustomobject]@{
        goal = "align bugfix"
        question_prompts = @("q1", "q2", "q3")
      }
      acceptance = [pscustomobject]@{
        goal = "align acceptance"
        question_prompts = @("q1", "q2", "q3")
      }
    }
  }
}

if ($null -ne $projectRulePolicy.defaults) {
  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_auto_fix']) {
    # backward-compatible: missing field uses runtime default
  } else {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.allow_auto_fix -Message "[CFG] project-rule-policy.defaults.allow_auto_fix must be boolean")
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_rule_optimization']) {
    # backward-compatible: missing field uses runtime default
  } else {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.allow_rule_optimization -Message "[CFG] project-rule-policy.defaults.allow_rule_optimization must be boolean")
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_local_optimize_without_backflow']) {
    # backward-compatible: missing field uses runtime default
  } else {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.allow_local_optimize_without_backflow -Message "[CFG] project-rule-policy.defaults.allow_local_optimize_without_backflow must be boolean")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['max_autonomous_iterations']) {
    if ($projectRulePolicy.defaults.max_autonomous_iterations -isnot [int] -and $projectRulePolicy.defaults.max_autonomous_iterations -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.defaults.max_autonomous_iterations must be integer"
      $fail++
    } elseif ([int]$projectRulePolicy.defaults.max_autonomous_iterations -lt 1 -or [int]$projectRulePolicy.defaults.max_autonomous_iterations -gt 100) {
      Write-Host "[CFG] project-rule-policy.defaults.max_autonomous_iterations out of range: expected 1..100"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['max_repeated_failure_per_step']) {
    if ($projectRulePolicy.defaults.max_repeated_failure_per_step -isnot [int] -and $projectRulePolicy.defaults.max_repeated_failure_per_step -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.defaults.max_repeated_failure_per_step must be integer"
      $fail++
    } elseif ([int]$projectRulePolicy.defaults.max_repeated_failure_per_step -lt 1 -or [int]$projectRulePolicy.defaults.max_repeated_failure_per_step -gt 20) {
      Write-Host "[CFG] project-rule-policy.defaults.max_repeated_failure_per_step out of range: expected 1..20"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['enable_no_progress_guard']) {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.enable_no_progress_guard -Message "[CFG] project-rule-policy.defaults.enable_no_progress_guard must be boolean")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['max_no_progress_iterations']) {
    [void](Validate-IntInRange `
      -Value $projectRulePolicy.defaults.max_no_progress_iterations `
      -Min 1 `
      -Max 20 `
      -IntegerMessage "[CFG] project-rule-policy.defaults.max_no_progress_iterations must be integer" `
      -RangeMessage "[CFG] project-rule-policy.defaults.max_no_progress_iterations out of range: expected 1..20")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['token_budget_mode']) {
    [void](Validate-TokenBudgetModeValue -Value ([string]$projectRulePolicy.defaults.token_budget_mode) -MessagePrefix "[CFG] project-rule-policy.defaults.token_budget_mode")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['stop_on_irreversible_risk']) {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.stop_on_irreversible_risk -Message "[CFG] project-rule-policy.defaults.stop_on_irreversible_risk must be boolean")
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['forbid_breaking_contract']) {
    # backward-compatible: missing field uses runtime default
  } else {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.forbid_breaking_contract -Message "[CFG] project-rule-policy.defaults.forbid_breaking_contract must be boolean")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['auto_commit_enabled']) {
    [void](Validate-BooleanValue -Value $projectRulePolicy.defaults.auto_commit_enabled -Message "[CFG] project-rule-policy.defaults.auto_commit_enabled must be boolean")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['auto_commit_on_checkpoints']) {
    if ($projectRulePolicy.defaults.auto_commit_on_checkpoints -isnot [System.Array]) {
      Write-Host "[CFG] project-rule-policy.defaults.auto_commit_on_checkpoints must be array"
      $fail++
    } else {
      foreach ($cp in @($projectRulePolicy.defaults.auto_commit_on_checkpoints)) {
        if ([string]::IsNullOrWhiteSpace([string]$cp)) {
          Write-Host "[CFG] project-rule-policy.defaults.auto_commit_on_checkpoints contains empty value"
          $fail++
          break
        }
      }
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['auto_commit_message_prefix']) {
    if ([string]::IsNullOrWhiteSpace([string]$projectRulePolicy.defaults.auto_commit_message_prefix)) {
      Write-Host "[CFG] project-rule-policy.defaults.auto_commit_message_prefix must be non-empty string"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['clarification_mode_default']) {
    $modeDefault = [string]$projectRulePolicy.defaults.clarification_mode_default
    if ($modeDefault -ne "direct_fix") {
      Write-Host "[CFG] project-rule-policy.defaults.clarification_mode_default must be 'direct_fix'"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['clarification_scenario_default']) {
    $scenarioDefault = [string]$projectRulePolicy.defaults.clarification_scenario_default
    $validScenarios = @("plan", "requirement", "bugfix", "acceptance")
    if ($validScenarios -notcontains $scenarioDefault) {
      Write-Host "[CFG] project-rule-policy.defaults.clarification_scenario_default invalid: expected one of plan/requirement/bugfix/acceptance"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['clarification_trigger_attempt_threshold']) {
    [void](Validate-IntInRange `
      -Value $projectRulePolicy.defaults.clarification_trigger_attempt_threshold `
      -Min 1 `
      -Max 10 `
      -IntegerMessage "[CFG] project-rule-policy.defaults.clarification_trigger_attempt_threshold must be integer" `
      -RangeMessage "[CFG] project-rule-policy.defaults.clarification_trigger_attempt_threshold out of range: expected 1..10")
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['clarification_max_questions']) {
    [void](Validate-IntInRange `
      -Value $projectRulePolicy.defaults.clarification_max_questions `
      -Min 1 `
      -Max 3 `
      -IntegerMessage "[CFG] project-rule-policy.defaults.clarification_max_questions must be integer" `
      -RangeMessage "[CFG] project-rule-policy.defaults.clarification_max_questions out of range: expected 1..3")
  }
}

$seenRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($r in $repos) {
  $repo = Normalize-Repo ([string]$r)
  if (-not $seenRepo.Add($repo)) {
    Write-Host "[CFG] duplicate repository: $repo"
    $fail++
  }
}

$customRepos = if ($null -eq $projectCustom.repos) { @() } else { @($projectCustom.repos) }
$allowedCustomLayers = @("core", "default", "optional")
function Validate-CustomLayerList {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string]$MessagePrefix
  )

  if ($Value -isnot [System.Array]) {
    Write-Host ("{0} must be array" -f $MessagePrefix)
    $script:fail++
    return @()
  }

  $layers = [System.Collections.Generic.List[string]]::new()
  foreach ($layer in @($Value)) {
    $name = ([string]$layer).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($name)) {
      Write-Host ("{0} contains empty layer name" -f $MessagePrefix)
      $script:fail++
      continue
    }
    if ($allowedCustomLayers -notcontains $name) {
      Write-Host ("{0} contains invalid layer '{1}' (expected core/default/optional)" -f $MessagePrefix, $name)
      $script:fail++
      continue
    }
    if (-not $layers.Contains($name)) {
      [void]$layers.Add($name)
    }
  }

  return @($layers.ToArray())
}

if ($null -ne $projectCustom.default_layers) {
  foreach ($layerName in $allowedCustomLayers) {
    $prop = $projectCustom.default_layers.PSObject.Properties[$layerName]
    if ($null -eq $prop) { continue }
    if ($prop.Value -isnot [System.Array]) {
      Write-Host ("[CFG] project-custom.default_layers.{0} must be array" -f $layerName)
      $fail++
    }
  }
}

if ($null -ne $oneclickDistributionPolicy -and $null -ne $oneclickDistributionPolicy.project_custom_files) {
  $pcfPolicy = $oneclickDistributionPolicy.project_custom_files
  if ($null -ne $pcfPolicy.PSObject.Properties['active_layers']) {
    [void](Validate-CustomLayerList -Value $pcfPolicy.active_layers -MessagePrefix "[CFG] oneclick-distribution-policy.project_custom_files.active_layers")
  }
  foreach ($entry in @($pcfPolicy.repos)) {
    if ($null -eq $entry) {
      Write-Host "[CFG] oneclick-distribution-policy.project_custom_files.repos entry is null"
      $fail++
      continue
    }
    if ($null -eq $entry.PSObject.Properties['active_layers']) { continue }
    [void](Validate-CustomLayerList -Value $entry.active_layers -MessagePrefix "[CFG] oneclick-distribution-policy.project_custom_files.repos.active_layers")
  }
}

$seenCustomRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $customRepos) {
  if ($null -eq $entry) {
    Write-Host "[CFG] project-custom entry is null"
    $fail++
    continue
  }

  $entryRepoName = [string]$entry.repoName
  if ([string]::IsNullOrWhiteSpace($entryRepoName)) {
    Write-Host "[CFG] project-custom entry missing repoName"
    $fail++
    continue
  }

  if (-not $seenCustomRepo.Add($entryRepoName)) {
    Write-Host "[CFG] duplicate project-custom repoName: $entryRepoName"
    $fail++
  }

  $customRepoMatched = $false
  foreach ($repoNorm in $seenRepo) {
    if ((Split-Path -Leaf $repoNorm).Equals($entryRepoName, [System.StringComparison]::OrdinalIgnoreCase)) {
      $customRepoMatched = $true
      break
    }
  }
  if (-not $customRepoMatched) {
    Write-Host "[CFG] project-custom repoName not in repositories.json: $entryRepoName"
    $fail++
  }
}

foreach ($repoNorm in $seenRepo) {
  $repoLeaf = Split-Path -Leaf $repoNorm
  if (-not $seenCustomRepo.Contains($repoLeaf)) {
    Write-Host "[CFG] project-custom missing repo entry: $repoLeaf"
    $fail++
  }
}

$registeredDefaultCustomFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if ($null -ne $projectCustom.default_layers) {
  foreach ($layerName in $allowedCustomLayers) {
    $prop = $projectCustom.default_layers.PSObject.Properties[$layerName]
    if ($null -eq $prop -or $prop.Value -isnot [System.Array]) { continue }
    foreach ($f in @($prop.Value)) {
      $fText = (([string]$f) -replace '\\', '/').TrimStart('/')
      if (-not [string]::IsNullOrWhiteSpace($fText)) {
        [void]$registeredDefaultCustomFiles.Add($fText)
      }
    }
  }
}
if ($null -eq $projectCustom.default_layers -and $null -ne $projectCustom.default) {
  foreach ($f in @($projectCustom.default)) {
    $fText = (([string]$f) -replace '\\', '/').TrimStart('/')
    if (-not [string]::IsNullOrWhiteSpace($fText)) { [void]$registeredDefaultCustomFiles.Add($fText) }
  }
}

$registeredRepoCustomFiles = @{}
foreach ($entry in $customRepos) {
  if ($null -eq $entry) { continue }
  $entryRepoName = [string]$entry.repoName
  if ([string]::IsNullOrWhiteSpace($entryRepoName)) { continue }

  if (-not $registeredRepoCustomFiles.ContainsKey($entryRepoName)) {
    $registeredRepoCustomFiles[$entryRepoName] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  }
  foreach ($f in @($entry.files)) {
    $fText = (([string]$f) -replace '\\', '/').TrimStart('/')
    if (-not [string]::IsNullOrWhiteSpace($fText)) {
      [void]$registeredRepoCustomFiles[$entryRepoName].Add($fText)
    }
  }
}

$projectSourceRoot = Join-Path $kitRoot "source\project"
if (Test-Path -LiteralPath $projectSourceRoot -PathType Container) {
  $skillSourceFiles = @(
    Get-ChildItem -Path $projectSourceRoot -Recurse -File -Filter "SKILL.md" -ErrorAction SilentlyContinue |
    Where-Object {
      $rel = ($_.FullName.Substring($projectSourceRoot.Length).TrimStart('\') -replace '\\', '/')
      $rel -match "^[^/]+/custom/(\.agents/skills/|plugins/[^/]+/skills/)"
    }
  )

  foreach ($skillFile in $skillSourceFiles) {
    $rel = ($skillFile.FullName.Substring($projectSourceRoot.Length).TrimStart('\') -replace '\\', '/')
    if ($rel -notmatch "^([^/]+)/custom/(.+)$") { continue }

    $scopeRepo = [string]$matches[1]
    $customRel = [string]$matches[2]
    $registered = $false

    if ($scopeRepo.Equals("_common", [System.StringComparison]::OrdinalIgnoreCase)) {
      $registered = $registeredDefaultCustomFiles.Contains($customRel)
    } else {
      if ($registeredRepoCustomFiles.ContainsKey($scopeRepo)) {
        $registered = $registeredRepoCustomFiles[$scopeRepo].Contains($customRel)
      } else {
        $registered = $false
      }
    }

    if (-not $registered) {
      Write-Host ("[CFG] unregistered skill custom file: {0}/{1}" -f $scopeRepo, $customRel)
      $fail++
    }
  }
}

$allowProjectRuleRepos = if ($null -eq $projectRulePolicy.allowProjectRulesForRepos) { @() } else { @($projectRulePolicy.allowProjectRulesForRepos) }
$seenProjectAllowRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ar in $allowProjectRuleRepos) {
  $arText = [string]$ar
  if ([string]::IsNullOrWhiteSpace($arText)) {
    Write-Host "[CFG] project-rule allow repo is empty"
    $fail++
    continue
  }

  $arWin = ($arText -replace '/', '\')
  if (-not [System.IO.Path]::IsPathRooted($arWin)) {
    Write-Host "[CFG] project-rule allow repo must be absolute: $arText"
    $fail++
    continue
  }

  $arNorm = Normalize-Repo $arText
  if (-not $seenProjectAllowRepo.Add($arNorm)) {
    Write-Host "[CFG] duplicate project-rule allow repo: $arNorm"
    $fail++
  }

  if (-not $seenRepo.Contains($arNorm)) {
    Write-Host "[CFG] project-rule allow repo not in repositories.json: $arNorm"
    $fail++
  }
}

$policyRepos = if ($null -eq $projectRulePolicy.repos) { @() } else { @($projectRulePolicy.repos) }
foreach ($pr in $policyRepos) {
  if ($null -eq $pr) {
    Write-Host "[CFG] project-rule-policy.repos entry is null"
    $fail++
    continue
  }

  $hasRepoKey = $pr.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$pr.repo)
  $hasRepoNameKey = $pr.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$pr.repoName)
  if (-not $hasRepoKey -and -not $hasRepoNameKey) {
    Write-Host "[CFG] project-rule-policy.repos entry must contain repo or repoName"
    $fail++
  }

  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "allow_auto_fix" -Message "[CFG] project-rule-policy.repos.allow_auto_fix must be boolean")
  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "allow_rule_optimization" -Message "[CFG] project-rule-policy.repos.allow_rule_optimization must be boolean")
  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "allow_local_optimize_without_backflow" -Message "[CFG] project-rule-policy.repos.allow_local_optimize_without_backflow must be boolean")
  if ($pr.PSObject.Properties['max_autonomous_iterations']) {
    if ($pr.max_autonomous_iterations -isnot [int] -and $pr.max_autonomous_iterations -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.repos.max_autonomous_iterations must be integer"
      $fail++
    } elseif ([int]$pr.max_autonomous_iterations -lt 1 -or [int]$pr.max_autonomous_iterations -gt 100) {
      Write-Host "[CFG] project-rule-policy.repos.max_autonomous_iterations out of range: expected 1..100"
      $fail++
    }
  }
  if ($pr.PSObject.Properties['max_repeated_failure_per_step']) {
    if ($pr.max_repeated_failure_per_step -isnot [int] -and $pr.max_repeated_failure_per_step -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.repos.max_repeated_failure_per_step must be integer"
      $fail++
    } elseif ([int]$pr.max_repeated_failure_per_step -lt 1 -or [int]$pr.max_repeated_failure_per_step -gt 20) {
      Write-Host "[CFG] project-rule-policy.repos.max_repeated_failure_per_step out of range: expected 1..20"
      $fail++
    }
  }
  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "enable_no_progress_guard" -Message "[CFG] project-rule-policy.repos.enable_no_progress_guard must be boolean")
  if ($pr.PSObject.Properties['max_no_progress_iterations']) {
    [void](Validate-IntInRange `
      -Value $pr.max_no_progress_iterations `
      -Min 1 `
      -Max 20 `
      -IntegerMessage "[CFG] project-rule-policy.repos.max_no_progress_iterations must be integer" `
      -RangeMessage "[CFG] project-rule-policy.repos.max_no_progress_iterations out of range: expected 1..20")
  }
  if ($pr.PSObject.Properties['token_budget_mode']) {
    [void](Validate-TokenBudgetModeValue -Value ([string]$pr.token_budget_mode) -MessagePrefix "[CFG] project-rule-policy.repos.token_budget_mode")
  }
  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "stop_on_irreversible_risk" -Message "[CFG] project-rule-policy.repos.stop_on_irreversible_risk must be boolean")
  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "forbid_breaking_contract" -Message "[CFG] project-rule-policy.repos.forbid_breaking_contract must be boolean")
  [void](Validate-OptionalBooleanProperty -Object $pr -PropertyName "auto_commit_enabled" -Message "[CFG] project-rule-policy.repos.auto_commit_enabled must be boolean")
  if ($pr.PSObject.Properties['auto_commit_on_checkpoints']) {
    if ($pr.auto_commit_on_checkpoints -isnot [System.Array]) {
      Write-Host "[CFG] project-rule-policy.repos.auto_commit_on_checkpoints must be array"
      $fail++
    } else {
      foreach ($cp in @($pr.auto_commit_on_checkpoints)) {
        if ([string]::IsNullOrWhiteSpace([string]$cp)) {
          Write-Host "[CFG] project-rule-policy.repos.auto_commit_on_checkpoints contains empty value"
          $fail++
          break
        }
      }
    }
  }
  if ($pr.PSObject.Properties['auto_commit_message_prefix']) {
    if ([string]::IsNullOrWhiteSpace([string]$pr.auto_commit_message_prefix)) {
      Write-Host "[CFG] project-rule-policy.repos.auto_commit_message_prefix must be non-empty string"
      $fail++
    }
  }
}

$seenTarget = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($t in $targets) {
  if ($null -eq $t -or [string]::IsNullOrWhiteSpace([string]$t.source) -or [string]::IsNullOrWhiteSpace([string]$t.target)) {
    Write-Host "[CFG] invalid target entry: missing source or target"
    $fail++
    continue
  }

  if ([System.IO.Path]::IsPathRooted([string]$t.source)) {
    Write-Host "[CFG] source must be relative: $($t.source)"
    $fail++
  }

  $target = ([string]$t.target -replace '/', '\')
  if (-not [System.IO.Path]::IsPathRooted($target)) {
    Write-Host "[CFG] target must be absolute: $($t.target)"
    $fail++
  } else {
    $targetNorm = [System.IO.Path]::GetFullPath($target)
    if (-not $seenTarget.Add($targetNorm)) {
      Write-Host "[CFG] duplicate target path: $targetNorm"
      $fail++
    }

    if (Is-ProjectRuleSource ([string]$t.source)) {
      $targetNormUnix = ($targetNorm -replace '\\', '/')
      $matchedAllowRepo = $false
      foreach ($ar in $seenProjectAllowRepo) {
        if ($targetNormUnix.StartsWith("$ar/", [System.StringComparison]::OrdinalIgnoreCase)) {
          $matchedAllowRepo = $true
          break
        }
      }
      if (-not $matchedAllowRepo) {
        Write-Host "[CFG] disallowed project-rule target: source=$($t.source) target=$($t.target)"
        $fail++
      }
    }
  }
}

if ($null -eq $rollout.default) {
  Write-Host "[CFG] rollout.default missing"
  $fail++
}

$validPhases = @("observe", "enforce")
$defaultPhase = [string]$rollout.default.phase
if ([string]::IsNullOrWhiteSpace($defaultPhase) -or ($validPhases -notcontains $defaultPhase)) {
  Write-Host "[CFG] rollout.default.phase invalid: $defaultPhase"
  $fail++
}

if ($null -eq $rollout.repos) {
  $rolloutRepos = @()
} else {
  $rolloutRepos = @($rollout.repos)
}

foreach ($rr in $rolloutRepos) {
  $repo = [string]$rr.repo
  if ([string]::IsNullOrWhiteSpace($repo)) {
    Write-Host "[CFG] rollout repo entry missing repo"
    $fail++
    continue
  }

  $phase = [string]$rr.phase
  if (-not [string]::IsNullOrWhiteSpace($phase) -and ($validPhases -notcontains $phase)) {
    Write-Host "[CFG] rollout phase invalid: repo=$repo phase=$phase"
    $fail++
  }

  $planned = [string]$rr.planned_enforce_date
  if (-not [string]::IsNullOrWhiteSpace($planned)) {
    $d = Parse-IsoDate $planned
    if ($null -eq $d) {
      Write-Host "[CFG] invalid planned_enforce_date: repo=$repo value=$planned (expected yyyy-MM-dd)"
      $fail++
    }
  }
}

[void](Validate-BooleanValue -Value $clarificationPolicy.enabled -Message "[CFG] clarification-policy.enabled must be boolean")
[void](Validate-IntInRange `
  -Value $clarificationPolicy.max_clarifying_questions `
  -Min 1 `
  -Max 3 `
  -IntegerMessage "[CFG] clarification-policy.max_clarifying_questions must be integer" `
  -RangeMessage "[CFG] clarification-policy.max_clarifying_questions out of range: expected 1..3")
[void](Validate-IntInRange `
  -Value $clarificationPolicy.trigger_attempt_threshold `
  -Min 1 `
  -Max 10 `
  -IntegerMessage "[CFG] clarification-policy.trigger_attempt_threshold must be integer" `
  -RangeMessage "[CFG] clarification-policy.trigger_attempt_threshold out of range: expected 1..10")
[void](Validate-BooleanValue -Value $clarificationPolicy.trigger_on_conflict_signal -Message "[CFG] clarification-policy.trigger_on_conflict_signal must be boolean")
[void](Validate-BooleanValue -Value $clarificationPolicy.auto_resume_after_clarification -Message "[CFG] clarification-policy.auto_resume_after_clarification must be boolean")
$defaultScenario = Validate-RequiredNonEmptyStringProperty -Object $clarificationPolicy -PropertyName "default_scenario" -MissingMessage "[CFG] clarification-policy.default_scenario must be non-empty string"
if ($null -ne $defaultScenario) {
  $validScenarios = @("plan", "requirement", "bugfix", "acceptance")
  if ($validScenarios -notcontains $defaultScenario) {
    Write-Host "[CFG] clarification-policy.default_scenario invalid: expected one of plan/requirement/bugfix/acceptance"
    $fail++
  }
}
if ($null -eq $clarificationPolicy.PSObject.Properties['scenarios'] -or $null -eq $clarificationPolicy.scenarios) {
  Write-Host "[CFG] clarification-policy.scenarios missing"
  $fail++
} else {
  $requiredScenarios = @("plan", "requirement", "bugfix", "acceptance")
  foreach ($scenarioName in $requiredScenarios) {
    $scenarioProp = $clarificationPolicy.scenarios.PSObject.Properties[$scenarioName]
    if ($null -eq $scenarioProp -or $null -eq $scenarioProp.Value) {
      Write-Host ("[CFG] clarification-policy.scenarios.{0} missing" -f $scenarioName)
      $fail++
      continue
    }
    $scenarioConfig = $scenarioProp.Value
    if ($null -eq $scenarioConfig.PSObject.Properties['goal'] -or [string]::IsNullOrWhiteSpace([string]$scenarioConfig.goal)) {
      Write-Host ("[CFG] clarification-policy.scenarios.{0}.goal must be non-empty string" -f $scenarioName)
      $fail++
    }
    if ($null -eq $scenarioConfig.PSObject.Properties['question_prompts'] -or $scenarioConfig.question_prompts -isnot [System.Array]) {
      Write-Host ("[CFG] clarification-policy.scenarios.{0}.question_prompts must be array" -f $scenarioName)
      $fail++
      continue
    }
    $promptCount = @($scenarioConfig.question_prompts | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
    if ($promptCount -lt 1 -or $promptCount -gt 3) {
      Write-Host ("[CFG] clarification-policy.scenarios.{0}.question_prompts count out of range: expected 1..3 non-empty values" -f $scenarioName)
      $fail++
    }
  }
}

if (Test-Path -LiteralPath $codexProfileRegistryPath -PathType Leaf) {
  $codexProfileRegistry = Read-OptionalJsonConfig -Path $codexProfileRegistryPath -InvalidNotice "[CFG] codex-profile-registry.json invalid JSON"

  if ($null -ne $codexProfileRegistry) {
    [void](Validate-RequiredNonEmptyStringProperty -Object $codexProfileRegistry -PropertyName "schema_version" -MissingMessage "[CFG] codex-profile-registry.schema_version missing")

    $profiles = @()
    if ($null -ne $codexProfileRegistry.PSObject.Properties['profiles'] -and $null -ne $codexProfileRegistry.profiles) {
      $profiles = @($codexProfileRegistry.profiles)
    }

    if ($profiles.Count -eq 0) {
      Write-Host "[CFG] codex-profile-registry.profiles must contain at least one profile"
      $fail++
    } else {
      foreach ($profile in $profiles) {
        if ($null -eq $profile) {
          Write-Host "[CFG] codex-profile-registry profile entry is null"
          $fail++
          continue
        }

        if ($null -eq $profile.PSObject.Properties['name'] -or [string]::IsNullOrWhiteSpace([string]$profile.name)) {
          Write-Host "[CFG] codex-profile-registry profile.name missing"
          $fail++
        }

        if ($null -eq $profile.PSObject.Properties['rendered_artifacts'] -or $profile.rendered_artifacts -isnot [System.Array] -or @($profile.rendered_artifacts).Count -eq 0) {
          Write-Host ("[CFG] codex-profile-registry profile.rendered_artifacts invalid: profile={0}" -f [string]$profile.name)
          $fail++
        } else {
          foreach ($artifact in @($profile.rendered_artifacts)) {
            if ([string]::IsNullOrWhiteSpace([string]$artifact)) {
              Write-Host ("[CFG] codex-profile-registry rendered_artifacts contains empty value: profile={0}" -f [string]$profile.name)
              $fail++
              break
            }
          }
        }
      }
    }
  }
}

if (Test-Path -LiteralPath $codexRuntimePolicyPath -PathType Leaf) {
  $codexRuntimePolicy = Read-OptionalJsonConfig -Path $codexRuntimePolicyPath -InvalidNotice "[CFG] codex-runtime-policy.json invalid JSON"

  if ($null -ne $codexRuntimePolicy) {
    [void](Validate-RequiredNonEmptyStringProperty -Object $codexRuntimePolicy -PropertyName "schema_version" -MissingMessage "[CFG] codex-runtime-policy.schema_version missing")

    [void](Validate-RequiredBooleanProperty -Object $codexRuntimePolicy -PropertyName "enabled_by_default" -Message "[CFG] codex-runtime-policy.enabled_by_default must be boolean")

    if ($null -eq $codexRuntimePolicy.PSObject.Properties['default_files'] -or $codexRuntimePolicy.default_files -isnot [System.Array] -or @($codexRuntimePolicy.default_files).Count -eq 0) {
      Write-Host "[CFG] codex-runtime-policy.default_files must be non-empty array"
      $fail++
    } else {
      foreach ($f in @($codexRuntimePolicy.default_files)) {
        $fText = [string]$f
        if ([string]::IsNullOrWhiteSpace($fText)) {
          Write-Host "[CFG] codex-runtime-policy.default_files contains empty value"
          $fail++
          continue
        }
        if ([System.IO.Path]::IsPathRooted(($fText -replace '/', '\'))) {
          Write-Host "[CFG] codex-runtime-policy.default_files must be relative path"
          $fail++
        }
      }
    }

    if ($null -ne $codexRuntimePolicy.PSObject.Properties['repos'] -and $null -ne $codexRuntimePolicy.repos) {
      foreach ($entry in @($codexRuntimePolicy.repos)) {
        if ($null -eq $entry) {
          Write-Host "[CFG] codex-runtime-policy.repos entry is null"
          $fail++
          continue
        }

        $hasRepo = $entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)
        $hasRepoName = $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)
        if (-not $hasRepo -and -not $hasRepoName) {
          Write-Host "[CFG] codex-runtime-policy.repos entry must contain repo or repoName"
          $fail++
        }

        [void](Validate-RequiredBooleanProperty -Object $entry -PropertyName "enabled" -Message "[CFG] codex-runtime-policy.repos.enabled must be boolean")
      }
    }
  }
}

[void](Validate-RequiredNonEmptyStringProperty -Object $growthPackPolicy -PropertyName "schema_version" -MissingMessage "[CFG] growth-pack-policy.schema_version missing")
[void](Validate-RequiredBooleanProperty -Object $growthPackPolicy -PropertyName "enabled" -Message "[CFG] growth-pack-policy.enabled must be boolean")
[void](Validate-RequiredBooleanProperty -Object $growthPackPolicy -PropertyName "root_apply_enabled_by_default" -Message "[CFG] growth-pack-policy.root_apply_enabled_by_default must be boolean")
$growthDefaultTier = Validate-RequiredNonEmptyStringProperty -Object $growthPackPolicy -PropertyName "default_tier" -MissingMessage "[CFG] growth-pack-policy.default_tier missing"
$growthAllowedTiers = @("starter", "advanced", "integration")
$quickStartMode = Validate-RequiredNonEmptyStringProperty -Object $growthPackPolicy -PropertyName "readme_quickstart_mode" -MissingMessage "[CFG] growth-pack-policy.readme_quickstart_mode missing"
if ($null -ne $quickStartMode) {
  $allowedQuickStartModes = @("advisory", "enforce")
  if ($allowedQuickStartModes -notcontains ([string]$quickStartMode).ToLowerInvariant()) {
    Write-Host "[CFG] growth-pack-policy.readme_quickstart_mode invalid: expected advisory/enforce"
    $fail++
  }
}
if ($null -ne $growthDefaultTier) {
  if ($growthAllowedTiers -notcontains ([string]$growthDefaultTier).ToLowerInvariant()) {
    Write-Host "[CFG] growth-pack-policy.default_tier invalid: expected starter/advanced/integration"
    $fail++
  }
}
if ($null -eq $growthPackPolicy.PSObject.Properties['tiers'] -or $null -eq $growthPackPolicy.tiers) {
  Write-Host "[CFG] growth-pack-policy.tiers missing"
  $fail++
} else {
  foreach ($tierName in $growthAllowedTiers) {
    $tierProp = $growthPackPolicy.tiers.PSObject.Properties[$tierName]
    if ($null -eq $tierProp -or $null -eq $tierProp.Value) {
      Write-Host ("[CFG] growth-pack-policy.tiers.{0} missing" -f $tierName)
      $fail++
      continue
    }
    if ($tierProp.Value -isnot [System.Array]) {
      Write-Host ("[CFG] growth-pack-policy.tiers.{0} must be array" -f $tierName)
      $fail++
      continue
    }
    foreach ($f in @($tierProp.Value)) {
      $fText = [string]$f
      if ([string]::IsNullOrWhiteSpace($fText)) {
        Write-Host ("[CFG] growth-pack-policy.tiers.{0} contains empty path" -f $tierName)
        $fail++
        continue
      }
      if ([System.IO.Path]::IsPathRooted(($fText -replace '/', '\'))) {
        Write-Host ("[CFG] growth-pack-policy.tiers.{0} path must be relative: {1}" -f $tierName, $fText)
        $fail++
      }
    }
  }
}
if ($null -ne $growthPackPolicy.PSObject.Properties['repo_overrides'] -and $null -ne $growthPackPolicy.repo_overrides) {
  foreach ($entry in @($growthPackPolicy.repo_overrides)) {
    if ($null -eq $entry) {
      Write-Host "[CFG] growth-pack-policy.repo_overrides contains null entry"
      $fail++
      continue
    }
    $hasRepo = $entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)
    $hasRepoName = $entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)
    if (-not $hasRepo -and -not $hasRepoName) {
      Write-Host "[CFG] growth-pack-policy.repo_overrides entry must contain repo or repoName"
      $fail++
    }
    if ($entry.PSObject.Properties['tier']) {
      $entryTier = ([string]$entry.tier).ToLowerInvariant()
      if ($growthAllowedTiers -notcontains $entryTier) {
        Write-Host ("[CFG] growth-pack-policy.repo_overrides.tier invalid: {0}" -f [string]$entry.tier)
        $fail++
      }
    }
    if ($entry.PSObject.Properties['enabled']) {
      [void](Validate-BooleanValue -Value $entry.enabled -Message "[CFG] growth-pack-policy.repo_overrides.enabled must be boolean")
    }
    if ($entry.PSObject.Properties['root_apply_enabled']) {
      [void](Validate-BooleanValue -Value $entry.root_apply_enabled -Message "[CFG] growth-pack-policy.repo_overrides.root_apply_enabled must be boolean")
    }
  }
}

[void](Validate-RequiredNonEmptyStringProperty -Object $practiceStackPolicy -PropertyName "schema_version" -MissingMessage "[CFG] practice-stack-policy.schema_version missing")
if ($null -eq $practiceStackPolicy.PSObject.Properties['default'] -or $null -eq $practiceStackPolicy.default) {
  Write-Host "[CFG] practice-stack-policy.default missing"
  $fail++
}
if ($null -eq $practiceStackPolicy.PSObject.Properties['repos'] -or $practiceStackPolicy.repos -isnot [System.Array]) {
  Write-Host "[CFG] practice-stack-policy.repos must be array"
  $fail++
}

$practiceKeys = @(
  "sdd",
  "tdd",
  "atdd_bdd",
  "contract_testing",
  "harness_engineering",
  "policy_as_code",
  "observability",
  "progressive_delivery",
  "hooks_ci_gates"
)
$practiceLevels = @("required", "recommended", "optional")
if ($null -ne $practiceStackPolicy.default) {
  foreach ($k in $practiceKeys) {
    if ($null -eq $practiceStackPolicy.default.PSObject.Properties[$k]) {
      Write-Host ("[CFG] practice-stack-policy.default.{0} missing" -f $k)
      $fail++
      continue
    }
    $level = [string]$practiceStackPolicy.default.$k
    if ($practiceLevels -notcontains $level) {
      Write-Host ("[CFG] practice-stack-policy.default.{0} invalid: expected required/recommended/optional" -f $k)
      $fail++
    }
  }
}

$seenPracticeRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in @($practiceStackPolicy.repos)) {
  if ($null -eq $entry) {
    Write-Host "[CFG] practice-stack-policy.repos contains null entry"
    $fail++
    continue
  }

  $rpName = [string]$entry.repoName
  if ([string]::IsNullOrWhiteSpace($rpName)) {
    Write-Host "[CFG] practice-stack-policy.repos.repoName missing"
    $fail++
    continue
  }
  if (-not $seenPracticeRepo.Add($rpName)) {
    Write-Host ("[CFG] practice-stack-policy duplicate repoName: {0}" -f $rpName)
    $fail++
  }

  $repoNameMatched = $false
  foreach ($repoNorm in $seenRepo) {
    if ((Split-Path -Leaf $repoNorm).Equals($rpName, [System.StringComparison]::OrdinalIgnoreCase)) {
      $repoNameMatched = $true
      break
    }
  }
  if (-not $repoNameMatched) {
    Write-Host ("[CFG] practice-stack-policy repoName not in repositories.json: {0}" -f $rpName)
    $fail++
  }

  if ($null -eq $entry.PSObject.Properties['practices'] -or $null -eq $entry.practices) {
    Write-Host ("[CFG] practice-stack-policy.repos.practices missing: repoName={0}" -f $rpName)
    $fail++
    continue
  }

  foreach ($k in $practiceKeys) {
    if ($null -eq $entry.practices.PSObject.Properties[$k]) {
      Write-Host ("[CFG] practice-stack-policy.repos.practices.{0} missing: repoName={1}" -f $k, $rpName)
      $fail++
      continue
    }
    if ($entry.practices.$k -isnot [bool]) {
      Write-Host ("[CFG] practice-stack-policy.repos.practices.{0} must be boolean: repoName={1}" -f $k, $rpName)
      $fail++
    }
  }
}

[void](Validate-RequiredNonEmptyStringProperty -Object $releaseDistributionPolicy -PropertyName "schema_version" -MissingMessage "[CFG] release-distribution-policy.schema_version missing")
if ($null -eq $releaseDistributionPolicy.PSObject.Properties['default'] -or $null -eq $releaseDistributionPolicy.default) {
  Write-Host "[CFG] release-distribution-policy.default missing"
  $fail++
}
if ($null -eq $releaseDistributionPolicy.PSObject.Properties['repos'] -or $releaseDistributionPolicy.repos -isnot [System.Array]) {
  Write-Host "[CFG] release-distribution-policy.repos must be array"
  $fail++
}

$allowedChannels = @("none", "standard", "offline")
$allowedForms = @("installer", "portable")
$allowedNetworkModes = @("online", "offline")
if ($null -ne $releaseDistributionPolicy.default) {
  $d = $releaseDistributionPolicy.default
  if ($null -eq $d.signing -or $null -eq $d.packaging) {
    Write-Host "[CFG] release-distribution-policy.default.signing/default.packaging missing"
    $fail++
  } else {
    if ($d.signing.required -isnot [bool] -or $d.signing.allow_paid_signing -isnot [bool]) {
      Write-Host "[CFG] release-distribution-policy.default.signing.required/allow_paid_signing must be boolean"
      $fail++
    }
    if ([string]::IsNullOrWhiteSpace([string]$d.signing.mode)) {
      Write-Host "[CFG] release-distribution-policy.default.signing.mode missing"
      $fail++
    }
    if ([string]::IsNullOrWhiteSpace([string]$d.packaging.default_channel) -or ($allowedChannels -notcontains [string]$d.packaging.default_channel)) {
      Write-Host "[CFG] release-distribution-policy.default.packaging.default_channel invalid"
      $fail++
    }
    if ($d.packaging.channels -isnot [System.Array] -or @($d.packaging.channels).Count -eq 0) {
      Write-Host "[CFG] release-distribution-policy.default.packaging.channels must be non-empty array"
      $fail++
    } else {
      foreach ($c in @($d.packaging.channels)) {
        if ($allowedChannels -notcontains [string]$c) {
          Write-Host ("[CFG] release-distribution-policy.default.packaging.channels invalid value: {0}" -f [string]$c)
          $fail++
        }
      }
    }
    if ($d.packaging.distribution_forms -isnot [System.Array] -or @($d.packaging.distribution_forms).Count -eq 0) {
      Write-Host "[CFG] release-distribution-policy.default.packaging.distribution_forms must be non-empty array"
      $fail++
    } else {
      foreach ($fItem in @($d.packaging.distribution_forms)) {
        if ($allowedForms -notcontains [string]$fItem) {
          Write-Host ("[CFG] release-distribution-policy.default.packaging.distribution_forms invalid value: {0}" -f [string]$fItem)
          $fail++
        }
      }
    }
    if ($d.packaging.network_modes -isnot [System.Array] -or @($d.packaging.network_modes).Count -eq 0) {
      Write-Host "[CFG] release-distribution-policy.default.packaging.network_modes must be non-empty array"
      $fail++
    } else {
      foreach ($mItem in @($d.packaging.network_modes)) {
        if ($allowedNetworkModes -notcontains [string]$mItem) {
          Write-Host ("[CFG] release-distribution-policy.default.packaging.network_modes invalid value: {0}" -f [string]$mItem)
          $fail++
        }
      }
    }
    if ($d.packaging.require_framework_dependent -isnot [bool] -or $d.packaging.require_self_contained -isnot [bool]) {
      Write-Host "[CFG] release-distribution-policy.default.packaging.require_* must be boolean"
      $fail++
    }
  }
}

$seenReleasePolicyRepo = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($rp in @($releaseDistributionPolicy.repos)) {
  if ($null -eq $rp) {
    Write-Host "[CFG] release-distribution-policy.repos contains null entry"
    $fail++
    continue
  }
  $rpName = [string]$rp.repoName
  if ([string]::IsNullOrWhiteSpace($rpName)) {
    Write-Host "[CFG] release-distribution-policy.repos.repoName missing"
    $fail++
    continue
  }
  if (-not $seenReleasePolicyRepo.Add($rpName)) {
    Write-Host ("[CFG] release-distribution-policy duplicate repoName: {0}" -f $rpName)
    $fail++
  }

  $repoNameMatched = $false
  foreach ($repoNorm in $seenRepo) {
    if ((Split-Path -Leaf $repoNorm).Equals($rpName, [System.StringComparison]::OrdinalIgnoreCase)) {
      $repoNameMatched = $true
      break
    }
  }
  if (-not $repoNameMatched) {
    Write-Host ("[CFG] release-distribution-policy repoName not in repositories.json: {0}" -f $rpName)
    $fail++
  }
}

if ($fail -gt 0) {
  Write-Host "Config validation failed. issues=$fail"
  exit 1
}

Write-Host "Config validation passed. repositories=$($repos.Count) targets=$($targets.Count) rolloutRepos=$($rolloutRepos.Count)"
