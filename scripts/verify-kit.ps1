$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$mustExist = @(
  "config\targets.json",
  "config\repositories.json",
  "config\rule-rollout.json",
  "config\project-rule-policy.json",
  "config\project-custom-files.json",
  "config\real-repo-regression-matrix.json",
  "config\governance-baseline.json",
  "config\codex-runtime-policy.json",
  "config\update-trigger-policy.json",
  "config\editorconfig.base",
  ".governance\tracked-files-policy.json",
  "scripts\add-repo.ps1",
  "scripts\remove-repo.ps1",
  "scripts\status.ps1",
  "scripts\doctor.ps1",
  "scripts\bootstrap-repo.ps1",
  "scripts\bootstrap-here.ps1",
  "scripts\install-full-stack.ps1",
  "scripts\install.ps1",
  "scripts\refresh-targets.ps1",
  "scripts\sync.ps1",
  "scripts\verify.ps1",
  "scripts\governance\check-tracked-files.ps1",
  "scripts\governance\run-recurring-review.ps1",
  "scripts\governance\run-monthly-policy-review.ps1",
  "scripts\governance\check-update-triggers.ps1",
  "scripts\governance\check-rule-duplication.ps1",
  "scripts\governance\register-review-task.ps1",
  "scripts\governance\unregister-review-task.ps1",
  "scripts\restore.ps1",
  "scripts\install-extras.ps1",
  "scripts\install-global-git.ps1",
  "scripts\verify-kit.ps1",
  "scripts\rollout-status.ps1",
  "scripts\set-rollout.ps1",
  "scripts\set-codex-runtime-policy.ps1",
  "scripts\check-waivers.ps1",
  "scripts\check-orphan-custom-sources.ps1",
  "scripts\prune-orphan-custom-sources.ps1",
  "scripts\prune-backups.ps1",
  "scripts\collect-governance-metrics.ps1",
  "scripts\bump-rule-version.ps1",
  "scripts\backflow-project-rules.ps1",
  "scripts\analyze-repo-governance.ps1",
  "scripts\suggest-release-profile.ps1",
  "scripts\verify-release-profile.ps1",
  "scripts\check-release-profile-coverage.ps1",
  "scripts\optimize-project-rules.ps1",
  "scripts\run-project-governance-cycle.ps1",
  "scripts\run-endstate-onboarding.ps1",
  "scripts\run-real-repo-regression.ps1",
  "scripts\verify-json-contract.ps1",
  "scripts\check-cli-capabilities.ps1",
  "scripts\check-cli-version-drift.ps1",
  "scripts\validate-failure-context.ps1",
  "scripts\audit-governance-readiness.ps1",
  "scripts\merge-rules.ps1",
  "scripts\validate-config.ps1",
  "scripts\lib\common.ps1",
  "hooks\pre-commit",
  "hooks\pre-push",
  "hooks-global\pre-commit",
  "hooks-global\pre-push",
  "ci\github-actions-template.yml",
  "ci\azure-pipelines-template.yml",
  "ci\gitlab-ci-template.yml",
  "templates\commit-template.txt",
  "templates\pr-template.md",
  "templates\change-evidence.md",
  "templates\release-profile.template.json",
  "templates\waiver-template.md",
  "templates\waiver-item-template.md",
  "templates\governance-metrics.md",
  "source\global\AGENTS.md",
  "source\global\CLAUDE.md",
  "source\global\GEMINI.md",
  "source\project\_common\custom\scripts\governance\run-project-governance-cycle.ps1",
  "source\project\_common\custom\scripts\governance\run-target-autopilot.ps1",
  "source\project\_common\custom\scripts\governance\check-tracked-files.ps1",
  "source\project\_common\custom\.governance\tracked-files-policy.json",
  "source\project\_common\custom\.codex\config.toml",
  "source\project\_common\custom\.codex\agents\planner.toml",
  "source\project\_common\custom\.codex\agents\reuse-analyst.toml",
  "source\project\_common\custom\.codex\agents\reviewer.toml",
  "source\project"
)

$missing = @()
foreach ($rel in $mustExist) {
  $p = Join-Path $root $rel
  if (!(Test-Path $p)) { $missing += $rel }
}

if ($missing.Count -gt 0) {
  $missing | ForEach-Object { Write-Host "[MISS] $_" }
  throw "governance-kit integrity check failed"
}

function Get-RuleMeta([string]$Path) {
  $text = Get-Content -Path $Path -Raw
  $meta = Get-RuleDocMetadata -Path $Path
  $has1 = [regex]::IsMatch($text, "(?m)^\s*##\s+1\.")
  $hasA = [regex]::IsMatch($text, "(?m)^\s*##\s+A\.")
  $hasB = [regex]::IsMatch($text, "(?m)^\s*##\s+B\.")
  $hasC = [regex]::IsMatch($text, "(?m)^\s*##\s+C\.")
  $hasD = [regex]::IsMatch($text, "(?m)^\s*##\s+D\.")

  return [pscustomobject]@{
    Path = $Path
    Version = $meta.version
    Date = $meta.last_update
    HasSections = ($has1 -and $hasA -and $hasB -and $hasC -and $hasD)
  }
}

$ruleFilesGlobal = @(
  "source\global\AGENTS.md",
  "source\global\CLAUDE.md",
  "source\global\GEMINI.md"
)
$projectRoot = Join-Path $root "source\project"
$projectRuleFiles = @()
$metaFail = 0
if (Test-Path $projectRoot) {
  $projectRuleFiles = @(Get-ChildItem -Path $projectRoot -Recurse -File | Where-Object {
    @("AGENTS.md", "CLAUDE.md", "GEMINI.md") -contains $_.Name
  })
}
if ($projectRuleFiles.Count -eq 0) {
  Write-Host "[META] no project rule files found under source/project"
  $metaFail++
}

$projectRuleDirs = @{}
foreach ($f in $projectRuleFiles) {
  $dir = $f.DirectoryName
  if (-not $projectRuleDirs.ContainsKey($dir)) {
    $projectRuleDirs[$dir] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  }
  [void]$projectRuleDirs[$dir].Add($f.Name)
}
foreach ($dir in $projectRuleDirs.Keys) {
  foreach ($required in @("AGENTS.md", "CLAUDE.md", "GEMINI.md")) {
    if (-not $projectRuleDirs[$dir].Contains($required)) {
      Write-Host "[META] incomplete project rule set in $dir missing $required"
      $metaFail++
    }
  }
}
$globalMetas = @()
$projectMetas = @()
foreach ($rel in $ruleFilesGlobal) {
  $globalMetas += Get-RuleMeta -Path (Join-Path $root $rel)
}
foreach ($file in $projectRuleFiles) {
  $projectMetas += Get-RuleMeta -Path $file.FullName
}

foreach ($m in ($globalMetas + $projectMetas)) {
  if ([string]::IsNullOrWhiteSpace($m.Version)) {
    Write-Host "[META] missing version field: $($m.Path)"
    $metaFail++
  }
  if ([string]::IsNullOrWhiteSpace($m.Date)) {
    Write-Host "[META] missing/invalid last-update date: $($m.Path)"
    $metaFail++
  }
  if (-not $m.HasSections) {
    if ($m.Path -like "*\source\project\*") {
      $textFallback = Get-Content -Path $m.Path -Raw
      $fallbackOk = (
        $textFallback.Contains("## 1.") -and
        $textFallback.Contains("## A.") -and
        $textFallback.Contains("## B.") -and
        $textFallback.Contains("## C.") -and
        $textFallback.Contains("## D.")
      )
      if (-not $fallbackOk) {
        Write-Host "[META] missing required top sections (1/A/B/C/D): $($m.Path)"
        $metaFail++
      }
    } else {
      Write-Host "[META] missing required top sections (1/A/B/C/D): $($m.Path)"
      $metaFail++
    }
  }
}

$globalVersions = @($globalMetas | ForEach-Object { $_.Version } | Select-Object -Unique)
$projectVersions = @($projectMetas | ForEach-Object { $_.Version } | Select-Object -Unique)
if ($globalVersions.Count -ne 1) {
  Write-Host "[META] global rule versions must be consistent: $($globalVersions -join ',')"
  $metaFail++
}
if ($projectVersions.Count -ne 1) {
  Write-Host "[META] project rule versions must be consistent: $($projectVersions -join ',')"
  $metaFail++
}

if ($metaFail -gt 0) {
  throw "governance-kit metadata check failed: issues=$metaFail"
}

$evidenceTemplateChecks = @(
  "templates\change-evidence.md",
  "docs\change-evidence\template.md"
)
$learningLoopRequiredFields = @(
  "learning_points_3",
  "reusable_checklist",
  "open_questions"
)

foreach ($rel in $evidenceTemplateChecks) {
  $abs = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
    continue
  }
  $kv = Parse-KeyValueFile -Path $abs
  foreach ($field in $learningLoopRequiredFields) {
    if (-not $kv.ContainsKey($field)) {
      Write-Host "[META] evidence template missing required learning-loop field '$field': $rel"
      $metaFail++
    }
  }
}

if ($metaFail -gt 0) {
  throw "governance-kit metadata check failed: issues=$metaFail"
}

$refreshScript = Join-Path $PSScriptRoot "refresh-targets.ps1"
if (-not (Test-Path -LiteralPath $refreshScript -PathType Leaf)) {
  throw "refresh-targets script missing: $refreshScript"
}
$refreshOutput = Invoke-ChildScriptCapture -ScriptPath $refreshScript -ScriptArgs @("-Mode", "plan", "-AsJson")
$refreshObj = $null
if (-not [string]::IsNullOrWhiteSpace([string]($refreshOutput | Out-String))) {
  $refreshObj = ([string]::Join([Environment]::NewLine, @($refreshOutput))) | ConvertFrom-Json
}
if ($null -eq $refreshObj) {
  throw "refresh-targets returned empty result"
}
if ([int]$refreshObj.target_change_count -gt 0) {
  throw ("distribution mapping drift detected: target_change_count={0}. Run scripts/install.ps1 (or scripts/refresh-targets.ps1) to sync one-click install mapping." -f [int]$refreshObj.target_change_count)
}

$dupScript = Join-Path $root "scripts\governance\check-rule-duplication.ps1"
Invoke-ChildScript -ScriptPath $dupScript -ScriptArgs @("-RepoRoot", $root)

Write-Host "governance-kit integrity OK"
