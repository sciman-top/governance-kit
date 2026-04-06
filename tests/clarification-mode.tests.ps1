$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here "..")).Path

describe "clarification mode tracker" {
  it "does not trigger clarification on first failure" {
    $tmp = Join-Path $env:TEMP ("govkit-clarify-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "repo") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\track-issue-state.ps1") -Destination (Join-Path $tmp "scripts\governance\track-issue-state.ps1") -Force
      @"
{
  "enabled": true,
  "max_clarifying_questions": 3,
  "trigger_attempt_threshold": 2,
  "trigger_on_conflict_signal": true,
  "auto_resume_after_clarification": true,
  "default_scenario": "bugfix",
  "scenarios": {
    "plan": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "requirement": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "bugfix": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "acceptance": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] }
  }
}
"@ | Set-Content -Path (Join-Path $tmp "config\clarification-policy.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Mode record -Outcome failure -Reason "gate failed"
      if ($LASTEXITCODE -ne 0) { throw "tracker failed with exit code $LASTEXITCODE" }
      $result = [string]::Join([Environment]::NewLine, @($json)) | ConvertFrom-Json

      $result.attempt_count | should be 1
      $result.clarification_required | should be $false
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "triggers clarification on second failure" {
    $tmp = Join-Path $env:TEMP ("govkit-clarify-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "repo") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\track-issue-state.ps1") -Destination (Join-Path $tmp "scripts\governance\track-issue-state.ps1") -Force
      @"
{
  "enabled": true,
  "max_clarifying_questions": 3,
  "trigger_attempt_threshold": 2,
  "trigger_on_conflict_signal": true,
  "auto_resume_after_clarification": true,
  "default_scenario": "bugfix",
  "scenarios": {
    "plan": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "requirement": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "bugfix": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "acceptance": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] }
  }
}
"@ | Set-Content -Path (Join-Path $tmp "config\clarification-policy.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Mode record -Outcome failure -Reason "first fail" | Out-Null
      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Mode record -Outcome failure -Reason "second fail"
      if ($LASTEXITCODE -ne 0) { throw "tracker failed with exit code $LASTEXITCODE" }
      $result = [string]::Join([Environment]::NewLine, @($json)) | ConvertFrom-Json

      $result.attempt_count | should be 2
      $result.clarification_required | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "resets attempts after clarification" {
    $tmp = Join-Path $env:TEMP ("govkit-clarify-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "repo") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\track-issue-state.ps1") -Destination (Join-Path $tmp "scripts\governance\track-issue-state.ps1") -Force
      @"
{
  "enabled": true,
  "max_clarifying_questions": 3,
  "trigger_attempt_threshold": 2,
  "trigger_on_conflict_signal": true,
  "auto_resume_after_clarification": true,
  "default_scenario": "bugfix",
  "scenarios": {
    "plan": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "requirement": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "bugfix": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] },
    "acceptance": { "goal": "g", "question_prompts": ["q1", "q2", "q3"] }
  }
}
"@ | Set-Content -Path (Join-Path $tmp "config\clarification-policy.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Mode record -Outcome failure -Reason "first fail" | Out-Null
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Mode record -Outcome failure -Reason "second fail" | Out-Null

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Mode record -Outcome clarified
      if ($LASTEXITCODE -ne 0) { throw "tracker failed with exit code $LASTEXITCODE" }
      $result = [string]::Join([Environment]::NewLine, @($json)) | ConvertFrom-Json

      $result.attempt_count | should be 0
      $result.clarification_required | should be $false
      $result.last_outcome | should be "clarified"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "returns scenario guide for plan mode" {
    $tmp = Join-Path $env:TEMP ("govkit-clarify-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "repo") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\track-issue-state.ps1") -Destination (Join-Path $tmp "scripts\governance\track-issue-state.ps1") -Force
      @"
{
  "enabled": true,
  "max_clarifying_questions": 3,
  "trigger_attempt_threshold": 2,
  "trigger_on_conflict_signal": true,
  "auto_resume_after_clarification": true,
  "default_scenario": "bugfix",
  "scenarios": {
    "plan": { "goal": "align plan", "question_prompts": ["p1", "p2", "p3"] },
    "requirement": { "goal": "align req", "question_prompts": ["r1", "r2", "r3"] },
    "bugfix": { "goal": "align bug", "question_prompts": ["b1", "b2", "b3"] },
    "acceptance": { "goal": "align acc", "question_prompts": ["a1", "a2", "a3"] }
  }
}
"@ | Set-Content -Path (Join-Path $tmp "config\clarification-policy.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\track-issue-state.ps1") `
        -RepoPath (Join-Path $tmp "repo") -IssueId "demo-issue" -Scenario "plan" -Mode evaluate
      if ($LASTEXITCODE -ne 0) { throw "tracker failed with exit code $LASTEXITCODE" }
      $result = [string]::Join([Environment]::NewLine, @($json)) | ConvertFrom-Json

      $result.scenario | should be "plan"
      $result.clarification_guide.goal | should be "align plan"
      (@($result.clarification_guide.question_prompts)).Count | should be 3
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }
}
