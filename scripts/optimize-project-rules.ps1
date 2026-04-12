param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [switch]$ShowScope,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
$repoName = Split-Path -Leaf $repo
$modePlan = $Mode -eq "plan"

$analysisJson = Invoke-ChildScriptCapture -ScriptPath (Join-Path $PSScriptRoot "analyze-repo-governance.ps1") -ScriptArgs @("-RepoPath", $repo, "-AsJson")
$analysis = $analysisJson | ConvertFrom-Json

$build = [string]$analysis.recommended.build
$test = [string]$analysis.recommended.test
$contract = [string]$analysis.recommended.contract_invariant
$hotspot = [string]$analysis.recommended.hotspot
$quickGate = [string]$analysis.recommended.quick_gate
$ci = $analysis.detected.ci
$hotspotRel = [string]$analysis.detected.hotspot_script_relative
$quickGateRel = [string]$analysis.detected.quick_gate_script_relative
$hookState = $analysis.detected.hook_state
$gitConfigState = $analysis.detected.git_config_state
$templatesState = $analysis.detected.templates

$a3Block = @"
### A.3 N/A policy
- minimum fields: reason, alternative_verification, evidence_link.
"@

$c2Block = @"
### C.2 Gate commands and execution order
- $build
- $test
- $contract
- $hotspot
- quick gate: $quickGate
- fixed order: build -> test -> contract/invariant -> hotspot.
"@

$hotspotPrecheck = if ($hotspot.StartsWith("N/A", [System.StringComparison]::OrdinalIgnoreCase)) {
  "N/A (hotspot script missing)"
} else {
  "Test-Path $hotspotRel"
}
$contractPrecheck = if ($contract.StartsWith("N/A", [System.StringComparison]::OrdinalIgnoreCase)) {
  "N/A (contract/invariant subset not detected)"
} else {
  if ($analysis.detected.test_project) { "Test-Path $($analysis.detected.test_project)" } else { "N/A (test project not detected)" }
}

$shellPrecheck = if ($build.StartsWith(".\", [System.StringComparison]::OrdinalIgnoreCase) -or $test.StartsWith(".\", [System.StringComparison]::OrdinalIgnoreCase)) {
  "Get-Command powershell"
} else {
  "Get-Command dotnet"
}

$c3Block = @"
### C.3 Command presence and N/A fallback verification
- precheck: $shellPrecheck, $contractPrecheck, $hotspotPrecheck.
- if hotspot is missing: mark hotspot=N/A, run contract/invariant subset and record manual hotspot review.
- if contract/invariant subset is unavailable: mark contract/invariant=N/A, run full test command and record contract-gap risks.
- any N/A must preserve semantic order: build -> test -> contract/invariant -> hotspot.
"@

$ciItems = @()
if ($ci.github_actions_quality_gate) { $ciItems += "- GitHub Actions: .github/workflows/quality-gate.yml" }
if ($ci.github_actions_quality_gates) { $ciItems += "- GitHub Actions: .github/workflows/quality-gates.yml" }
if ($ci.azure_pipelines) { $ciItems += "- Azure Pipelines: azure-pipelines.yml" }
if ($ci.gitlab_ci) { $ciItems += "- GitLab CI: .gitlab-ci.yml" }
if ($ciItems.Count -eq 0) { $ciItems += "- No standard CI entry file detected in this repository." }

$installItems = @(
  ("- hooks/pre-commit+pre-push governance block installed: " + [bool]$hookState.governance_block_installed),
  ("- git commit.template configured: " + [bool]$gitConfigState.commit_template_configured),
  ("- git governance.root configured: " + [bool]$gitConfigState.governance_root_configured),
  ("- docs/change-evidence/template.md exists: " + [bool]$templatesState.change_evidence_template),
  ("- docs/governance/waiver-template.md exists: " + [bool]$templatesState.governance_waiver_template),
  ("- docs/governance/metrics-template.md exists: " + [bool]$templatesState.governance_metrics_template)
)

$c7Block = @"
### C.7 Target-repo direct edit backflow policy
- source of truth: E:/CODE/repo-governance-hub/source/project/$repoName/*.
- temporary direct edits in target repo are allowed for fast trial, but must backflow to source the same day with evidence.
- after backflow, run powershell -File E:/CODE/repo-governance-hub/scripts/install.ps1 -Mode safe to re-sync source and target.
- before backflow completion, do not run sync/install again to avoid overwriting unsaved target edits.

### C.8 CI entry differences
{0}

### C.9 Hooks/templates/git config snapshot
- quick gate script selected: {1}
- hotspot script selected: {2}
{3}
"@ -f (
  $ciItems -join "`r`n"
), $(
  if ([string]::IsNullOrWhiteSpace($quickGateRel)) { "N/A" } else { $quickGateRel }
), $(
  if ([string]::IsNullOrWhiteSpace($hotspotRel)) { "N/A" } else { $hotspotRel }
), (
  $installItems -join "`r`n"
)

$files = @("AGENTS.md", "CLAUDE.md", "GEMINI.md")
if ($ShowScope) {
  Write-Host "=== SCOPE optimize-project-rules ==="
  foreach ($f in $files) {
    Write-Host ("- " + (Join-Path $repo $f))
  }
}
$updated = 0
$actions = @()
foreach ($f in $files) {
  $path = Join-Path $repo $f
  if (!(Test-Path $path)) {
    throw "Project rule file missing: $path"
  }

  $text = Read-Utf8NoBom -Path $path
  $next = $text

  # Only auto-rewrite template-style docs. If a doc has been manually/openly rewritten,
  # keep custom sections to avoid over-optimization or semantic rollback.
  $isTemplateDoc = ($text -match "(?mi)^###\s*A\.3\s+N/?A policy\s*$") -and
                   ($text -match "(?mi)^###\s*C\.2\s+(Gate commands and execution order|Gates)\s*$") -and
                   ($text -match "(?mi)^###\s*C\.3\s+(Command presence and N/?A fallback verification|N/?A fallback)\s*$")
  if (-not $isTemplateDoc) {
    Write-Host "[SKIP] custom-optimized doc preserved $path"
    $actions += [pscustomobject]@{ file = $path; action = "CUSTOM_PRESERVED" }
    continue
  }

  $next = [regex]::Replace($next, "(?mis)^###\s*A\.3\s+N/?A policy.*?(?=^##\s*B\.)", ($a3Block.Trim() + "`r`n`r`n"))
  $next = [regex]::Replace($next, "(?mis)^###\s*C\.2\s+(Gate commands and execution order|Gates).*?(?=^###\s*C\.3\s+)", ($c2Block.Trim() + "`r`n`r`n"))
  $next = [regex]::Replace($next, "(?mis)^###\s*C\.3\s+(Command presence and N/?A fallback verification|N/?A fallback).*?(?=^###\s*C\.4\s+)", ($c3Block.Trim() + "`r`n`r`n"))

  $hasAnyC7 = $next -match "(?m)^### C\.7 "
  $hasTemplateC7 = $next -match "(?m)^### C\.7 Target-repo direct edit backflow policy$"
  if ($hasTemplateC7) {
    $next = [regex]::Replace($next, "(?ms)^### C\.7 Target-repo direct edit backflow policy.*?(?=^## D\.)", ($c7Block.Trim() + "`r`n`r`n"))
  } elseif ($hasAnyC7) {
    # keep custom C.7/C.8/C.9 when custom headings are present
  } else {
    $next = [regex]::Replace($next, "(?ms)\r?\n## D\.", ("`r`n" + $c7Block.Trim() + "`r`n`r`n## D."))
  }

  if ($next -notmatch "target repo direct edit must backflow") {
    $next = [regex]::Replace(
      $next,
      "(?m)^- .*chain.*$",
      ('$0' + "`r`n" + "- target repo direct edit must backflow and pass re-distribution verification.")
    )
  }

  if ($next -ne $text) {
    if ($modePlan) {
      Write-Host "[PLAN] UPDATE $path"
      $actions += [pscustomobject]@{ file = $path; action = "UPDATE" }
    } else {
      Write-Utf8NoBom -Path $path -Content $next
      Write-Host "[UPDATED] $path"
      $actions += [pscustomobject]@{ file = $path; action = "UPDATED" }
    }
    $updated++
  } else {
    Write-Host "[SKIP] unchanged $path"
    $actions += [pscustomobject]@{ file = $path; action = "UNCHANGED" }
  }
}

if ($AsJson) {
  @{
    mode = $Mode
    repo = ($repo -replace '\\', '/')
    updated = $updated
    items = @($actions)
  } | ConvertTo-Json -Depth 6 | Write-Output
}

if ($modePlan) {
  Write-Host "Plan done. files_to_update=$updated"
} else {
  Write-Host "Done. files_updated=$updated"
}


