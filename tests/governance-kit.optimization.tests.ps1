$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here "..")).Path

function Set-MinProjectRulePolicy {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigDir,
    [Parameter(Mandatory = $true)]
    [string]$RepoPath
  )

  @{
    allowProjectRulesForRepos = @($RepoPath)
  } | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $ConfigDir "project-rule-policy.json") -Encoding UTF8
}

function Set-StubScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Message = "ok",
    [int]$ExitCode = 0
  )

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
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1") -Message "boom" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
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
      Set-RequireSkipValidationVerifyScript -Path (Join-Path $tmp "scripts\verify.ps1")
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
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
      Set-StubScript -Path (Join-Path $tmp "scripts\verify.ps1") -Message "boom" -ExitCode 1
      Set-StubScript -Path (Join-Path $tmp "scripts\check-waivers.ps1")
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

      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\optimize-project-rules.ps1") -RepoPath $repo -Mode safe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "optimize-project-rules.ps1 failed with exit code $LASTEXITCODE" }

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
}
