param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [Parameter(Mandatory = $true)]
  [string]$IssueId,
  [ValidateSet("plan", "requirement", "bugfix", "acceptance")]
  [string]$Scenario = "",
  [ValidateSet("evaluate", "record")]
  [string]$Mode = "evaluate",
  [ValidateSet("success", "failure", "conflict", "clarified")]
  [string]$Outcome = "failure",
  [string]$Reason = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$kitRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$policyPath = Join-Path $kitRoot "config\clarification-policy.json"
if (-not (Test-Path -LiteralPath $policyPath)) {
  throw "clarification policy not found: $policyPath"
}

try {
  $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
} catch {
  throw "clarification policy invalid JSON: $policyPath"
}

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved) {
  throw "Repo path not found: $RepoPath"
}
$repo = $repoResolved.Path

if ([string]::IsNullOrWhiteSpace($IssueId)) {
  throw "IssueId cannot be empty."
}

$stateRoot = Join-Path $repo ".codex\clarification"
New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
$safeIssueId = ($IssueId -replace '[^a-zA-Z0-9._-]', '_')
$statePath = Join-Path $stateRoot ("$safeIssueId.json")

function New-DefaultState {
  return [pscustomobject]@{
    issue_id = $IssueId
    attempt_count = 0
    last_outcome = "none"
    last_failure_reason = ""
    clarification_required = $false
    updated_at = (Get-Date).ToString("o")
  }
}

function Get-State {
  if (-not (Test-Path -LiteralPath $statePath)) {
    return New-DefaultState
  }

  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  } catch {
    return New-DefaultState
  }

  if ($null -eq $state.issue_id) { $state | Add-Member -NotePropertyName issue_id -NotePropertyValue $IssueId -Force }
  if ($null -eq $state.attempt_count) { $state | Add-Member -NotePropertyName attempt_count -NotePropertyValue 0 -Force }
  if ($null -eq $state.last_outcome) { $state | Add-Member -NotePropertyName last_outcome -NotePropertyValue "none" -Force }
  if ($null -eq $state.last_failure_reason) { $state | Add-Member -NotePropertyName last_failure_reason -NotePropertyValue "" -Force }
  if ($null -eq $state.clarification_required) { $state | Add-Member -NotePropertyName clarification_required -NotePropertyValue $false -Force }
  if ($null -eq $state.updated_at) { $state | Add-Member -NotePropertyName updated_at -NotePropertyValue (Get-Date).ToString("o") -Force }
  return $state
}

function Resolve-ClarificationRequired {
  param(
    [int]$AttemptCount,
    [string]$LastOutcome
  )

  if (-not [bool]$policy.enabled) {
    return $false
  }

  $threshold = [int]$policy.trigger_attempt_threshold
  if ($AttemptCount -ge $threshold) {
    return $true
  }

  if ([bool]$policy.trigger_on_conflict_signal -and $LastOutcome -eq "conflict") {
    return $true
  }

  return $false
}

function Resolve-Scenario {
  param([string]$RequestedScenario)

  $defaultScenario = "bugfix"
  if ($null -ne $policy.PSObject.Properties['default_scenario'] -and -not [string]::IsNullOrWhiteSpace([string]$policy.default_scenario)) {
    $defaultScenario = [string]$policy.default_scenario
  }

  $effective = if ([string]::IsNullOrWhiteSpace($RequestedScenario)) { $defaultScenario } else { $RequestedScenario }
  $valid = @("plan", "requirement", "bugfix", "acceptance")
  if ($valid -notcontains $effective) {
    $effective = "bugfix"
  }
  return $effective
}

function Get-ScenarioTemplate {
  param([string]$ScenarioName)

  $fallback = [pscustomobject]@{
    goal = "Align context and reduce misunderstandings"
    question_prompts = @(
      "Describe your goal in one sentence.",
      "What is current behavior vs expected behavior?",
      "What is explicitly out of scope in this round?"
    )
  }

  if ($null -eq $policy.PSObject.Properties['scenarios']) {
    return $fallback
  }

  $scenarios = $policy.scenarios
  if ($null -eq $scenarios) {
    return $fallback
  }

  $named = $scenarios.PSObject.Properties[$ScenarioName]
  if ($null -eq $named) {
    return $fallback
  }

  $template = $named.Value
  if ($null -eq $template) {
    return $fallback
  }

  $goal = ""
  if ($null -ne $template.PSObject.Properties['goal']) {
    $goal = [string]$template.goal
  }
  if ([string]::IsNullOrWhiteSpace($goal)) {
    $goal = [string]$fallback.goal
  }

  $prompts = @()
  if ($null -ne $template.PSObject.Properties['question_prompts']) {
    $prompts = @($template.question_prompts)
  }
  if ($prompts.Count -eq 0) {
    $prompts = @($fallback.question_prompts)
  }

  $maxQ = [int]$policy.max_clarifying_questions
  if ($maxQ -lt 1) { $maxQ = 1 }
  $prompts = @($prompts | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -First $maxQ)
  if ($prompts.Count -eq 0) {
    $prompts = @($fallback.question_prompts | Select-Object -First $maxQ)
  }

  return [pscustomobject]@{
    goal = $goal
    question_prompts = $prompts
  }
}

$state = Get-State
$effectiveScenario = Resolve-Scenario -RequestedScenario $Scenario
$scenarioTemplate = Get-ScenarioTemplate -ScenarioName $effectiveScenario

if ($Mode -eq "record") {
  switch ($Outcome) {
    "success" {
      $state.attempt_count = 0
      $state.last_failure_reason = ""
      $state.clarification_required = $false
    }
    "clarified" {
      $state.attempt_count = 0
      $state.last_failure_reason = ""
      $state.clarification_required = $false
    }
    "failure" {
      $state.attempt_count = [int]$state.attempt_count + 1
      if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $state.last_failure_reason = $Reason
      }
    }
    "conflict" {
      $threshold = [int]$policy.trigger_attempt_threshold
      $state.attempt_count = [Math]::Max([int]$state.attempt_count, $threshold)
      if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $state.last_failure_reason = $Reason
      }
    }
  }

  $state.last_outcome = $Outcome
  $state.clarification_required = Resolve-ClarificationRequired -AttemptCount ([int]$state.attempt_count) -LastOutcome ([string]$state.last_outcome)
  $state.updated_at = (Get-Date).ToString("o")
  $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath -Encoding UTF8
}

$result = [pscustomobject]@{
  schema_version = "1.0"
  issue_id = $IssueId
  mode = $Mode
  state_path = $statePath
  policy = [pscustomobject]@{
    enabled = [bool]$policy.enabled
    trigger_attempt_threshold = [int]$policy.trigger_attempt_threshold
    trigger_on_conflict_signal = [bool]$policy.trigger_on_conflict_signal
    max_clarifying_questions = [int]$policy.max_clarifying_questions
    auto_resume_after_clarification = [bool]$policy.auto_resume_after_clarification
    default_scenario = if ($null -ne $policy.PSObject.Properties['default_scenario']) { [string]$policy.default_scenario } else { "bugfix" }
  }
  scenario = $effectiveScenario
  attempt_count = [int]$state.attempt_count
  last_outcome = [string]$state.last_outcome
  last_failure_reason = [string]$state.last_failure_reason
  clarification_required = [bool]$state.clarification_required
  clarification_guide = [pscustomobject]@{
    goal = [string]$scenarioTemplate.goal
    question_prompts = @($scenarioTemplate.question_prompts)
  }
  updated_at = [string]$state.updated_at
}

$result | ConvertTo-Json -Depth 8 | Write-Output
