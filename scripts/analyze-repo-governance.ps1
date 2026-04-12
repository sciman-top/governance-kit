param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
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
$repoName = Split-Path -Leaf $repo

function Get-FirstExistingRelativePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [Parameter(Mandatory = $true)]
    [string[]]$Candidates
  )

  foreach ($rel in $Candidates) {
    $full = Join-Path $Root ($rel -replace '/', '\')
    if (Test-Path -LiteralPath $full) {
      return ($rel -replace '\\', '/')
    }
  }

  return $null
}

function Read-TextIfExists {
  param([string]$Path)
  if (!(Test-Path -LiteralPath $Path)) { return $null }
  return Get-Content -LiteralPath $Path -Raw
}

$sln = @(Get-ChildItem -Path $repo -Filter *.sln -File -ErrorAction SilentlyContinue | Select-Object -First 1)
$testProj = @(Get-ChildItem -Path $repo -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue | Where-Object {
  $_.FullName -match '(\\|/)tests(\\|/)' -or $_.Name -match 'Tests\.csproj$'
} | Select-Object -First 1)
$hasBuildPs1 = Test-Path (Join-Path $repo "build.ps1")
$hasSkillsPs1 = Test-Path (Join-Path $repo "skills.ps1")
$hasVerifyKitPs1 = Test-Path (Join-Path $repo "scripts\verify-kit.ps1")
$hasVerifyPs1 = Test-Path (Join-Path $repo "scripts\verify.ps1")
$hasValidateConfigPs1 = Test-Path (Join-Path $repo "scripts\validate-config.ps1")
$hasDoctorPs1 = Test-Path (Join-Path $repo "scripts\doctor.ps1")
$hasGovernanceKitTests = Test-Path (Join-Path $repo "tests\repo-governance-hub.optimization.tests.ps1")
$hotspotRel = Get-FirstExistingRelativePath -Root $repo -Candidates @(
  "scripts/quality/check-hotspot-line-budgets.ps1",
  "scripts/validation/check-hotspot-line-budgets.ps1"
)
$quickGateRel = Get-FirstExistingRelativePath -Root $repo -Candidates @(
  "scripts/quality/run-local-quality-gates.ps1",
  "scripts/validation/run-stable-tests.ps1"
)
$evidenceDir = Join-Path $repo "docs\change-evidence"
$qualityGateWorkflowRel = Get-FirstExistingRelativePath -Root $repo -Candidates @(
  ".github/workflows/quality-gate.yml",
  ".github/workflows/quality-gates.yml"
)

$srcDirs = @()
$srcRoot = Join-Path $repo "src"
if (Test-Path $srcRoot) {
  $srcDirs = @(Get-ChildItem -Path $srcRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
}

$ci = [pscustomobject]@{
  github_actions_quality_gate = Test-Path (Join-Path $repo ".github\workflows\quality-gate.yml")
  github_actions_quality_gates = Test-Path (Join-Path $repo ".github\workflows\quality-gates.yml")
  github_actions = (Test-Path (Join-Path $repo ".github\workflows\quality-gate.yml")) -or (Test-Path (Join-Path $repo ".github\workflows\quality-gates.yml"))
  azure_pipelines = Test-Path (Join-Path $repo "azure-pipelines.yml")
  gitlab_ci = Test-Path (Join-Path $repo ".gitlab-ci.yml")
}

$contractFilter = $null
if ($qualityGateWorkflowRel) {
  $qualityGateWorkflow = Join-Path $repo ($qualityGateWorkflowRel -replace '/', '\')
  $wfText = Read-TextIfExists -Path $qualityGateWorkflow
  if ($wfText) {
    $m = [regex]::Match($wfText, '--filter\s+"([^"]+)"')
    if ($m.Success) { $contractFilter = $m.Groups[1].Value }
  }
}

$contractFilterFallback = "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~Contract|FullyQualifiedName~Invariant"
$contractFilterToUse = if ([string]::IsNullOrWhiteSpace($contractFilter)) { $contractFilterFallback } else { $contractFilter }

$isPowershellSkillRepo = ($sln.Count -eq 0) -and ($testProj.Count -eq 0) -and $hasBuildPs1 -and $hasSkillsPs1
$isGovernanceKitStyleRepo = ($sln.Count -eq 0) -and ($testProj.Count -eq 0) -and $hasVerifyKitPs1 -and $hasVerifyPs1 -and $hasValidateConfigPs1 -and $hasDoctorPs1

$buildCmd = if ($isGovernanceKitStyleRepo) {
  "powershell -File scripts/verify-kit.ps1"
} elseif ($isPowershellSkillRepo) {
  ".\build.ps1"
} elseif ($sln.Count -gt 0) {
  "dotnet build $($sln[0].Name) -c Debug"
} else {
  "dotnet build -c Debug"
}

$testCmd = if ($isGovernanceKitStyleRepo) {
  if ($hasGovernanceKitTests) {
    "powershell -File tests/repo-governance-hub.optimization.tests.ps1"
  } else {
    "powershell -File scripts/verify.ps1 -SkipConfigValidation"
  }
} elseif ($isPowershellSkillRepo) {
  ".\skills.ps1 发现"
} elseif ($testProj.Count -gt 0) {
  $rel = Get-RelativePathSafe -BasePath $repo -TargetPath $testProj[0].FullName
  "dotnet test $rel -c Debug"
} else {
  "dotnet test -c Debug"
}

$contractCmd = if ($isGovernanceKitStyleRepo) {
  "powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1"
} elseif ($isPowershellSkillRepo) {
  ".\skills.ps1 doctor --strict"
} elseif ($testProj.Count -gt 0) {
  $rel = Get-RelativePathSafe -BasePath $repo -TargetPath $testProj[0].FullName
  "dotnet test $rel -c Debug --filter `"$contractFilterToUse`""
} else {
  "N/A (no test project detected)"
}

$hotspotCmd = if ($isGovernanceKitStyleRepo) {
  "powershell -File scripts/doctor.ps1"
} elseif ($isPowershellSkillRepo) {
  ".\skills.ps1 构建生效"
} elseif ($hotspotRel) {
  "powershell -File $hotspotRel -AsJson"
} else {
  "N/A (hotspot script not found)"
}

$quickGateCmd = if ($quickGateRel -eq "scripts/validation/run-stable-tests.ps1") {
  "powershell -File scripts/validation/run-stable-tests.ps1 -Configuration Debug -SkipBuild -Profile quick"
} elseif ($quickGateRel) {
  "powershell -File $quickGateRel -Profile quick"
} else {
  "N/A (quick gate script not found)"
}

$hooksPreCommit = Join-Path $repo ".git\hooks\pre-commit"
$hooksPrePush = Join-Path $repo ".git\hooks\pre-push"
$preCommitText = Read-TextIfExists -Path $hooksPreCommit
$prePushText = Read-TextIfExists -Path $hooksPrePush
$hookBlockInstalled = (($preCommitText -match "# >>> repo-governance-hub begin") -and ($prePushText -match "# >>> repo-governance-hub begin"))

$commitTemplateConfigured = $false
$governanceRootConfigured = $false
$governanceKitRootConfigured = $false
try {
  $templateValue = (& git -C $repo config --local --get commit.template 2>$null)
  $commitTemplateConfigured = -not [string]::IsNullOrWhiteSpace($templateValue)
} catch {}
try {
  $rootValue = (& git -C $repo config --local --get governance.root 2>$null)
  $governanceRootConfigured = -not [string]::IsNullOrWhiteSpace($rootValue)
} catch {}

$templatePresence = [pscustomobject]@{
  change_evidence_template = Test-Path (Join-Path $repo "docs\change-evidence\template.md")
  governance_waiver_template = Test-Path (Join-Path $repo "docs\governance\waiver-template.md")
  governance_metrics_template = Test-Path (Join-Path $repo "docs\governance\metrics-template.md")
  governance_waiver_item_template = Test-Path (Join-Path $repo "docs\governance\waivers\_template.md")
}

$facts = [pscustomobject]@{
  repo = ($repo -replace '\\', '/')
  repo_name = $repoName
  has_git = Test-Path (Join-Path $repo ".git")
  detected = [pscustomobject]@{
    solution = if ($sln.Count -gt 0) { $sln[0].Name } else { $null }
    test_project = if ($testProj.Count -gt 0) { (Get-RelativePathSafe -BasePath $repo -TargetPath $testProj[0].FullName) } else { $null }
    src_modules = @($srcDirs)
    evidence_dir_exists = (Test-Path $evidenceDir)
    hotspot_script_relative = $hotspotRel
    quick_gate_script_relative = $quickGateRel
    quality_gate_workflow_relative = $qualityGateWorkflowRel
    contract_filter = $contractFilterToUse
    ci = $ci
    hook_state = [pscustomobject]@{
      pre_commit_exists = Test-Path $hooksPreCommit
      pre_push_exists = Test-Path $hooksPrePush
      governance_block_installed = $hookBlockInstalled
    }
    git_config_state = [pscustomobject]@{
      commit_template_configured = $commitTemplateConfigured
      governance_root_configured = $governanceRootConfigured
    }
    templates = $templatePresence
  }
  recommended = [pscustomobject]@{
    build = $buildCmd
    test = $testCmd
    contract_invariant = $contractCmd
    hotspot = $hotspotCmd
    quick_gate = $quickGateCmd
    evidence_dir = "docs/change-evidence/"
  }
}

if ($AsJson) {
  $facts | ConvertTo-Json -Depth 8 | Write-Output
  exit 0
}

Write-Host "repo=$($facts.repo)"
Write-Host "repo_name=$($facts.repo_name)"
Write-Host "has_git=$($facts.has_git)"
Write-Host "solution=$($facts.detected.solution)"
Write-Host "test_project=$($facts.detected.test_project)"
Write-Host "evidence_dir_exists=$($facts.detected.evidence_dir_exists)"
Write-Host "ci.github_actions=$($facts.detected.ci.github_actions)"
Write-Host "ci.github_actions_quality_gate=$($facts.detected.ci.github_actions_quality_gate)"
Write-Host "ci.github_actions_quality_gates=$($facts.detected.ci.github_actions_quality_gates)"
Write-Host "ci.azure_pipelines=$($facts.detected.ci.azure_pipelines)"
Write-Host "ci.gitlab_ci=$($facts.detected.ci.gitlab_ci)"
Write-Host "hotspot_script_relative=$($facts.detected.hotspot_script_relative)"
Write-Host "quick_gate_script_relative=$($facts.detected.quick_gate_script_relative)"
Write-Host "quality_gate_workflow_relative=$($facts.detected.quality_gate_workflow_relative)"
Write-Host "hook.governance_block_installed=$($facts.detected.hook_state.governance_block_installed)"
Write-Host "git.commit_template_configured=$($facts.detected.git_config_state.commit_template_configured)"
Write-Host "git.governance_root_configured=$($facts.detected.git_config_state.governance_root_configured)"
if ($facts.detected.src_modules.Count -gt 0) {
  Write-Host ("src_modules=" + ($facts.detected.src_modules -join ","))
}
Write-Host "recommended.build=$($facts.recommended.build)"
Write-Host "recommended.test=$($facts.recommended.test)"
Write-Host "recommended.contract_invariant=$($facts.recommended.contract_invariant)"
Write-Host "recommended.hotspot=$($facts.recommended.hotspot)"
Write-Host "recommended.quick_gate=$($facts.recommended.quick_gate)"
Write-Host "recommended.evidence_dir=$($facts.recommended.evidence_dir)"

