$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here "..")).Path

function Write-Utf8NoBomFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}


function Set-MinProjectRulePolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigDir,
    [Parameter(Mandatory = $true)]
    [string]$RepoPath
  )

  @{
    allowProjectRulesForRepos = @($RepoPath)
    defaults = @{
      allow_auto_fix = $true
      allow_rule_optimization = $true
      allow_local_optimize_without_backflow = $false
      max_autonomous_iterations = 3
      max_repeated_failure_per_step = 2
      stop_on_irreversible_risk = $true
      forbid_breaking_contract = $true
    }
    repos = @()
  } | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $ConfigDir "project-rule-policy.json") -Encoding UTF8
}

function Set-MinReleaseDistributionPolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigDir
  )

  @'
{
  "schema_version": "1.0",
  "default": {
    "signing": {
      "required": false,
      "mode": "none-personal",
      "allow_paid_signing": false
    },
    "packaging": {
      "default_channel": "none",
      "channels": ["none"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    }
  },
  "repos": [
    {
      "repoName": "FakeRepo",
      "signing": {
        "required": false,
        "mode": "none-personal",
        "allow_paid_signing": false
      },
      "packaging": {
        "default_channel": "none",
        "channels": ["none"],
        "distribution_forms": ["portable"],
        "network_modes": ["online"],
        "require_framework_dependent": false,
        "require_self_contained": false
      }
    }
  ]
}
'@ | Set-Content -Path (Join-Path $ConfigDir "release-distribution-policy.json") -Encoding UTF8
}

function Set-MinPracticeStackPolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigDir,
    [string]$RepoName = "FakeRepo"
  )

  @"
{
  "schema_version": "1.0",
  "default": {
    "sdd": "required",
    "tdd": "required",
    "atdd_bdd": "recommended",
    "contract_testing": "required",
    "harness_engineering": "required",
    "policy_as_code": "required",
    "observability": "required",
    "progressive_delivery": "recommended",
    "hooks_ci_gates": "required"
  },
  "repos": [
    {
      "repoName": "$RepoName",
      "practices": {
        "sdd": true,
        "tdd": true,
        "atdd_bdd": true,
        "contract_testing": true,
        "harness_engineering": true,
        "policy_as_code": true,
        "observability": true,
        "progressive_delivery": true,
        "hooks_ci_gates": true
      }
    }
  ]
}
"@ | Set-Content -Path (Join-Path $ConfigDir "practice-stack-policy.json") -Encoding UTF8
}

function Set-StubScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Message = "ok",
    [int]$ExitCode = 0
  )

  $parent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  @"
param()
Write-Host "$Message"
exit $ExitCode
"@ | Set-Content -Path $Path -Encoding UTF8
}

function Set-RequireSkipValidationVerifyScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  @'
param([switch]$SkipConfigValidation)
if (-not $SkipConfigValidation) {
  Write-Host "missing -SkipConfigValidation"
  exit 1
}
Write-Host "ok"
exit 0
'@ | Set-Content -Path $Path -Encoding UTF8
}

function Initialize-ClarificationTrackerFixture {
  param(
    [Parameter(Mandatory = $true)]
    [string]$TmpRoot
  )

  New-Item -ItemType Directory -Path (Join-Path $TmpRoot "scripts\governance") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $TmpRoot "config") -Force | Out-Null

  Copy-Item -Path (Join-Path $repoRoot "scripts\governance\track-issue-state.ps1") -Destination (Join-Path $TmpRoot "scripts\governance\track-issue-state.ps1") -Force
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
"@ | Set-Content -Path (Join-Path $TmpRoot "config\clarification-policy.json") -Encoding UTF8
}

describe "governance-kit optimization guardrails" {
  it "has shared common script for cross-script helpers" {
    $commonPath = Join-Path $repoRoot "scripts\lib\common.ps1"
    (Test-Path $commonPath) | should be $true
  }

  it "install force mode ignores no-overwrite switches" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path $tmp -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\install.ps1") -Destination (Join-Path $tmp "scripts\install.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
      Set-Content -Path $src -Value "new-content" -Encoding UTF8
      Set-Content -Path $dst -Value "old-content" -Encoding UTF8

      @(
        @{ source = "source/AGENTS.md"; target = $dst }
      ) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\install.ps1") -Mode force -NoOverwriteRules -SkipPostVerify | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "install.ps1 force failed with exit code $LASTEXITCODE" }

      (Get-Content -Path $dst -Raw).Trim() | should be "new-content"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "waiver checker only accepts ISO date format yyyy-MM-dd" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "repo"
    try {
      New-Item -ItemType Directory -Path $tmp -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "docs\governance\waivers") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\check-waivers.ps1") -Destination (Join-Path $tmp "scripts\check-waivers.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @($repo) | ConvertTo-Json | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(@{ repo = $repo; phase = "observe"; blockExpiredWaiver = $false })
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      @"
waiver_id=W-1
rule_id=R-1
status=open
expires_at=2026/03/01
"@ | Set-Content -Path (Join-Path $repo "docs\governance\waivers\w1.md") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\check-waivers.ps1") 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "check-waivers.ps1 failed with exit code $LASTEXITCODE" }

      $output | should match "invalid expires_at"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "install prints mode risk banner in plan mode" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\install.ps1") -Destination (Join-Path $tmp "scripts\install.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      Set-Content -Path $src -Value "new-content" -Encoding UTF8
      @(@{ source = "source/AGENTS.md"; target = $dst }) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\install.ps1") -Mode plan 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "install.ps1 plan failed with exit code $LASTEXITCODE" }
      $output | should match "\[MODE\] install.ps1 mode=plan risk=LOW\(read-only\)"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "install non-plan enforces post-verify assertion" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\install.ps1") -Destination (Join-Path $tmp "scripts\install.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @"
param()
Set-Content -Path "$tmp\verify.marker" -Value "ok" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\verify.ps1") -Encoding UTF8

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
      Set-Content -Path $src -Value "new-content" -Encoding UTF8
      Set-Content -Path $dst -Value "old-content" -Encoding UTF8
      @(@{ source = "source/AGENTS.md"; target = $dst }) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\install.ps1") -Mode safe -NoBackup 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "install.ps1 safe failed with exit code $LASTEXITCODE" }
      (Test-Path (Join-Path $tmp "verify.marker")) | should be $true
      $output | should match "\[ASSERT\] post-verify passed"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "install counts unchanged entries in skipped summary" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "target") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\install.ps1") -Destination (Join-Path $tmp "scripts\install.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      Set-Content -Path $src -Value "same-content" -Encoding UTF8
      Set-Content -Path $dst -Value "same-content" -Encoding UTF8
      @(@{ source = "source/AGENTS.md"; target = $dst }) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\install.ps1") -Mode safe -NoBackup -SkipPostVerify -AsJson 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "install.ps1 safe failed with exit code $LASTEXITCODE" }
      $output | should match '"skipped"\s*:\s*1'
      $output | should match '"copied"\s*:\s*0'
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "install full-cycle runs after install lock is released" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "target") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\install.ps1") -Destination (Join-Path $tmp "scripts\install.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @"
param([string]`$RepoPath,[string]`$RepoName,[ValidateSet('plan','safe')]`$Mode='safe')
Set-Content -Path "$tmp\cycle.marker" -Value ("repo=" + `$RepoName + ";mode=" + `$Mode) -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1") -Message "ok" -ExitCode 0

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      Set-Content -Path $src -Value "new-content" -Encoding UTF8
      Set-Content -Path $dst -Value "old-content" -Encoding UTF8

      @(@{ source = "source/AGENTS.md"; target = $dst }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @((Join-Path $tmp "RepoA")) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\install.ps1") -Mode safe -NoBackup -FullCycle 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "install.ps1 full-cycle failed with exit code $LASTEXITCODE" }

      (Test-Path (Join-Path $tmp "cycle.marker")) | should be $true
      (Get-Content -Path (Join-Path $tmp "cycle.marker") -Raw) | should match "mode=safe"
      $output | should match "=== FULL_CYCLE"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-config fails on non-ISO planned_enforce_date" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      if (Test-Path (Join-Path $repoRoot "scripts\validate-config.ps1")) {
        Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force
      }

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "FakeRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath "E:/CODE/FakeRepo"
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026/04/15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-config.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "invalid planned_enforce_date"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-config passes on ISO planned_enforce_date" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      if (Test-Path (Join-Path $repoRoot "scripts\validate-config.ps1")) {
        Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force
      }

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "FakeRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath "E:/CODE/FakeRepo"
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026-04-15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-config.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "Config validation passed"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-config fails when skill source is not registered in project-custom-files" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\_common\custom\.agents\skills\new-skill") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force

      Write-Utf8NoBomFile -Path (Join-Path $tmp "source\project\_common\custom\.agents\skills\new-skill\SKILL.md") -Content @'
---
name: new-skill
description: test fixture skill
---

Fixture body.
'@

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "FakeRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath "E:/CODE/FakeRepo"
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-config.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "unregistered skill custom file"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-config passes when skill source is registered in project-custom-files" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\_common\custom\.agents\skills\new-skill") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force

      Write-Utf8NoBomFile -Path (Join-Path $tmp "source\project\_common\custom\.agents\skills\new-skill\SKILL.md") -Content @'
---
name: new-skill
description: test fixture skill
---

Fixture body.
'@

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8
      @{
        default = @(".agents/skills/new-skill/SKILL.md")
        repos = @(
          @{
            repoName = "FakeRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath "E:/CODE/FakeRepo"
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-config.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "Config validation passed"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-config fails on invalid autonomous limit fields" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8
      @{
        allowProjectRulesForRepos = @("E:/CODE/FakeRepo")
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          max_autonomous_iterations = 0
          max_repeated_failure_per_step = "two"
          stop_on_irreversible_risk = $true
          forbid_breaking_contract = $true
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8
      @{
        default = @()
        repos = @(@{ repoName = "FakeRepo"; files = @() })
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-config.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "max_autonomous_iterations out of range"
      $output | should match "max_repeated_failure_per_step must be integer"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-config fails on invalid auto commit policy fields" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8
      @{
        allowProjectRulesForRepos = @("E:/CODE/FakeRepo")
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          max_autonomous_iterations = 3
          max_repeated_failure_per_step = 2
          stop_on_irreversible_risk = $true
          forbid_breaking_contract = $true
          auto_commit_enabled = "yes"
          auto_commit_on_checkpoints = "after_backflow"
          auto_commit_message_prefix = ""
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8
      @{
        default = @()
        repos = @(@{ repoName = "FakeRepo"; files = @() })
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-config.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "auto_commit_enabled must be boolean"
      $output | should match "auto_commit_on_checkpoints must be array"
      $output | should match "auto_commit_message_prefix must be non-empty string"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "verify fails fast when config is invalid" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "target") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\verify.ps1") -Destination (Join-Path $tmp "scripts\verify.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-config.ps1") -Destination (Join-Path $tmp "scripts\validate-config.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      Set-Content -Path $src -Value "same-content" -Encoding UTF8
      Set-Content -Path $dst -Value "same-content" -Encoding UTF8

      @(@{ source = "source/AGENTS.md"; target = $dst }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "FakeRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath "E:/CODE/FakeRepo"
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026/04/15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\verify.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "invalid planned_enforce_date"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "verify can skip validate-config when explicitly requested" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "target") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\verify.ps1") -Destination (Join-Path $tmp "scripts\verify.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1") -Message "stub validate-config failed" -ExitCode 1

      $src = Join-Path $tmp "source\AGENTS.md"
      $dst = Join-Path $tmp "target\AGENTS.md"
      Set-Content -Path $src -Value "same-content" -Encoding UTF8
      Set-Content -Path $dst -Value "same-content" -Encoding UTF8

      @(@{ source = "source/AGENTS.md"; target = $dst }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\verify.ps1") -SkipConfigValidation 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "Verify done\. ok=1 fail=0"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "doctor reports red when a step fails" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\doctor.ps1") -Destination (Join-Path $tmp "scripts\doctor.ps1") -Force

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-release-profile-coverage.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1") -Message "boom" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-practice-stack.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\status.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\rollout-status.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\doctor.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "HEALTH=RED"
      $output | should match "failed_steps=verify-targets"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "doctor runs verify with skip-config-validation to avoid duplicate validation" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\doctor.ps1") -Destination (Join-Path $tmp "scripts\doctor.ps1") -Force

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-release-profile-coverage.ps1")
      Set-RequireSkipValidationVerifyScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-practice-stack.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\status.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\rollout-status.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\doctor.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "HEALTH=GREEN"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "doctor can skip verify-targets for local structural health check" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\doctor.ps1") -Destination (Join-Path $tmp "scripts\doctor.ps1") -Force

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-release-profile-coverage.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1") -Message "boom" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-practice-stack.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\status.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\rollout-status.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\doctor.ps1") -SkipVerifyTargets 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "\[SKIP\] verify-targets"
      $output | should match "HEALTH=GREEN"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "doctor supports AsJson output for machine consumption" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\doctor.ps1") -Destination (Join-Path $tmp "scripts\doctor.ps1") -Force

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-release-profile-coverage.ps1")
      Set-RequireSkipValidationVerifyScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\governance\check-practice-stack.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\status.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\rollout-status.ps1")

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\doctor.ps1") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "doctor.ps1 -AsJson failed with exit code $LASTEXITCODE" }
      $obj = ($json | Out-String | ConvertFrom-Json)

      $obj.schema_version | should be "1.0"
      $obj.health | should be "GREEN"
      @($obj.failed_steps).Count | should be 0
      (@($obj.steps).Count -ge 5) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "anti-bloat budgets apply mode_limits by token_budget_mode" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp ".governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "sample") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-anti-bloat-budgets.ps1") -Destination (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1") -Force

      $lines = @()
      for ($i = 1; $i -le 850; $i++) {
        $lines += ('Write-Host "line-{0}"' -f $i)
      }
      ($lines -join "`r`n") | Set-Content -Path (Join-Path $tmp "sample\large.ps1") -Encoding UTF8

      @'
{
  "schema_version": "1.0",
  "enabled": true,
  "enforce": {
    "block_on_violation": true
  },
  "scope": {
    "prefer_git_pending": false,
    "include_untracked": true,
    "scan_repo_when_no_pending": true,
    "max_repo_files": 50
  },
  "scan": {
    "include_extensions": [".ps1"],
    "exclude_paths": ["scripts/governance/"]
  },
  "limits": {
    "max_file_lines": 1000,
    "max_consecutive_non_empty_lines": 2000,
    "max_estimated_tokens_per_file": 50000,
    "max_estimated_tokens_total_pending": 50000,
    "max_duplicate_line_occurrences": 1000,
    "chars_per_token": 4
  },
  "mode_limits": {
    "lite": {
      "max_file_lines": 800
    },
    "deep": {
      "max_file_lines": 1200
    }
  }
}
'@ | Set-Content -Path (Join-Path $tmp ".governance\anti-bloat-policy.json") -Encoding UTF8

      $liteOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1") -RepoRoot $tmp -TokenBudgetMode lite 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $liteOutput | should match "anti_bloat\.token_budget_mode=lite"
      $liteOutput | should match "VIOLATION\] file_lines"

      $deepOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1") -RepoRoot $tmp -TokenBudgetMode deep 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $deepOutput | should match "anti_bloat\.token_budget_mode=deep"
      $deepOutput | should match "anti_bloat\.health=PASS"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "status supports AsJson output" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\status.ps1") -Destination (Join-Path $tmp "scripts\status.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @'
{
  "schema_version": "1.0",
  "enabled_by_default": false,
  "default_files": [".codex/config.toml"],
  "repos": [
    { "repoName": "FakeRepo", "enabled": true }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\codex-runtime-policy.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026-04-15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\status.ps1") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "status.ps1 -AsJson failed with exit code $LASTEXITCODE" }
      $obj = ($json | Out-String | ConvertFrom-Json)

      $obj.schema_version | should be "1.0"
      $obj.repositories | should be 1
      $obj.targets | should be 1
      $obj.rollout.default_phase | should be "observe"
      $obj.codex_runtime.policy_found | should be $true
      $obj.codex_runtime.enabled_repo_entries | should be 1
      $obj.codex_runtime.codex_target_mappings | should be 1
      $obj.codex_runtime.codex_home_target_mappings | should be 1
      $obj.codex_runtime.codex_repo_target_mappings | should be 0
      ($obj.core_health.score -ge 0) | should be $true
      ($obj.core_health.level -in @("GREEN","YELLOW","RED")) | should be $true
      @($obj.warnings).Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "rollout-status supports AsJson output" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\rollout-status.ps1") -Destination (Join-Path $tmp "scripts\rollout-status.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026-04-15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\rollout-status.ps1") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "rollout-status.ps1 -AsJson failed with exit code $LASTEXITCODE" }
      $obj = ($json | Out-String | ConvertFrom-Json)

      $obj.schema_version | should be "1.0"
      $obj.default_phase | should be "observe"
      $obj.observe | should be 1
      $obj.enforce | should be 0
      @($obj.warnings).Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "status uses strict ISO date parsing for rollout planned_enforce_date" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\status.ps1") -Destination (Join-Path $tmp "scripts\status.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026/04/15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\status.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "invalid planned_enforce_date"
      $output | should match "expected yyyy-MM-dd"
      $output | should match "rollout\.observe_overdue=0"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "rollout-status uses strict ISO date parsing for planned_enforce_date" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\rollout-status.ps1") -Destination (Join-Path $tmp "scripts\rollout-status.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @{
        default = @{ phase = "observe"; blockExpiredWaiver = $false }
        repos = @(
          @{
            repo = "E:/CODE/FakeRepo"
            phase = "observe"
            planned_enforce_date = "2026/04/15"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\rule-rollout.json") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\rollout-status.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "invalid planned_enforce_date"
      $output | should match "expected yyyy-MM-dd"
      $output | should match "phase\.observe_overdue=0"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "bump-rule-version plan previews updates without writing" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\global") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\bump-rule-version.ps1") -Destination (Join-Path $tmp "scripts\bump-rule-version.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $seed = @"
# title
**版本**: 1.00
**最后更新**: 2026-01-01
"@
      @("AGENTS.md", "CLAUDE.md", "GEMINI.md") | ForEach-Object {
        Set-Content -Path (Join-Path $tmp "source\global\$_") -Value $seed -Encoding UTF8
        Set-Content -Path (Join-Path $tmp "source\project\$_") -Value $seed -Encoding UTF8
      }

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\bump-rule-version.ps1") -Scope all -Version 2.34 -Date 2026-03-30 -Mode plan 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "bump-rule-version plan failed with exit code $LASTEXITCODE" }

      $output | should match "files_to_update=6"
      (Get-Content -Raw (Join-Path $tmp "source\global\AGENTS.md")) | should match "1\.00"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "bump-rule-version safe updates version and date" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\global") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\bump-rule-version.ps1") -Destination (Join-Path $tmp "scripts\bump-rule-version.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $seed = @"
# title
**版本**: 1.00
**最后更新**: 2026-01-01
"@
      Set-Content -Path (Join-Path $tmp "source\global\AGENTS.md") -Value $seed -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\global\CLAUDE.md") -Value $seed -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\global\GEMINI.md") -Value $seed -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\bump-rule-version.ps1") -Scope global -Version 2.35 -Date 2026-03-30 -Mode safe 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "bump-rule-version safe failed with exit code $LASTEXITCODE" }
      $output | should match "files_updated=3"

      (Get-Content -Raw (Join-Path $tmp "source\global\AGENTS.md")) | should match "2\.35"
      (Get-Content -Raw (Join-Path $tmp "source\global\AGENTS.md")) | should match "2026-03-30"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "collect-governance-metrics reads rule_version from generic markdown metadata label" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "repo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\global") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\collect-governance-metrics.ps1") -Destination (Join-Path $tmp "scripts\collect-governance-metrics.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @($repo) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8

      @"
# AGENTS
**Version**: 7.77
**Last Updated**: 2026-03-30
"@ | Set-Content -Path (Join-Path $tmp "source\global\AGENTS.md") -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\collect-governance-metrics.ps1") 2>&1 | Out-String
      if ($LASTEXITCODE -ne 0) { throw "collect-governance-metrics failed with exit code $LASTEXITCODE" }
      $output | should match "collect-governance-metrics done"

      $metrics = Get-Content -Raw (Join-Path $repo "docs\governance\metrics-auto.md")
      $metrics | should match "rule_version=7\.77"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "add-repo prefers repo-scoped project rule sources when available" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "FakeRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\FakeRepo") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\add-repo.ps1") -Destination (Join-Path $tmp "scripts\add-repo.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath $repo
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "source\project\AGENTS.md") -Value "legacy" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\CLAUDE.md") -Value "legacy" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\GEMINI.md") -Value "legacy" -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "source\project\FakeRepo\AGENTS.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\FakeRepo\CLAUDE.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\FakeRepo\GEMINI.md") -Value "scoped" -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\add-repo.ps1") -RepoPath $repo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "add-repo.ps1 failed with exit code $LASTEXITCODE" }

      $targets = Get-Content -Raw (Join-Path $tmp "config\targets.json") | ConvertFrom-Json
      (@($targets | Where-Object { $_.source -like "source/project/FakeRepo/*" })).Count | should be 3
      (@($targets | Where-Object { $_.source -like "source/project/*.md" -and $_.source -notlike "source/project/FakeRepo/*" })).Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "add-repo falls back to _common custom source for default custom files" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "FreshRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\FreshRepo") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\_common\custom\scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\add-repo.ps1") -Destination (Join-Path $tmp "scripts\add-repo.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath $repo
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @("scripts/governance/run-target-autopilot.ps1")
        repos = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "source\project\FreshRepo\AGENTS.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\FreshRepo\CLAUDE.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\FreshRepo\GEMINI.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\_common\custom\scripts\governance\run-target-autopilot.ps1") -Value "param()" -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\add-repo.ps1") -RepoPath $repo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "add-repo.ps1 failed with exit code $LASTEXITCODE" }

      $targets = Get-Content -Raw (Join-Path $tmp "config\targets.json") | ConvertFrom-Json
      (@($targets | Where-Object { $_.source -eq "source/project/_common/custom/scripts/governance/run-target-autopilot.ps1" })).Count | should be 1
      (@($targets | Where-Object { $_.target -eq "$(($repo -replace '\\','/'))/scripts/governance/run-target-autopilot.ps1" })).Count | should be 1
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "add-repo injects generic template project rules for repos outside allow-list" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "OutsideAllowListRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\template\project") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\add-repo.ps1") -Destination (Join-Path $tmp "scripts\add-repo.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @{
        allowProjectRulesForRepos = @()
      } | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @()
        repos = @()
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "source\template\project\AGENTS.md") -Value "template-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\template\project\CLAUDE.md") -Value "template-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\template\project\GEMINI.md") -Value "template-gemini" -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\add-repo.ps1") -RepoPath $repo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "add-repo.ps1 failed with exit code $LASTEXITCODE" }

      $targets = Get-Content -Raw (Join-Path $tmp "config\targets.json") | ConvertFrom-Json
      (@($targets | Where-Object { $_.source -eq "source/template/project/AGENTS.md" })).Count | should be 1
      (@($targets | Where-Object { $_.source -eq "source/template/project/CLAUDE.md" })).Count | should be 1
      (@($targets | Where-Object { $_.source -eq "source/template/project/GEMINI.md" })).Count | should be 1
      (@($targets | Where-Object { $_.target -eq "$(($repo -replace '\\','/'))/AGENTS.md" })).Count | should be 1
      (@($targets | Where-Object { $_.target -eq "$(($repo -replace '\\','/'))/CLAUDE.md" })).Count | should be 1
      (@($targets | Where-Object { $_.target -eq "$(($repo -replace '\\','/'))/GEMINI.md" })).Count | should be 1
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "bootstrap-repo skips no-overwrite self-protection for governance-kit itself" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\bootstrap-repo.ps1") -Destination (Join-Path $tmp "scripts\bootstrap-repo.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param()
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\add-repo.ps1") -Encoding UTF8
      @'
param()
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\merge-rules.ps1") -Encoding UTF8
      @'
param()
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\install-extras.ps1") -Encoding UTF8
      @'
param()
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\doctor.ps1") -Encoding UTF8
      @"
param([string[]]`$Args)
Set-Content -Path "$tmp\install-args.txt" -Value ([string]::Join(' ', `$Args)) -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\install.ps1") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\bootstrap-repo.ps1") -RepoPath $tmp -Mode safe -SkipInstallGlobalGit | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "bootstrap-repo.ps1 failed with exit code $LASTEXITCODE" }

      $installArgs = Get-Content -Path (Join-Path $tmp "install-args.txt") -Raw
      $installArgs | should not match "NoOverwriteUnderRepo"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-project-governance-cycle auto-skips optimize and backflow for repos outside allow-list" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "OutsideAllowListRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\run-project-governance-cycle.ps1") -Destination (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-tracked-files.ps1") -Destination (Join-Path $tmp "scripts\governance\check-tracked-files.ps1") -Force
      Initialize-ClarificationTrackerFixture -TmpRoot $tmp

      @{
        allowProjectRulesForRepos = @()
      } | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "OutsideAllowListRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\install.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\install-extras.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1")
      @"
param()
Set-Content -Path "$tmp\optimize.marker" -Value "called" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\optimize-project-rules.ps1") -Encoding UTF8
      @"
param()
Set-Content -Path "$tmp\backflow.marker" -Value "called" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Encoding UTF8
      Set-StubScript -Path (Join-Path $tmp "scripts\suggest-project-custom-files.ps1")

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -RepoPath $repo -RepoName OutsideAllowListRepo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "run-project-governance-cycle.ps1 failed with exit code $LASTEXITCODE" }

      (Test-Path (Join-Path $tmp "optimize.marker")) | should be $false
      (Test-Path (Join-Path $tmp "backflow.marker")) | should be $false
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-project-governance-cycle allows local optimize without backflow when policy enabled" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "OutsideAllowListRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\run-project-governance-cycle.ps1") -Destination (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-tracked-files.ps1") -Destination (Join-Path $tmp "scripts\governance\check-tracked-files.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Initialize-ClarificationTrackerFixture -TmpRoot $tmp

      @{
        allowProjectRulesForRepos = @()
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          allow_local_optimize_without_backflow = $true
          forbid_breaking_contract = $true
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "OutsideAllowListRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\install.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\install-extras.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1")
      @"
param()
Set-Content -Path "$tmp\optimize.marker" -Value "called" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\optimize-project-rules.ps1") -Encoding UTF8
      @"
param()
Set-Content -Path "$tmp\backflow.marker" -Value "called" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Encoding UTF8
      Set-StubScript -Path (Join-Path $tmp "scripts\suggest-project-custom-files.ps1")

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -RepoPath $repo -RepoName OutsideAllowListRepo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "run-project-governance-cycle.ps1 failed with exit code $LASTEXITCODE" }

      (Test-Path (Join-Path $tmp "optimize.marker")) | should be $true
      (Test-Path (Join-Path $tmp "backflow.marker")) | should be $false
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-project-governance-cycle auto commits milestone changes with Chinese message and clean tree" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "TargetRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\run-project-governance-cycle.ps1") -Destination (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-tracked-files.ps1") -Destination (Join-Path $tmp "scripts\governance\check-tracked-files.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Initialize-ClarificationTrackerFixture -TmpRoot $tmp

      & git -C $repo init | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git init failed" }
      & git -C $repo config user.name "governance-bot" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git config user.name failed" }
      & git -C $repo config user.email "governance-bot@example.com" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git config user.email failed" }

      Set-Content -Path (Join-Path $repo "README.md") -Value "seed" -Encoding UTF8
      Set-Content -Path (Join-Path $repo ".gitignore") -Value ".codex/" -Encoding UTF8
      & git -C $repo add -A | Out-Null
      & git -C $repo commit -m "初始化提交" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "initial git commit failed" }

      @{
        allowProjectRulesForRepos = @($repo)
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          allow_local_optimize_without_backflow = $false
          max_autonomous_iterations = 3
          max_repeated_failure_per_step = 2
          stop_on_irreversible_risk = $true
          forbid_breaking_contract = $true
        }
        repos = @(
          @{
            repoName = "TargetRepo"
            auto_commit_enabled = $true
            auto_commit_on_checkpoints = @("after_backflow")
            auto_commit_message_prefix = "治理里程碑自动提交"
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "TargetRepo"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\install.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\install-extras.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\optimize-project-rules.ps1")
      @"
param()
Set-Content -Path "$repo\milestone.txt" -Value "changed" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Encoding UTF8
      Set-StubScript -Path (Join-Path $tmp "scripts\suggest-project-custom-files.ps1")

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -RepoPath $repo -RepoName TargetRepo -Mode safe -SkipOptimize | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "run-project-governance-cycle.ps1 failed with exit code $LASTEXITCODE" }

      $lastMsg = (& git -C $repo log -1 --pretty=%B | Out-String).Trim()
      $lastMsg | should match "治理里程碑自动提交"
      $lastMsg | should match "after_backflow"

      $status = (& git -C $repo status --porcelain | Out-String).Trim()
      $status | should be ""
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-project-governance-cycle blocks when cycle_complete clean-checkpoint is dirty" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "DirtyRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\run-project-governance-cycle.ps1") -Destination (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Initialize-ClarificationTrackerFixture -TmpRoot $tmp

      & git -C $repo init | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git init failed" }
      & git -C $repo config user.name "governance-bot" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git config user.name failed" }
      & git -C $repo config user.email "governance-bot@example.com" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git config user.email failed" }

      Set-Content -Path (Join-Path $repo "README.md") -Value "seed" -Encoding UTF8
      & git -C $repo add -A | Out-Null
      & git -C $repo commit -m "初始化提交" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "initial git commit failed" }

      @(
        @{
          allowProjectRulesForRepos = @($repo)
          defaults = @{
            allow_auto_fix = $true
            allow_rule_optimization = $true
            allow_local_optimize_without_backflow = $false
            max_autonomous_iterations = 3
            max_repeated_failure_per_step = 2
            stop_on_irreversible_risk = $true
            forbid_breaking_contract = $true
            auto_commit_enabled = $false
            auto_commit_on_checkpoints = @()
            auto_commit_message_prefix = "治理里程碑自动提交"
          }
          repos = @(
            @{
              repoName = "DirtyRepo"
              auto_commit_enabled = $false
              auto_commit_on_checkpoints = @()
              auto_commit_message_prefix = "治理里程碑自动提交"
            }
          )
        }
      )[0] | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8

      @(
        @{
          default = @()
          repos = @(
            @{
              repoName = "DirtyRepo"
              files = @()
            }
          )
        }
      )[0] | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\install.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\install-extras.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\optimize-project-rules.ps1")
      @"
param()
Set-Content -Path "$repo\dirty.txt" -Value "changed" -Encoding UTF8
exit 0
"@ | Set-Content -Path (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Encoding UTF8
      Set-StubScript -Path (Join-Path $tmp "scripts\suggest-project-custom-files.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -RepoPath $repo -RepoName DirtyRepo -Mode safe -SkipOptimize 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "clean checkpoint failed at 'cycle_complete'"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-project-governance-cycle blocks early when repo is dirty before safe cycle starts" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "PreflightDirtyRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\run-project-governance-cycle.ps1") -Destination (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Initialize-ClarificationTrackerFixture -TmpRoot $tmp

      & git -C $repo init | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git init failed" }
      & git -C $repo config user.name "governance-bot" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git config user.name failed" }
      & git -C $repo config user.email "governance-bot@example.com" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "git config user.email failed" }

      Set-Content -Path (Join-Path $repo "README.md") -Value "seed" -Encoding UTF8
      & git -C $repo add -A | Out-Null
      & git -C $repo commit -m "初始化提交" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "initial git commit failed" }
      Set-Content -Path (Join-Path $repo "README.md") -Value "dirty-before-cycle" -Encoding UTF8

      @(
        @{
          allowProjectRulesForRepos = @($repo)
          defaults = @{
            allow_auto_fix = $true
            allow_rule_optimization = $true
            allow_local_optimize_without_backflow = $false
            max_autonomous_iterations = 3
            max_repeated_failure_per_step = 2
            stop_on_irreversible_risk = $true
            forbid_breaking_contract = $true
            auto_commit_enabled = $true
            auto_commit_on_checkpoints = @("after_backflow")
            auto_commit_message_prefix = "治理里程碑自动提交"
          }
          repos = @(
            @{
              repoName = "PreflightDirtyRepo"
              auto_commit_enabled = $true
              auto_commit_on_checkpoints = @("after_backflow")
              auto_commit_message_prefix = "治理里程碑自动提交"
            }
          )
        }
      )[0] | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8

      @(
        @{
          default = @()
          repos = @(
            @{
              repoName = "PreflightDirtyRepo"
              files = @()
            }
          )
        }
      )[0] | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\install.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\install-extras.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\optimize-project-rules.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\backflow-project-rules.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\suggest-project-custom-files.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-project-governance-cycle.ps1") -RepoPath $repo -RepoName PreflightDirtyRepo -Mode safe -SkipOptimize 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "preflight failed: repo has pre-existing dirty entries"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-failure-context accepts complete failure context JSON" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-failure-context.ps1") -Destination (Join-Path $tmp "scripts\validate-failure-context.ps1") -Force

      $json = @{
        failed_step = "contract.verify"
        command = "powershell -File scripts/run-project-governance-cycle.ps1"
        exit_code = 1
        log_path = "E:/CODE/repo/.codex/logs/failure.log"
        repo_path = "E:/CODE/repo"
        gate_order = "build -> test -> contract/invariant -> hotspot"
        retry_command = "powershell -File scripts/run-project-governance-cycle.ps1"
        policy_snapshot = @{
          allow_project_rules = $false
        }
        remediation_owner = "outer-ai-session"
        remediation_scope = "governance-kit-first"
        rerun_owner = "outer-ai-session"
        timestamp = "2026-04-03T12:00:00+08:00"
      } | ConvertTo-Json -Depth 6 -Compress
      "[FAILURE_CONTEXT_JSON] $json" | Set-Content -Path (Join-Path $tmp "failure.log") -Encoding UTF8
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-failure-context.ps1") -LogPath (Join-Path $tmp "failure.log") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "validation passed"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "validate-failure-context rejects missing required fields" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\validate-failure-context.ps1") -Destination (Join-Path $tmp "scripts\validate-failure-context.ps1") -Force

      $json = @{
        failed_step = "contract.verify"
        exit_code = 1
        remediation_owner = "outer-ai-session"
      } | ConvertTo-Json -Depth 4 -Compress
      "[FAILURE_CONTEXT_JSON] $json" | Set-Content -Path (Join-Path $tmp "failure.log") -Encoding UTF8
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\validate-failure-context.ps1") -LogPath (Join-Path $tmp "failure.log") 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "missing_required_fields"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-safe-autopilot caps cycles by policy max_autonomous_iterations" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\automation") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "tests") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\automation\run-safe-autopilot.ps1") -Destination (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @{
        allowProjectRulesForRepos = @()
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          allow_local_optimize_without_backflow = $false
          max_autonomous_iterations = 2
          max_repeated_failure_per_step = 2
          stop_on_irreversible_risk = $true
          forbid_breaking_contract = $true
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "tests\governance-kit.optimization.tests.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -RepoRoot $tmp -MaxCycles 5 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $output | should match "capped to policy"
      $output | should match "=== cycle 2 / 2 ==="
      $output | should not match "=== cycle 3 /"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-safe-autopilot stops at repeated failure boundary with failure context" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\automation") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "tests") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\automation\run-safe-autopilot.ps1") -Destination (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @{
        allowProjectRulesForRepos = @()
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          allow_local_optimize_without_backflow = $false
          max_autonomous_iterations = 5
          max_repeated_failure_per_step = 2
          enable_no_progress_guard = $false
          max_no_progress_iterations = 2
          token_budget_mode = "lite"
          stop_on_irreversible_risk = $false
          forbid_breaking_contract = $true
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1") -Message "fail" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "tests\governance-kit.optimization.tests.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -RepoRoot $tmp -MaxCycles 5 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "AUTO-RETRY"
      $output | should match "REPEATED_FAILURE_LIMIT"
      $output | should match "\[FAILURE_CONTEXT_JSON\]"
      $output | should match "governance-kit-first"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-safe-autopilot stops early on no-progress signature boundary" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\automation") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "tests") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\automation\run-safe-autopilot.ps1") -Destination (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @{
        allowProjectRulesForRepos = @()
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          allow_local_optimize_without_backflow = $false
          max_autonomous_iterations = 5
          max_repeated_failure_per_step = 5
          enable_no_progress_guard = $true
          max_no_progress_iterations = 2
          token_budget_mode = "lite"
          stop_on_irreversible_risk = $false
          forbid_breaking_contract = $true
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1") -Message "fail" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "tests\governance-kit.optimization.tests.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -RepoRoot $tmp -MaxCycles 5 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "NO_PROGRESS_SIGNATURE_LIMIT"
      $output | should match "\[FAILURE_CONTEXT_JSON\]"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-safe-autopilot stops immediately on irreversible risk boundary" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\automation") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "tests") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\automation\run-safe-autopilot.ps1") -Destination (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @{
        allowProjectRulesForRepos = @()
        defaults = @{
          allow_auto_fix = $true
          allow_rule_optimization = $true
          allow_local_optimize_without_backflow = $false
          max_autonomous_iterations = 5
          max_repeated_failure_per_step = 5
          stop_on_irreversible_risk = $true
          forbid_breaking_contract = $true
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-rule-policy.json") -Encoding UTF8

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "tests\governance-kit.optimization.tests.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1") -Message "fail" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\doctor.ps1")

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\automation\run-safe-autopilot.ps1") -RepoRoot $tmp -MaxCycles 5 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "IRREVERSIBLE_RISK_BOUNDARY"
      $output | should match "\[FAILURE_CONTEXT_JSON\]"
      $output | should match "governance-kit-first"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "backflow-project-rules copies target project docs to repo-scoped source with backup" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "ClassroomToolkit"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ClassroomToolkit") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\backflow-project-rules.ps1") -Destination (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\AGENTS.md") -Value "old-source-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\CLAUDE.md") -Value "old-source-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\GEMINI.md") -Value "old-source-gemini" -Encoding UTF8

      Set-Content -Path (Join-Path $repo "AGENTS.md") -Value "new-target-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "CLAUDE.md") -Value "new-target-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "GEMINI.md") -Value "new-target-gemini" -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\backflow-project-rules.ps1") -RepoPath $repo -RepoName ClassroomToolkit -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "backflow-project-rules.ps1 failed with exit code $LASTEXITCODE" }

      (Get-Content -Raw (Join-Path $tmp "source\project\ClassroomToolkit\AGENTS.md")).Trim() | should be "new-target-agents"
      (Get-Content -Raw (Join-Path $tmp "source\project\ClassroomToolkit\CLAUDE.md")).Trim() | should be "new-target-claude"
      (Get-Content -Raw (Join-Path $tmp "source\project\ClassroomToolkit\GEMINI.md")).Trim() | should be "new-target-gemini"

      $backupRoots = @(Get-ChildItem -Path (Join-Path $tmp "backups") -Directory -Filter "backflow-*")
      ($backupRoots.Count -ge 1) | should be $true
      $latest = $backupRoots | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      (Test-Path (Join-Path $latest.FullName "ClassroomToolkit\source-before\AGENTS.md")) | should be $true
      (Test-Path (Join-Path $latest.FullName "ClassroomToolkit\target-snapshot\AGENTS.md")) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "analyze-repo-governance detects key governance facts and recommendations" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "RepoA"
    try {
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "tests\RepoA.Tests") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "scripts\quality") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo ".github\workflows") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "src\RepoA.App") -Force | Out-Null

      Set-Content -Path (Join-Path $repo "RepoA.sln") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "tests\RepoA.Tests\RepoA.Tests.csproj") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\quality\check-hotspot-line-budgets.ps1") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\quality\run-local-quality-gates.ps1") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo ".github\workflows\quality-gates.yml") -Value "" -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\analyze-repo-governance.ps1") -RepoPath $repo -AsJson
      if ($LASTEXITCODE -ne 0) { throw "analyze-repo-governance.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      $obj.detected.solution | should be "RepoA.sln"
      $obj.detected.test_project | should match "tests/RepoA.Tests/RepoA.Tests.csproj"
      $obj.recommended.build | should match "dotnet build RepoA.sln -c Debug"
      $obj.recommended.hotspot | should match "check-hotspot-line-budgets"
      $obj.detected.ci.github_actions | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "analyze-repo-governance prefers governance-kit PowerShell gate recommendations for script-first repos" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "GovRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $repo "scripts\quality") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "tests") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Set-Content -Path (Join-Path $repo "scripts\verify-kit.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\verify.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\validate-config.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\doctor.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\quality\run-local-quality-gates.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "tests\governance-kit.optimization.tests.ps1") -Value "describe 'x' { it 'y' { $true | should be $true } }" -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\analyze-repo-governance.ps1") -RepoPath $repo -AsJson
      if ($LASTEXITCODE -ne 0) { throw "analyze-repo-governance.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json

      $obj.recommended.build | should be "powershell -File scripts/verify-kit.ps1"
      $obj.recommended.test | should be "powershell -File tests/governance-kit.optimization.tests.ps1"
      $obj.recommended.contract_invariant | should be "powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1"
      $obj.recommended.hotspot | should be "powershell -File scripts/doctor.ps1"
      $obj.recommended.quick_gate | should be "powershell -File scripts/quality/run-local-quality-gates.ps1 -Profile quick"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "optimize-project-rules updates C2/C3/C7/C8 blocks in target docs" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "RepoB"
    try {
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "tests\RepoB.Tests") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "scripts\quality") -Force | Out-Null
      Set-Content -Path (Join-Path $repo "RepoB.sln") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "tests\RepoB.Tests\RepoB.Tests.csproj") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\quality\check-hotspot-line-budgets.ps1") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "scripts\quality\run-local-quality-gates.ps1") -Value "" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "azure-pipelines.yml") -Value "" -Encoding UTF8

      $seed = @"
# Rule
**Version**: 1.00
**Last Updated**: 2026-03-30
## 1. Guide
## A. Baseline
### A.3 N/A policy
- must record N/A reason, alternative verification, and evidence.
## B. Platform
## C. Project specifics
### C.2 Gate commands and execution order
- old
### C.3 Command presence and N/A fallback verification
- old
### C.4 Fail policy
- old
## D. Checklist
- chain complete
"@
      Set-Content -Path (Join-Path $repo "AGENTS.md") -Value $seed -Encoding UTF8
      Set-Content -Path (Join-Path $repo "CLAUDE.md") -Value $seed -Encoding UTF8
      Set-Content -Path (Join-Path $repo "GEMINI.md") -Value $seed -Encoding UTF8

      $optimizeScript = Join-Path $repoRoot "scripts\optimize-project-rules.ps1"
      & $optimizeScript -RepoPath $repo -Mode safe | Out-Null
      if (-not $?) { throw "optimize-project-rules.ps1 failed" }

      $agents = Get-Content -Raw (Join-Path $repo "AGENTS.md")
      $agents | should match "dotnet build RepoB.sln -c Debug"
      $agents | should match "### C\.7 Target-repo direct edit backflow policy"
      $agents | should match "### C\.8 CI entry differences"
      $agents | should match "azure-pipelines\.yml"
      $agents | should match "alternative_verification"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "backflow-project-rules copies configured custom files and appends target mappings" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "ClassroomToolkit"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ClassroomToolkit") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo ".github\workflows") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "docs\change-evidence") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\backflow-project-rules.ps1") -Destination (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\AGENTS.md") -Value "old-source-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\CLAUDE.md") -Value "old-source-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\GEMINI.md") -Value "old-source-gemini" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "AGENTS.md") -Value "new-target-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "CLAUDE.md") -Value "new-target-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "GEMINI.md") -Value "new-target-gemini" -Encoding UTF8

      Set-Content -Path (Join-Path $repo ".github\workflows\quality-gate.yml") -Value "name: quality-gate" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "docs\change-evidence\template.md") -Value "# template" -Encoding UTF8

      @{
        default = @()
        repos = @(
          @{
            repoName = "ClassroomToolkit"
            files = @(
              ".github/workflows/quality-gate.yml",
              "docs/change-evidence/template.md"
            )
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      @(
        @{ source = "source/project/ClassroomToolkit/AGENTS.md"; target = "$($repo -replace '\\','/')/AGENTS.md" }
      ) | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\backflow-project-rules.ps1") -RepoPath $repo -RepoName ClassroomToolkit -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "backflow-project-rules.ps1 failed with exit code $LASTEXITCODE" }

      (Test-Path (Join-Path $tmp "source\project\ClassroomToolkit\custom\.github\workflows\quality-gate.yml")) | should be $true
      (Test-Path (Join-Path $tmp "source\project\ClassroomToolkit\custom\docs\change-evidence\template.md")) | should be $true

      $targets = Get-Content -Raw (Join-Path $tmp "config\targets.json") | ConvertFrom-Json
      (@($targets | Where-Object { $_.source -eq "source/project/ClassroomToolkit/custom/.github/workflows/quality-gate.yml" })).Count | should be 1
      (@($targets | Where-Object { $_.source -eq "source/project/ClassroomToolkit/custom/docs/change-evidence/template.md" })).Count | should be 1
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "backflow-project-rules supports -SkipCustomFiles to avoid custom copy" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "ClassroomToolkit"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ClassroomToolkit") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo ".github\workflows") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\backflow-project-rules.ps1") -Destination (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\AGENTS.md") -Value "old-source-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\CLAUDE.md") -Value "old-source-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ClassroomToolkit\GEMINI.md") -Value "old-source-gemini" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "AGENTS.md") -Value "new-target-agents" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "CLAUDE.md") -Value "new-target-claude" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "GEMINI.md") -Value "new-target-gemini" -Encoding UTF8
      Set-Content -Path (Join-Path $repo ".github\workflows\quality-gate.yml") -Value "name: quality-gate" -Encoding UTF8

      @{
        default = @()
        repos = @(
          @{
            repoName = "ClassroomToolkit"
            files = @(".github/workflows/quality-gate.yml")
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      @(
        @{ source = "source/project/ClassroomToolkit/AGENTS.md"; target = "$($repo -replace '\\','/')/AGENTS.md" }
      ) | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\backflow-project-rules.ps1") -RepoPath $repo -RepoName ClassroomToolkit -Mode safe -SkipCustomFiles | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "backflow-project-rules.ps1 with -SkipCustomFiles failed with exit code $LASTEXITCODE" }

      (Test-Path (Join-Path $tmp "source\project\ClassroomToolkit\custom\.github\workflows\quality-gate.yml")) | should be $false
      $targets = Get-Content -Raw (Join-Path $tmp "config\targets.json") | ConvertFrom-Json
      (@($targets | Where-Object { $_.source -eq "source/project/ClassroomToolkit/custom/.github/workflows/quality-gate.yml" })).Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "backflow-project-rules rejects conflicting custom file switches" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "ClassroomToolkit"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ClassroomToolkit") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\backflow-project-rules.ps1") -Destination (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $repo "AGENTS.md") -Value "x" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "CLAUDE.md") -Value "x" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "GEMINI.md") -Value "x" -Encoding UTF8

      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\backflow-project-rules.ps1") -RepoPath $repo -RepoName ClassroomToolkit -Mode safe -SkipCustomFiles -IncludeCustomFiles:$true 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "Conflicting arguments"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "audit-governance-readiness writes markdown report and passes with healthy stubs" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "docs") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\audit-governance-readiness.ps1") -Destination (Join-Path $tmp "scripts\audit-governance-readiness.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-StubScript -Path (Join-Path $tmp "scripts\verify-kit.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\validate-config.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1")
      @'
param([switch]$SkipConfigValidation)
Write-Host "ok"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\verify.ps1") -Encoding UTF8

      @("E:/CODE/FakeRepo") | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/Users/sciman/.codex/AGENTS.md" }) | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{} | ConvertTo-Json -Depth 2 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      @{ version = "1.0.0"; frozen_at = "2026-03-30" } | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\governance-baseline.json") -Encoding UTF8

      $reportPath = Join-Path $tmp "docs\governance-readiness.md"
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\audit-governance-readiness.ps1") -OutPath $reportPath | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "audit-governance-readiness.ps1 failed with exit code $LASTEXITCODE" }

      (Test-Path $reportPath) | should be $true
      $report = Get-Content -Raw $reportPath
      $report | should match "overall: PASS"
      $report | should match "verify-kit\.ps1: PASS"
      $report | should match "validate-config\.ps1: PASS"
      $report | should match "verify\.ps1: PASS"
      $report | should match "check-orphan-custom-sources\.ps1: PASS"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "check-orphan-custom-sources detects orphan files and can fail in strict mode" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\RepoX\custom\scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\check-orphan-custom-sources.ps1") -Destination (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "source\project\RepoX\custom\scripts\kept.ps1") -Value "ok" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\RepoX\custom\scripts\orphan.ps1") -Value "orphan" -Encoding UTF8

      @(
        @{ source = "source/project/RepoX/custom/scripts/kept.ps1"; target = "E:/CODE/RepoX/scripts/kept.ps1" }
      ) | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      @{
        default = @()
        repos = @(
          @{
            repoName = "RepoX"
            files = @("scripts/kept.ps1")
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "check-orphan-custom-sources.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      $obj.orphan_count | should be 1
      (@($obj.items | Where-Object { $_.source -eq "source/project/RepoX/custom/scripts/orphan.ps1" })).Count | should be 1

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -FailOnOrphans | Out-Null
      $LASTEXITCODE | should be 1
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "prune-orphan-custom-sources removes orphan files with backup" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\RepoX\custom\scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\check-orphan-custom-sources.ps1") -Destination (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\prune-orphan-custom-sources.ps1") -Destination (Join-Path $tmp "scripts\prune-orphan-custom-sources.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "source\project\RepoX\custom\scripts\kept.ps1") -Value "ok" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\RepoX\custom\scripts\orphan.ps1") -Value "orphan" -Encoding UTF8

      @(
        @{ source = "source/project/RepoX/custom/scripts/kept.ps1"; target = "E:/CODE/RepoX/scripts/kept.ps1" }
      ) | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      @{
        default = @()
        repos = @(
          @{
            repoName = "RepoX"
            files = @("scripts/kept.ps1")
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      $before = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -AsJson
      (($before | ConvertFrom-Json).orphan_count) | should be 1

      $result = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\prune-orphan-custom-sources.ps1") -Mode safe -AsJson
      if ($LASTEXITCODE -ne 0) { throw "prune-orphan-custom-sources.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $result | ConvertFrom-Json
      $obj.removed | should be 1
      (Test-Path (Join-Path $tmp "source\project\RepoX\custom\scripts\orphan.ps1")) | should be $false

      $after = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -AsJson
      (($after | ConvertFrom-Json).orphan_count) | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "prune-target-orphans removes manifest-tracked orphan files and updates manifest" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "RepoX"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo ".governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "rules") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\prune-target-orphans.ps1") -Destination (Join-Path $tmp "scripts\prune-target-orphans.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @($repo) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(
        @{ source = "source/project/RepoX/custom/rules/kept.md"; target = ($repo -replace '\\', '/') + "/rules/kept.md" }
      ) | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      @'
{
  "enabled": true,
  "default_mode": "plan",
  "enforce_after_days": 14,
  "ownership": {
    "required_for_delete": true,
    "manifest_path": ".governance/distribution-state.json"
  },
  "safety_guards": {
    "max_delete_per_run": 30,
    "max_delete_ratio": 0.5,
    "block_on_unmanaged_conflict": true,
    "dry_run_required_before_safe": true
  },
  "protected_paths": [],
  "protected_globs": [],
  "gate": {
    "fail_on_delete_budget_exceeded": true,
    "fail_on_orphans_in_enforce": true
  },
  "repo_overrides": []
}
'@ | Set-Content -Path (Join-Path $tmp "config\distribution-prune-policy.json") -Encoding UTF8

      Set-Content -Path (Join-Path $repo "rules\kept.md") -Value "kept" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "rules\orphan.md") -Value "orphan" -Encoding UTF8

      @'
{
  "version": 1,
  "managed_files": [
    { "path": "rules/kept.md", "source": "source/project/RepoX/custom/rules/kept.md" },
    { "path": "rules/orphan.md", "source": "source/project/RepoX/custom/rules/orphan.md" }
  ]
}
'@ | Set-Content -Path (Join-Path $repo ".governance\distribution-state.json") -Encoding UTF8

      $result = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\prune-target-orphans.ps1") -Mode safe -AsJson
      if ($LASTEXITCODE -ne 0) { throw "prune-target-orphans.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $result | ConvertFrom-Json
      $obj.total_orphan_candidates | should be 1
      $obj.total_pruned | should be 1
      (Test-Path (Join-Path $repo "rules\orphan.md")) | should be $false
      (Test-Path (Join-Path $repo "rules\kept.md")) | should be $true

      $manifest = Get-Content -Path (Join-Path $repo ".governance\distribution-state.json") -Raw | ConvertFrom-Json
      $manifest.managed_count | should be 1
      @($manifest.managed_files | Where-Object { $_.path -eq "rules/kept.md" }).Count | should be 1
      @($manifest.managed_files | Where-Object { $_.path -eq "rules/orphan.md" }).Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "prune-target-orphans blocks by delete budget and sets should_fail_gate" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "RepoY"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo ".governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repo "rules") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\prune-target-orphans.ps1") -Destination (Join-Path $tmp "scripts\prune-target-orphans.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @($repo) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @(
        @{ source = "source/project/RepoY/custom/rules/kept.md"; target = ($repo -replace '\\', '/') + "/rules/kept.md" }
      ) | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      @'
{
  "enabled": true,
  "default_mode": "safe",
  "enforce_after_days": 14,
  "ownership": {
    "required_for_delete": true,
    "manifest_path": ".governance/distribution-state.json"
  },
  "safety_guards": {
    "max_delete_per_run": 1,
    "max_delete_ratio": 0.2,
    "block_on_unmanaged_conflict": true,
    "dry_run_required_before_safe": true
  },
  "protected_paths": [],
  "protected_globs": [],
  "gate": {
    "fail_on_delete_budget_exceeded": true,
    "fail_on_orphans_in_enforce": true
  },
  "repo_overrides": []
}
'@ | Set-Content -Path (Join-Path $tmp "config\distribution-prune-policy.json") -Encoding UTF8

      Set-Content -Path (Join-Path $repo "rules\kept.md") -Value "kept" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "rules\orphan-a.md") -Value "a" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "rules\orphan-b.md") -Value "b" -Encoding UTF8

      @'
{
  "version": 1,
  "managed_files": [
    { "path": "rules/kept.md", "source": "source/project/RepoY/custom/rules/kept.md" },
    { "path": "rules/orphan-a.md", "source": "source/project/RepoY/custom/rules/orphan-a.md" },
    { "path": "rules/orphan-b.md", "source": "source/project/RepoY/custom/rules/orphan-b.md" }
  ]
}
'@ | Set-Content -Path (Join-Path $repo ".governance\distribution-state.json") -Encoding UTF8

      $result = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\prune-target-orphans.ps1") -Mode plan -AsJson
      if ($LASTEXITCODE -ne 0) { throw "prune-target-orphans.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $result | ConvertFrom-Json
      $obj.total_orphan_candidates | should be 2
      $obj.total_pruned | should be 0
      $obj.should_fail_gate | should be $true
      [int]$obj.repos[0].skipped_budget | should be 2
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "install fails fast when script lock cannot be acquired" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $hold = $null
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp ".locks") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\install.ps1") -Destination (Join-Path $tmp "scripts\install.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $src = Join-Path $tmp "source\AGENTS.md"
      Set-Content -Path $src -Value "x" -Encoding UTF8
      @(@{ source = "source/AGENTS.md"; target = (Join-Path $tmp "target\AGENTS.md") }) | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      $hold = [System.IO.File]::Open((Join-Path $tmp ".locks\install.lock"), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\install.ps1") -Mode plan -LockTimeoutSeconds 1 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "Failed to acquire script lock 'install'"
    } finally {
      if ($null -ne $hold) { $hold.Dispose() }
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "backflow fails fast when script lock cannot be acquired" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "ClassroomToolkit"
    $hold = $null
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ClassroomToolkit") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp ".locks") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\backflow-project-rules.ps1") -Destination (Join-Path $tmp "scripts\backflow-project-rules.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $repo "AGENTS.md") -Value "x" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "CLAUDE.md") -Value "x" -Encoding UTF8
      Set-Content -Path (Join-Path $repo "GEMINI.md") -Value "x" -Encoding UTF8

      $hold = [System.IO.File]::Open((Join-Path $tmp ".locks\backflow-project-rules.lock"), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\backflow-project-rules.ps1") -RepoPath $repo -RepoName ClassroomToolkit -Mode plan -SkipCustomFiles -LockTimeoutSeconds 1 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "Failed to acquire script lock 'backflow-project-rules'"
    } finally {
      if ($null -ne $hold) { $hold.Dispose() }
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "restore fails fast when script lock cannot be acquired" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $hold = $null
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\20260101-000000\C\temp") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp ".locks") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\restore.ps1") -Destination (Join-Path $tmp "scripts\restore.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "backups\20260101-000000\C\temp\x.txt") -Value "x" -Encoding UTF8
      @(@{ source = "source/global/AGENTS.md"; target = "C:/temp/x.txt" }) | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8

      $hold = [System.IO.File]::Open((Join-Path $tmp ".locks\restore.lock"), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\restore.ps1") -LockTimeoutSeconds 1 2>&1 | Out-String
      $LASTEXITCODE | should be 1
      $output | should match "Failed to acquire script lock 'restore'"
    } finally {
      if ($null -ne $hold) { $hold.Dispose() }
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "prune-backups supports plan mode without deleting directories" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\a") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\b") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\c") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\prune-backups.ps1") -Destination (Join-Path $tmp "scripts\prune-backups.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      (Get-Item (Join-Path $tmp "backups\a")).LastWriteTime = (Get-Date).AddDays(-20)
      (Get-Item (Join-Path $tmp "backups\b")).LastWriteTime = (Get-Date).AddDays(-10)
      (Get-Item (Join-Path $tmp "backups\c")).LastWriteTime = (Get-Date).AddDays(-1)

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\prune-backups.ps1") -Mode plan -RetainDays 0 -RetainCount 1 -AsJson
      if ($LASTEXITCODE -ne 0) { throw "prune-backups.ps1 plan failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      $obj.removed | should be 0
      (@($obj.actions | Where-Object { $_.action -eq "PLAN_PRUNE" }).Count -ge 2) | should be $true
      (Test-Path (Join-Path $tmp "backups\a")) | should be $true
      (Test-Path (Join-Path $tmp "backups\b")) | should be $true
      (Test-Path (Join-Path $tmp "backups\c")) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "prune-backups removes expired backup directories in safe mode" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\a") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\b") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\c") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\prune-backups.ps1") -Destination (Join-Path $tmp "scripts\prune-backups.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      (Get-Item (Join-Path $tmp "backups\a")).LastWriteTime = (Get-Date).AddDays(-20)
      (Get-Item (Join-Path $tmp "backups\b")).LastWriteTime = (Get-Date).AddDays(-10)
      (Get-Item (Join-Path $tmp "backups\c")).LastWriteTime = (Get-Date).AddDays(-1)

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\prune-backups.ps1") -Mode safe -RetainDays 0 -RetainCount 1 -AsJson
      if ($LASTEXITCODE -ne 0) { throw "prune-backups.ps1 safe failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      $obj.removed | should be 2
      (Test-Path (Join-Path $tmp "backups\c")) | should be $true
      (Test-Path (Join-Path $tmp "backups\a")) | should be $false
      (Test-Path (Join-Path $tmp "backups\b")) | should be $false
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "prune-backups keeps protected prefix directories even when expired" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\backflow-aaa") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "backups\old-normal") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\prune-backups.ps1") -Destination (Join-Path $tmp "scripts\prune-backups.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      (Get-Item (Join-Path $tmp "backups\backflow-aaa")).LastWriteTime = (Get-Date).AddDays(-90)
      (Get-Item (Join-Path $tmp "backups\old-normal")).LastWriteTime = (Get-Date).AddDays(-90)

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\prune-backups.ps1") -Mode safe -RetainDays 0 -RetainCount 0 -ProtectPrefixes backflow- -AsJson
      if ($LASTEXITCODE -ne 0) { throw "prune-backups.ps1 protect prefix failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json

      (Test-Path (Join-Path $tmp "backups\backflow-aaa")) | should be $true
      (Test-Path (Join-Path $tmp "backups\old-normal")) | should be $false
      (@($obj.actions | Where-Object { $_.path -like "*backflow-aaa" -and $_.reason -like "prefix*" }).Count -ge 1) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "verify-json-contract validates schema fields and versions" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\verify-json-contract.ps1") -Destination (Join-Path $tmp "scripts\verify-json-contract.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param([switch]$AsJson)
if ($AsJson) {
  @{ schema_version="1.0"; repositories=1; targets=1; repos=@(); global_home_targets=1; missing_repositories=0; orphan_targets=0; rollout=$null; codex_runtime=@{ policy_found=$false; enabled_by_default=$false; policy_repo_entries=0; enabled_repo_entries=0; codex_target_mappings=0; codex_home_target_mappings=0; codex_repo_target_mappings=0 }; core_health=@{ score=100; level="GREEN"; reasons=@() }; warnings=@() } | ConvertTo-Json -Depth 6 | Write-Output
  exit 0
}
'@ | Set-Content -Path (Join-Path $tmp "scripts\status.ps1") -Encoding UTF8

      @'
param([switch]$AsJson)
if ($AsJson) {
  @{ schema_version="1.0"; default_phase="observe"; default_block_expired_waiver=$false; observe=1; enforce=0; observe_overdue=0; repos=@(); warnings=@() } | ConvertTo-Json -Depth 6 | Write-Output
  exit 0
}
'@ | Set-Content -Path (Join-Path $tmp "scripts\rollout-status.ps1") -Encoding UTF8

      @'
param([switch]$AsJson)
if ($AsJson) {
  @{ schema_version="1.0"; generated_at="2026-04-02 00:00:00"; health="GREEN"; failed_steps=@(); skipped_steps=@(); steps=@() } | ConvertTo-Json -Depth 6 | Write-Output
  exit 0
}
'@ | Set-Content -Path (Join-Path $tmp "scripts\doctor.ps1") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\verify-json-contract.ps1") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "verify-json-contract.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      $obj.status | should be "PASS"
      $obj.expected_schema_version | should be "1.0"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-real-repo-regression supports plan and smoke modes with matrix config" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repoA = Join-Path $tmp "RepoA"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path $repoA -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $repoA "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\run-real-repo-regression.ps1") -Destination (Join-Path $tmp "scripts\run-real-repo-regression.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $repoA "AGENTS.md") -Value "x" -Encoding UTF8
      Set-Content -Path (Join-Path $repoA "scripts\smoke.ps1") -Value "param(); Write-Host 'ok'; exit 0" -Encoding UTF8

      @{
        schema_version = "1.0"
        repos = @(
          @{
            repo_name = "RepoA"
            repo = ($repoA -replace '\\','/')
            required_paths = @("AGENTS.md", "scripts/smoke.ps1")
            smoke_command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke.ps1"
            full_command = ""
          },
          @{
            repo_name = "RepoMissing"
            repo = ((Join-Path $tmp "MissingRepo") -replace '\\','/')
            required_paths = @("AGENTS.md")
            smoke_command = ""
            full_command = ""
          }
        )
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "matrix.json") -Encoding UTF8

      $plan = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-real-repo-regression.ps1") -Mode plan -MatrixPath (Join-Path $tmp "matrix.json") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "run-real-repo-regression plan failed with exit code $LASTEXITCODE" }
      $planObj = $plan | ConvertFrom-Json
      $planObj.status | should be "PASS"
      $planObj.total | should be 2

      $smoke = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\run-real-repo-regression.ps1") -Mode smoke -MatrixPath (Join-Path $tmp "matrix.json") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "run-real-repo-regression smoke failed with exit code $LASTEXITCODE" }
      $smokeObj = $smoke | ConvertFrom-Json
      $smokeObj.status | should be "PASS"
      (@($smokeObj.results | Where-Object { $_.repo_name -eq "RepoA" -and $_.status -eq "PASS" }).Count -eq 1) | should be $true
      (@($smokeObj.results | Where-Object { $_.repo_name -eq "RepoMissing" -and $_.status -eq "SKIP" }).Count -eq 1) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common Invoke-ChildScriptCapture returns script output and enforces exit code" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param()
Write-Output "hello-from-child"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "ok.ps1") -Encoding UTF8

      @'
param()
Write-Output "bad"
exit 7
'@ | Set-Content -Path (Join-Path $tmp "fail.ps1") -Encoding UTF8

      . (Join-Path $tmp "scripts\lib\common.ps1")
      $okOut = Invoke-ChildScriptCapture -ScriptPath (Join-Path $tmp "ok.ps1")
      (($okOut | Out-String).Trim()) | should be "hello-from-child"

      $thrown = $false
      try {
        Invoke-ChildScriptCapture -ScriptPath (Join-Path $tmp "fail.ps1") | Out-Null
      } catch {
        $thrown = $true
      }
      $thrown | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common Assert-Command and Invoke-LoggedCommand provide shared command guards" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "logs") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      . (Join-Path $tmp "scripts\lib\common.ps1")

      Assert-Command -Name powershell

      $missingThrown = $false
      try {
        Assert-Command -Name "govkit-definitely-missing-command"
      } catch {
        $missingThrown = $true
      }
      $missingThrown | should be $true

      $result = Invoke-LoggedCommand -Name "unit.test.log" -WorkDir $tmp -LogRoot (Join-Path $tmp "logs") -Action {
        & powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Output 'hello-log'; exit 0"
      }
      $result.exit_code | should be 0
      (Test-Path -LiteralPath $result.log_path) | should be $true
      ((Get-Content -LiteralPath $result.log_path -Raw) -match "hello-log") | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common Invoke-LoggedCommand creates missing log directory automatically" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      . (Join-Path $tmp "scripts\lib\common.ps1")

      $logRoot = Join-Path $tmp "nested\logs\autocreate"
      (Test-Path -LiteralPath $logRoot) | should be $false

      $result = Invoke-LoggedCommand -Name "unit.test.autocreate" -WorkDir $tmp -LogRoot $logRoot -Action {
        & powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Output 'auto-log'; exit 0"
      }

      $result.exit_code | should be 0
      (Test-Path -LiteralPath $logRoot) | should be $true
      (Test-Path -LiteralPath $result.log_path) | should be $true
      ((Get-Content -LiteralPath $result.log_path -Raw) -match "auto-log") | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common Invoke-CommandCapture returns stable fields for success and failure probes" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param()
Write-Output "cap-ok"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "ok.ps1") -Encoding UTF8

      @'
param()
Write-Error "cap-fail"
exit 7
'@ | Set-Content -Path (Join-Path $tmp "fail.ps1") -Encoding UTF8

      . (Join-Path $tmp "scripts\lib\common.ps1")

      $okCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$($tmp -replace '\\','/')/ok.ps1`""
      $ok = Invoke-CommandCapture -Command $okCmd -HeadLines 1 -IncludeTimestamp
      $ok.exit_code | should be 0
      $ok.key_output | should match "cap-ok"
      ([string]::IsNullOrWhiteSpace([string]$ok.timestamp)) | should be $false

      $failCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$($tmp -replace '\\','/')/fail.ps1`""
      $fail = Invoke-CommandCapture -Command $failCmd -HeadLines 1
      $fail.exit_code | should not be 0
      $fail.raw_output | should match "cap-fail"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "add-repo prefers repo-scoped custom source when available" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "ScopedCustomRepo"
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ScopedCustomRepo\custom\docs") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\_common\custom\docs") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\ScopedCustomRepo") -Force | Out-Null
      New-Item -ItemType Directory -Path $repo -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\add-repo.ps1") -Destination (Join-Path $tmp "scripts\add-repo.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-MinProjectRulePolicy -ConfigDir (Join-Path $tmp "config") -RepoPath $repo
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @() | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @("docs/PLANS.md")
        repos = @(
          @{
            repoName = "ScopedCustomRepo"
            files = @("docs/PLANS.md")
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "source\project\ScopedCustomRepo\AGENTS.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ScopedCustomRepo\CLAUDE.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ScopedCustomRepo\GEMINI.md") -Value "scoped" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\ScopedCustomRepo\custom\docs\PLANS.md") -Value "repo-scoped-plans" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "source\project\_common\custom\docs\PLANS.md") -Value "common-plans" -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\add-repo.ps1") -RepoPath $repo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "add-repo.ps1 failed with exit code $LASTEXITCODE" }

      $targets = Get-Content -Raw (Join-Path $tmp "config\targets.json") | ConvertFrom-Json
      (@($targets | Where-Object { $_.source -eq "source/project/ScopedCustomRepo/custom/docs/PLANS.md" })).Count | should be 1
      (@($targets | Where-Object { $_.source -eq "source/project/_common/custom/docs/PLANS.md" -and $_.target -eq "$(($repo -replace '\\','/'))/docs/PLANS.md" })).Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common Test-FileContentEqual and hash cache stay correct after file updates" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $a = Join-Path $tmp "a.txt"
      $b = Join-Path $tmp "b.txt"
      $c = Join-Path $tmp "c.txt"
      Set-Content -Path $a -Value "same-content" -Encoding UTF8
      Set-Content -Path $b -Value "same-content" -Encoding UTF8
      Set-Content -Path $c -Value "different-content-longer" -Encoding UTF8

      . (Join-Path $tmp "scripts\lib\common.ps1")

      (Test-FileContentEqual -PathA $a -PathB $b) | should be $true
      (Test-FileContentEqual -PathA $a -PathB $c) | should be $false

      $hash1 = Get-FileSha256 -Path $a
      Start-Sleep -Milliseconds 30
      Set-Content -Path $a -Value "same-content-updated" -Encoding UTF8
      $hash2 = Get-FileSha256 -Path $a
      $hash1 | should not be $hash2

      $jsonPath = Join-Path $tmp "cache.json"
      '{"value":"old"}' | Set-Content -Path $jsonPath -Encoding UTF8
      $json1 = Read-JsonFile -Path $jsonPath -UseCache
      '{"value":"newer-value"}' | Set-Content -Path $jsonPath -Encoding UTF8
      $json2 = Read-JsonFile -Path $jsonPath -UseCache
      ([string]$json1.value) | should be "old"
      ([string]$json2.value) | should be "newer-value"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common release and clarification helpers provide shared governance primitives" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tmp "RepoA"
    try {
      New-Item -ItemType Directory -Path $repo -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Initialize-ClarificationTrackerFixture -TmpRoot $tmp
      Set-MinReleaseDistributionPolicy -ConfigDir (Join-Path $tmp "config")
      Set-MinPracticeStackPolicy -ConfigDir (Join-Path $tmp "config") -RepoName "FakeRepo"

      . (Join-Path $tmp "scripts\lib\common.ps1")

      $policy = Get-ReleaseDistributionPolicy -KitRoot $tmp
      $repoPolicy = Get-ReleaseDistributionPolicyForRepo -Policy $policy -RepoName "FakeRepo"
      $defaultPolicy = Get-ReleaseDistributionPolicyForRepo -Policy $policy -RepoName "MissingRepo" -FallbackToDefault
      $repoPolicy.repoName | should be "FakeRepo"
      ([string]$defaultPolicy.packaging.default_channel) | should be "none"

      $ctx = Join-Path $tmp "clarification-context.json"
      @'
{"clarification_scenario":"requirement"}
'@ | Set-Content -Path $ctx -Encoding UTF8

      $resolved = Resolve-EffectiveClarificationScenario -RequestedScenario "auto" -ContextFile $ctx -CurrentMode "safe"
      ([string]$resolved.scenario) | should be "requirement"
      ([string]$resolved.source) | should be "context_file"

      $invalidRequested = Resolve-EffectiveClarificationScenario -RequestedScenario "not-a-scenario" -CurrentMode "safe"
      ([string]$invalidRequested.scenario) | should be "bugfix"
      ([string]$invalidRequested.source) | should be "fallback"

      $trackerScript = Join-Path $tmp "scripts\governance\track-issue-state.ps1"
      $evalState = Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repo -IssueId "T-1" -Scenario "bugfix" -Mode "evaluate" -PowerShellPath "powershell"
      ([bool]$evalState.clarification_required) | should be $false

      Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repo -IssueId "T-1" -Scenario "bugfix" -Mode "record" -Outcome "failure" -Reason "fail-1" -PowerShellPath "powershell" | Out-Null
      $state2 = Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repo -IssueId "T-1" -Scenario "bugfix" -Mode "record" -Outcome "failure" -Reason "fail-2" -PowerShellPath "powershell"
      ([bool]$state2.clarification_required) | should be $true

      $missingTrackerThrown = $false
      try {
        Invoke-ClarificationTracker -TrackerScript (Join-Path $tmp "missing-tracker.ps1") -RepoPath $repo -IssueId "T-2" -Scenario "bugfix" -Mode "evaluate" -PowerShellPath "powershell" | Out-Null
      } catch {
        $missingTrackerThrown = $true
      }
      $missingTrackerThrown | should be $true

      $missingPowerShellThrown = $false
      try {
        Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repo -IssueId "T-3" -Scenario "bugfix" -Mode "evaluate" -PowerShellPath "pwsh-definitely-missing" | Out-Null
      } catch {
        $missingPowerShellThrown = $true
      }
      $missingPowerShellThrown | should be $true

      $fakeCmd = Join-Path $tmp "fake-powershell.cmd"
      @'
@echo {"not":"json"
@exit /b 0
'@ | Set-Content -Path $fakeCmd -Encoding ASCII

      $invalidJsonThrown = $false
      try {
        Invoke-ClarificationTracker -TrackerScript $trackerScript -RepoPath $repo -IssueId "T-4" -Scenario "bugfix" -Mode "evaluate" -PowerShellPath $fakeCmd | Out-Null
      } catch {
        $invalidJsonThrown = $true
      }
      $invalidJsonThrown | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "doctor fallback runner works when common helper is missing" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\doctor.ps1") -Destination (Join-Path $tmp "scripts\doctor.ps1") -Force

      @'
param()
Write-Host "governance-kit integrity OK"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\verify-kit.ps1") -Encoding UTF8

      @'
param()
Write-Host "Config validation passed. repositories=1 targets=1 rolloutRepos=1"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\validate-config.ps1") -Encoding UTF8

      @'
param()
Write-Host "release profile coverage OK"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\check-release-profile-coverage.ps1") -Encoding UTF8

      @'
param([switch]$SkipConfigValidation)
Write-Host "Verify done. ok=1 fail=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\verify.ps1") -Encoding UTF8

      @'
param()
Write-Host "Waiver check done. files=0 expired=0 blocked=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\check-waivers.ps1") -Encoding UTF8

      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      @'
param()
Write-Host "practice stack ok"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\governance\check-practice-stack.ps1") -Encoding UTF8

      @'
param()
Write-Host "anti bloat ok"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\governance\check-anti-bloat-budgets.ps1") -Encoding UTF8

      @'
param()
Write-Host "status ok"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\status.ps1") -Encoding UTF8

      @'
param()
Write-Host "phase.observe_overdue=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\rollout-status.ps1") -Encoding UTF8

      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      @('E:/CODE/governance-kit') | ConvertTo-Json | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8

      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\doctor.ps1") 2>&1 | Out-String
      $LASTEXITCODE | should be 0
      $out | should match "HEALTH=GREEN"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-recurring-review writes alert snapshot when alerts exist" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "docs\governance") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\run-recurring-review.ps1") -Destination (Join-Path $tmp "scripts\governance\run-recurring-review.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-update-triggers.ps1") -Destination (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param()
Write-Host "HEALTH=RED"
exit 1
'@ | Set-Content -Path (Join-Path $tmp "scripts\doctor.ps1") -Encoding UTF8

      @'
param()
Write-Host "phase.observe_overdue=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\rollout-status.ps1") -Encoding UTF8

      @'
param()
Write-Host "Waiver check done. files=0 expired=0 blocked=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\check-waivers.ps1") -Encoding UTF8

      @'
param()
Write-Host "collect-governance-metrics done"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\collect-governance-metrics.ps1") -Encoding UTF8

      @'
param()
Write-Output (@{
  schema_version = "1.0"
  status = "OK"
  alert_count = 0
  alerts = @()
} | ConvertTo-Json -Depth 6)
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\run-recurring-review.ps1") -RepoRoot $tmp -NoNotifyOnAlert -AsJson
      $LASTEXITCODE | should be 1
      $obj = $json | ConvertFrom-Json
      $obj.ok | should be $false
      (Test-Path (Join-Path $tmp "docs\governance\alerts-latest.md")) | should be $true
      ((Get-Content -Path (Join-Path $tmp "docs\governance\alerts-latest.md") -Raw) -match "status=ALERT") | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "run-monthly-policy-review generates monthly review markdown" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "docs\governance") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\run-recurring-review.ps1") -Destination (Join-Path $tmp "scripts\governance\run-recurring-review.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-update-triggers.ps1") -Destination (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\run-monthly-policy-review.ps1") -Destination (Join-Path $tmp "scripts\governance\run-monthly-policy-review.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param()
Write-Host "HEALTH=GREEN"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\doctor.ps1") -Encoding UTF8

      @'
param()
Write-Host "phase.observe_overdue=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\rollout-status.ps1") -Encoding UTF8

      @'
param()
Write-Host "Waiver check done. files=0 expired=0 blocked=0"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\check-waivers.ps1") -Encoding UTF8

      @'
param()
Write-Host "collect-governance-metrics done"
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\collect-governance-metrics.ps1") -Encoding UTF8

      @'
param()
Write-Output (@{
  schema_version = "1.0"
  status = "OK"
  alert_count = 0
  alerts = @()
} | ConvertTo-Json -Depth 6)
exit 0
'@ | Set-Content -Path (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\run-monthly-policy-review.ps1") -RepoRoot $tmp -Period "2026-04" -AsJson
      if ($LASTEXITCODE -ne 0) { throw "run-monthly-policy-review failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      $obj.status | should be "OK"
      (Test-Path (Join-Path $tmp "docs\governance\reviews\2026-04-monthly-review.md")) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "check-update-triggers reports low-value orphan custom sources" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\RepoA\custom") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "docs\governance") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-update-triggers.ps1") -Destination (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\check-orphan-custom-sources.ps1") -Destination (Join-Path $tmp "scripts\check-orphan-custom-sources.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      Set-Content -Path (Join-Path $tmp "source\project\RepoA\custom\orphan.txt") -Value "x" -Encoding UTF8
      "[]" | Set-Content -Path (Join-Path $tmp "config\targets.json") -Encoding UTF8
      @{
        default = @()
        repos = @(
          @{
            repoName = "RepoA"
            files = @()
          }
        )
      } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $tmp "config\project-custom-files.json") -Encoding UTF8
      @{
        schema_version = "1.0"
        cadence = @{
          recurring_review_days = 7
          monthly_review_day = 1
        }
        triggers = @{
          cli_version_drift = @{ enabled = $false; severity = "high" }
          rollout_observe_overdue = @{ enabled = $false; severity = "medium" }
          metrics_snapshot_stale = @{ enabled = $false; severity = "medium"; max_age_days = 8 }
          waiver_expired_unrecovered = @{ enabled = $false; severity = "high" }
          platform_na_expired = @{ enabled = $false; severity = "medium" }
          low_value_orphan_custom_sources = @{ enabled = $true; severity = "medium" }
        }
      } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $tmp "config\update-trigger-policy.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -RepoRoot $tmp -AsJson
      $LASTEXITCODE | should be 1
      $obj = $json | ConvertFrom-Json
      $obj.alert_count | should be 1
      $obj.orphan_custom_source_count | should be 1
      @($obj.alerts | Where-Object { $_.id -eq "low_value_orphan_custom_sources" }).Count | should be 1
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "check-update-triggers reports release-distribution-policy drift" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "source\project\RepoA\custom\.governance") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-update-triggers.ps1") -Destination (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      $repoAPath = Join-Path $tmp "RepoA"
      New-Item -ItemType Directory -Path $repoAPath -Force | Out-Null
      @($repoAPath) | ConvertTo-Json | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @'
{
  "schema_version": "1.0",
  "default": {
    "signing": { "required": false, "mode": "none-personal", "allow_paid_signing": false },
    "packaging": {
      "default_channel": "none",
      "channels": ["none"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    }
  },
  "repos": [
    {
      "repoName": "RepoA",
      "signing": { "required": false, "mode": "none-personal", "allow_paid_signing": false },
      "packaging": {
        "default_channel": "none",
        "channels": ["none"],
        "distribution_forms": ["portable"],
        "network_modes": ["online"],
        "require_framework_dependent": false,
        "require_self_contained": false
      }
    }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\release-distribution-policy.json") -Encoding UTF8

      $profileText = @'
{
  "schema_version": "1.0",
  "repo": {
    "name": "RepoA",
    "path": "__REPO_A_PATH__",
    "release_enabled": false
  },
  "policies": {
    "signing": { "required": false, "mode": "none-personal", "allow_paid_signing": false },
    "packaging": {
      "default_channel": "standard",
      "channels": ["standard"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    }
  }
}
'@
      $profileText = $profileText.Replace("__REPO_A_PATH__", ($repoAPath -replace "\\", "/"))
      Set-Content -Path (Join-Path $tmp "source\project\RepoA\custom\.governance\release-profile.json") -Value $profileText -Encoding UTF8

      @'
{
  "schema_version": "1.0",
  "cadence": { "recurring_review_days": 7, "monthly_review_day": 1 },
  "triggers": {
    "cli_version_drift": { "enabled": false, "severity": "high" },
    "rollout_observe_overdue": { "enabled": false, "severity": "medium" },
    "metrics_snapshot_stale": { "enabled": false, "severity": "medium", "max_age_days": 8 },
    "waiver_expired_unrecovered": { "enabled": false, "severity": "high" },
    "platform_na_expired": { "enabled": false, "severity": "medium" },
    "release_distribution_policy_drift": { "enabled": true, "severity": "high" },
    "low_value_orphan_custom_sources": { "enabled": false, "severity": "medium" }
  }
}
'@ | Set-Content -Path (Join-Path $tmp "config\update-trigger-policy.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\check-update-triggers.ps1") -RepoRoot $tmp -AsJson
      $LASTEXITCODE | should be 1
      $obj = $json | ConvertFrom-Json
      $obj.release_distribution_policy_drift_count | should be 1
      @($obj.alerts | Where-Object { $_.id -eq "release_distribution_policy_drift" }).Count | should be 1
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "common Get-CodexRuntimeFilesForRepo respects policy default disabled and repo opt-in" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
{
  "schema_version": "1.0",
  "enabled_by_default": false,
  "default_files": [
    ".codex/config.toml",
    ".codex/agents/planner.toml"
  ],
  "repos": [
    { "repoName": "RepoA", "enabled": true }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\codex-runtime-policy.json") -Encoding UTF8

      . (Join-Path $tmp "scripts\lib\common.ps1")
      $repoA = Join-Path $tmp "RepoA"
      $repoB = Join-Path $tmp "RepoB"
      New-Item -ItemType Directory -Path $repoA -Force | Out-Null
      New-Item -ItemType Directory -Path $repoB -Force | Out-Null

      $filesA = @(Get-CodexRuntimeFilesForRepo -KitRoot $tmp -RepoPath $repoA -RepoName "RepoA")
      $filesB = @(Get-CodexRuntimeFilesForRepo -KitRoot $tmp -RepoPath $repoB -RepoName "RepoB")

      $filesA.Count | should be 2
      ($filesA -contains ".codex/config.toml") | should be $true
      $filesB.Count | should be 0
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "set-codex-runtime-policy updates repoName entry enabled flag" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\set-codex-runtime-policy.ps1") -Destination (Join-Path $tmp "scripts\set-codex-runtime-policy.ps1") -Force

      @'
{
  "schema_version": "1.0",
  "enabled_by_default": false,
  "default_files": [".codex/config.toml"],
  "repos": [
    { "repoName": "RepoA", "enabled": false }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\codex-runtime-policy.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\set-codex-runtime-policy.ps1") -RepoName RepoA -Enabled true -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "set-codex-runtime-policy.ps1 failed with exit code $LASTEXITCODE" }

      $obj = Get-Content -Path (Join-Path $tmp "config\codex-runtime-policy.json") -Raw | ConvertFrom-Json
      $entry = @($obj.repos | Where-Object { $_.repoName -eq "RepoA" })[0]
      [bool]$entry.enabled | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "set-codex-runtime-policy adds repoName entry when missing" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\set-codex-runtime-policy.ps1") -Destination (Join-Path $tmp "scripts\set-codex-runtime-policy.ps1") -Force

      @'
{
  "schema_version": "1.0",
  "enabled_by_default": false,
  "default_files": [".codex/config.toml"],
  "repos": []
}
'@ | Set-Content -Path (Join-Path $tmp "config\codex-runtime-policy.json") -Encoding UTF8

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\set-codex-runtime-policy.ps1") -RepoName RepoB -Enabled true -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "set-codex-runtime-policy.ps1 failed with exit code $LASTEXITCODE" }

      $obj = Get-Content -Path (Join-Path $tmp "config\codex-runtime-policy.json") -Raw | ConvertFrom-Json
      $entry = @($obj.repos | Where-Object { $_.repoName -eq "RepoB" })[0]
      [bool]$entry.enabled | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "verify-release-profile rejects paid signing mode" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA\.governance") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\verify-release-profile.ps1") -Destination (Join-Path $tmp "scripts\verify-release-profile.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
{
  "schema_version": "1.0",
  "project_type": "generic",
  "release_enabled": false,
  "owner": "RepoA",
  "classification": {
    "release_decision": "disabled-no-release-signals",
    "detected_release_signals": []
  },
  "policies": {
    "signing": {
      "required": false,
      "mode": "ev-paid",
      "allow_paid_signing": true
    },
    "compatibility": {
      "matrix_required": false,
      "minimum_os": ["Windows 10 22H2"],
      "architectures": ["x64"]
    },
    "packaging": {
      "default_channel": "none",
      "channels": ["none"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    },
    "anti_false_positive": {
      "prefer_zip": false,
      "disallow_self_extracting_archive": false,
      "disallow_obfuscation": false,
      "disallow_runtime_downloader": false
    },
    "traceability": {
      "require_sha256": false,
      "require_release_manifest": false,
      "require_changelog": false
    }
  },
  "gates": {
    "build": "echo ok",
    "test": "echo ok",
    "contract_invariant": "echo ok",
    "hotspot": "echo ok"
  },
  "release": {
    "preflight": "N/A",
    "prepare": "N/A",
    "workflow_files": [],
    "output_root": "artifacts/release",
    "manifest": "artifacts/release/<version>/release-manifest.json"
  }
}
'@ | Set-Content -Path (Join-Path $tmp "RepoA\.governance\release-profile.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\verify-release-profile.ps1") -RepoPath (Join-Path $tmp "RepoA") -AsJson
      $LASTEXITCODE | should be 1
      $obj = $json | ConvertFrom-Json
      $obj.status | should be "FAIL"
      (@($obj.errors | Where-Object { $_ -match "allow_paid_signing must be false" }).Count -ge 1) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "suggest-release-profile emits packaging forms and no-paid-signing policy" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA\scripts\release") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA\docs\runbooks") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\suggest-release-profile.ps1") -Destination (Join-Path $tmp "scripts\suggest-release-profile.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param([Parameter(Mandatory = $true)][string]$RepoPath,[switch]$AsJson)
if ($AsJson) {
  @{ recommended = @{ build = "echo build"; test = "echo test"; contract_invariant = "echo contract"; hotspot = "echo hotspot" } } | ConvertTo-Json -Depth 6 | Write-Output
  exit 0
}
'@ | Set-Content -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1") -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "RepoA\scripts\release\prepare-distribution.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "RepoA\scripts\release\preflight-check.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "RepoA\docs\runbooks\release-prevention-checklist.md") -Value "# checklist" -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\suggest-release-profile.ps1") -RepoPath (Join-Path $tmp "RepoA") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "suggest-release-profile.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      (@($obj.profile.policies.packaging.distribution_forms) -contains "installer") | should be $true
      (@($obj.profile.policies.packaging.distribution_forms) -contains "portable") | should be $true
      (@($obj.profile.policies.packaging.network_modes) -contains "online") | should be $true
      (@($obj.profile.policies.packaging.network_modes) -contains "offline") | should be $true
      [bool]$obj.profile.policies.signing.allow_paid_signing | should be $false
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "suggest-release-profile honors release-distribution-policy signing override" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA\scripts\release") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA\docs\runbooks") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\suggest-release-profile.ps1") -Destination (Join-Path $tmp "scripts\suggest-release-profile.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
param([Parameter(Mandatory = $true)][string]$RepoPath,[switch]$AsJson)
if ($AsJson) {
  @{ recommended = @{ build = "echo build"; test = "echo test"; contract_invariant = "echo contract"; hotspot = "echo hotspot" } } | ConvertTo-Json -Depth 6 | Write-Output
  exit 0
}
'@ | Set-Content -Path (Join-Path $tmp "scripts\analyze-repo-governance.ps1") -Encoding UTF8

      @'
{
  "schema_version": "1.0",
  "default": {
    "signing": { "required": false, "mode": "none-personal", "allow_paid_signing": false },
    "packaging": {
      "default_channel": "none",
      "channels": ["none"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    }
  },
  "repos": [
    {
      "repoName": "RepoA",
      "signing": { "required": false, "mode": "none-personal-custom", "allow_paid_signing": false },
      "packaging": {
        "default_channel": "standard",
        "channels": ["standard", "offline"],
        "distribution_forms": ["installer", "portable"],
        "network_modes": ["online", "offline"],
        "require_framework_dependent": true,
        "require_self_contained": true
      }
    }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\release-distribution-policy.json") -Encoding UTF8

      Set-Content -Path (Join-Path $tmp "RepoA\scripts\release\prepare-distribution.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "RepoA\scripts\release\preflight-check.ps1") -Value "param(); Write-Host ok" -Encoding UTF8
      Set-Content -Path (Join-Path $tmp "RepoA\docs\runbooks\release-prevention-checklist.md") -Value "# checklist" -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\suggest-release-profile.ps1") -RepoPath (Join-Path $tmp "RepoA") -AsJson
      if ($LASTEXITCODE -ne 0) { throw "suggest-release-profile.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      [string]$obj.profile.policies.signing.mode | should be "none-personal-custom"
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "verify-release-profile enforces release-distribution-policy consistency" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA\.governance") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\verify-release-profile.ps1") -Destination (Join-Path $tmp "scripts\verify-release-profile.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @'
{
  "schema_version": "1.0",
  "default": {
    "signing": { "required": false, "mode": "none-personal", "allow_paid_signing": false },
    "packaging": {
      "default_channel": "none",
      "channels": ["none"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    }
  },
  "repos": [
    {
      "repoName": "RepoA",
      "signing": { "required": false, "mode": "none-personal-policy", "allow_paid_signing": false },
      "packaging": {
        "default_channel": "none",
        "channels": ["none"],
        "distribution_forms": ["portable"],
        "network_modes": ["online"],
        "require_framework_dependent": false,
        "require_self_contained": false
      }
    }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\release-distribution-policy.json") -Encoding UTF8

      @'
{
  "schema_version": "1.0",
  "project_type": "generic",
  "release_enabled": false,
  "owner": "RepoA",
  "classification": {
    "release_decision": "disabled-no-release-signals",
    "detected_release_signals": []
  },
  "policies": {
    "signing": {
      "required": false,
      "mode": "none-personal",
      "allow_paid_signing": false
    },
    "compatibility": {
      "matrix_required": false,
      "minimum_os": ["Windows 10 22H2"],
      "architectures": ["x64"]
    },
    "packaging": {
      "default_channel": "none",
      "channels": ["none"],
      "distribution_forms": ["portable"],
      "network_modes": ["online"],
      "require_framework_dependent": false,
      "require_self_contained": false
    },
    "anti_false_positive": {
      "prefer_zip": false,
      "disallow_self_extracting_archive": false,
      "disallow_obfuscation": false,
      "disallow_runtime_downloader": false
    },
    "traceability": {
      "require_sha256": false,
      "require_release_manifest": false,
      "require_changelog": false
    }
  },
  "gates": {
    "build": "echo ok",
    "test": "echo ok",
    "contract_invariant": "echo ok",
    "hotspot": "echo ok"
  },
  "release": {
    "preflight": "N/A",
    "prepare": "N/A",
    "workflow_files": [],
    "output_root": "artifacts/release",
    "manifest": "artifacts/release/<version>/release-manifest.json"
  }
}
'@ | Set-Content -Path (Join-Path $tmp "RepoA\.governance\release-profile.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\verify-release-profile.ps1") -RepoPath (Join-Path $tmp "RepoA") -AsJson
      $LASTEXITCODE | should be 1
      $obj = $json | ConvertFrom-Json
      (@($obj.errors | Where-Object { $_ -match "signing.mode does not match release-distribution-policy" }).Count -ge 1) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "check-practice-stack script exists and emits json summary" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-practice-stack.ps1") -Destination (Join-Path $tmp "scripts\governance\check-practice-stack.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @((Join-Path $tmp "RepoA") -replace '\\','/') | ConvertTo-Json | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @'
{
  "schema_version": "1.0",
  "default": {
    "sdd": "required",
    "tdd": "required",
    "atdd_bdd": "recommended",
    "contract_testing": "required",
    "harness_engineering": "required",
    "policy_as_code": "required",
    "observability": "required",
    "progressive_delivery": "recommended",
    "hooks_ci_gates": "required"
  },
  "repos": []
}
'@ | Set-Content -Path (Join-Path $tmp "config\practice-stack-policy.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\check-practice-stack.ps1") -RepoRoot $tmp -AsJson
      if ($LASTEXITCODE -ne 0) { throw "check-practice-stack.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      [string]$obj.status | should be "PASS"
      [int]$obj.summary.repo_count | should be 1
      [int]$obj.summary.alert_count | should be 0
      [int]$obj.summary.average_score | should be 100
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }

  it "check-practice-stack reports missing required practices" {
    $tmp = Join-Path $env:TEMP ("govkit-test-" + [guid]::NewGuid().ToString("N"))
    try {
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\lib") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "scripts\governance") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "config") -Force | Out-Null
      New-Item -ItemType Directory -Path (Join-Path $tmp "RepoA") -Force | Out-Null

      Copy-Item -Path (Join-Path $repoRoot "scripts\governance\check-practice-stack.ps1") -Destination (Join-Path $tmp "scripts\governance\check-practice-stack.ps1") -Force
      Copy-Item -Path (Join-Path $repoRoot "scripts\lib\common.ps1") -Destination (Join-Path $tmp "scripts\lib\common.ps1") -Force

      @((Join-Path $tmp "RepoA") -replace '\\','/') | ConvertTo-Json | Set-Content -Path (Join-Path $tmp "config\repositories.json") -Encoding UTF8
      @'
{
  "schema_version": "1.0",
  "default": {
    "sdd": "required",
    "tdd": "required",
    "atdd_bdd": "recommended",
    "contract_testing": "required",
    "harness_engineering": "required",
    "policy_as_code": "required",
    "observability": "required",
    "progressive_delivery": "recommended",
    "hooks_ci_gates": "required"
  },
  "repos": [
    {
      "repoName": "RepoA",
      "practices": {
        "sdd": false,
        "tdd": false,
        "atdd_bdd": false,
        "contract_testing": true,
        "harness_engineering": false,
        "policy_as_code": true,
        "observability": false,
        "progressive_delivery": false,
        "hooks_ci_gates": true
      }
    }
  ]
}
'@ | Set-Content -Path (Join-Path $tmp "config\practice-stack-policy.json") -Encoding UTF8

      $json = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp "scripts\governance\check-practice-stack.ps1") -RepoRoot $tmp -AsJson
      if ($LASTEXITCODE -ne 0) { throw "check-practice-stack.ps1 failed with exit code $LASTEXITCODE" }
      $obj = $json | ConvertFrom-Json
      [string]$obj.status | should be "WARN"
      [int]$obj.summary.repo_count | should be 1
      ([int]$obj.summary.alert_count -ge 1) | should be $true
      ([int]$obj.summary.average_score -lt 100) | should be $true
    } finally {
      if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
  }
}




