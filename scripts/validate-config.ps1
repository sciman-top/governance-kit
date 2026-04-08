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
$clarificationPolicyPath = Join-Path $kitRoot "config\clarification-policy.json"

if (!(Test-Path $reposPath)) { throw "repositories.json not found: $reposPath" }
if (!(Test-Path $targetsPath)) { throw "targets.json not found: $targetsPath" }
if (!(Test-Path $rolloutPath)) { throw "rule-rollout.json not found: $rolloutPath" }
if (!(Test-Path $projectRulePolicyPath)) { throw "project-rule-policy.json not found: $projectRulePolicyPath" }
if (!(Test-Path $projectCustomPath)) { throw "project-custom-files.json not found: $projectCustomPath" }

$fail = 0

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

try {
  $rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
} catch {
  throw "rule-rollout.json invalid JSON: $rolloutPath"
}

try {
  $projectRulePolicy = Get-Content -Path $projectRulePolicyPath -Raw | ConvertFrom-Json
} catch {
  throw "project-rule-policy.json invalid JSON: $projectRulePolicyPath"
}

try {
  $projectCustom = Get-Content -Path $projectCustomPath -Raw | ConvertFrom-Json
} catch {
  throw "project-custom-files.json invalid JSON: $projectCustomPath"
}

if (Test-Path $clarificationPolicyPath) {
  try {
    $clarificationPolicy = Get-Content -Path $clarificationPolicyPath -Raw | ConvertFrom-Json
  } catch {
    throw "clarification-policy.json invalid JSON: $clarificationPolicyPath"
  }
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
  } elseif ($projectRulePolicy.defaults.allow_auto_fix -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.allow_auto_fix must be boolean"
    $fail++
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_rule_optimization']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.allow_rule_optimization -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.allow_rule_optimization must be boolean"
    $fail++
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['allow_local_optimize_without_backflow']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.allow_local_optimize_without_backflow -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.allow_local_optimize_without_backflow must be boolean"
    $fail++
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

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['stop_on_irreversible_risk']) {
    if ($projectRulePolicy.defaults.stop_on_irreversible_risk -isnot [bool]) {
      Write-Host "[CFG] project-rule-policy.defaults.stop_on_irreversible_risk must be boolean"
      $fail++
    }
  }

  if ($null -eq $projectRulePolicy.defaults.PSObject.Properties['forbid_breaking_contract']) {
    # backward-compatible: missing field uses runtime default
  } elseif ($projectRulePolicy.defaults.forbid_breaking_contract -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.defaults.forbid_breaking_contract must be boolean"
    $fail++
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['auto_commit_enabled']) {
    if ($projectRulePolicy.defaults.auto_commit_enabled -isnot [bool]) {
      Write-Host "[CFG] project-rule-policy.defaults.auto_commit_enabled must be boolean"
      $fail++
    }
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
    $threshold = $projectRulePolicy.defaults.clarification_trigger_attempt_threshold
    if ($threshold -isnot [int] -and $threshold -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.defaults.clarification_trigger_attempt_threshold must be integer"
      $fail++
    } elseif ([int]$threshold -lt 1 -or [int]$threshold -gt 10) {
      Write-Host "[CFG] project-rule-policy.defaults.clarification_trigger_attempt_threshold out of range: expected 1..10"
      $fail++
    }
  }

  if ($null -ne $projectRulePolicy.defaults.PSObject.Properties['clarification_max_questions']) {
    $maxQuestions = $projectRulePolicy.defaults.clarification_max_questions
    if ($maxQuestions -isnot [int] -and $maxQuestions -isnot [long]) {
      Write-Host "[CFG] project-rule-policy.defaults.clarification_max_questions must be integer"
      $fail++
    } elseif ([int]$maxQuestions -lt 1 -or [int]$maxQuestions -gt 3) {
      Write-Host "[CFG] project-rule-policy.defaults.clarification_max_questions out of range: expected 1..3"
      $fail++
    }
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

  if ($pr.PSObject.Properties['allow_auto_fix'] -and $pr.allow_auto_fix -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.allow_auto_fix must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['allow_rule_optimization'] -and $pr.allow_rule_optimization -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.allow_rule_optimization must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['allow_local_optimize_without_backflow'] -and $pr.allow_local_optimize_without_backflow -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.allow_local_optimize_without_backflow must be boolean"
    $fail++
  }
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
  if ($pr.PSObject.Properties['stop_on_irreversible_risk'] -and $pr.stop_on_irreversible_risk -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.stop_on_irreversible_risk must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['forbid_breaking_contract'] -and $pr.forbid_breaking_contract -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.forbid_breaking_contract must be boolean"
    $fail++
  }
  if ($pr.PSObject.Properties['auto_commit_enabled'] -and $pr.auto_commit_enabled -isnot [bool]) {
    Write-Host "[CFG] project-rule-policy.repos.auto_commit_enabled must be boolean"
    $fail++
  }
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

if ($clarificationPolicy.enabled -isnot [bool]) {
  Write-Host "[CFG] clarification-policy.enabled must be boolean"
  $fail++
}
if ($clarificationPolicy.max_clarifying_questions -isnot [int] -and $clarificationPolicy.max_clarifying_questions -isnot [long]) {
  Write-Host "[CFG] clarification-policy.max_clarifying_questions must be integer"
  $fail++
} elseif ([int]$clarificationPolicy.max_clarifying_questions -lt 1 -or [int]$clarificationPolicy.max_clarifying_questions -gt 3) {
  Write-Host "[CFG] clarification-policy.max_clarifying_questions out of range: expected 1..3"
  $fail++
}
if ($clarificationPolicy.trigger_attempt_threshold -isnot [int] -and $clarificationPolicy.trigger_attempt_threshold -isnot [long]) {
  Write-Host "[CFG] clarification-policy.trigger_attempt_threshold must be integer"
  $fail++
} elseif ([int]$clarificationPolicy.trigger_attempt_threshold -lt 1 -or [int]$clarificationPolicy.trigger_attempt_threshold -gt 10) {
  Write-Host "[CFG] clarification-policy.trigger_attempt_threshold out of range: expected 1..10"
  $fail++
}
if ($clarificationPolicy.trigger_on_conflict_signal -isnot [bool]) {
  Write-Host "[CFG] clarification-policy.trigger_on_conflict_signal must be boolean"
  $fail++
}
if ($clarificationPolicy.auto_resume_after_clarification -isnot [bool]) {
  Write-Host "[CFG] clarification-policy.auto_resume_after_clarification must be boolean"
  $fail++
}
if ($null -eq $clarificationPolicy.PSObject.Properties['default_scenario'] -or [string]::IsNullOrWhiteSpace([string]$clarificationPolicy.default_scenario)) {
  Write-Host "[CFG] clarification-policy.default_scenario must be non-empty string"
  $fail++
} else {
  $defaultScenario = [string]$clarificationPolicy.default_scenario
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

if ($fail -gt 0) {
  Write-Host "Config validation failed. issues=$fail"
  exit 1
}

Write-Host "Config validation passed. repositories=$($repos.Count) targets=$($targets.Count) rolloutRepos=$($rolloutRepos.Count)"
