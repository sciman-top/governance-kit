param(
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$OverwriteCI,
  [switch]$OverwriteTemplates
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "install-extras.ps1" -Mode $Mode
$reposPath = Join-Path $kitRoot "config\repositories.json"
if (!(Test-Path $reposPath)) {
  throw "repositories.json not found: $reposPath"
}

if ($Mode -eq "force") {
  $OverwriteCI = $true
  $OverwriteTemplates = $true
}
$planMode = $Mode -eq "plan"

function Ensure-Dir([string]$Path) {
  if ($planMode) {
    if (!(Test-Path $Path)) { Write-Host "[PLAN] MKDIR $Path" }
    return
  }
  if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Copy-WithPolicy([string]$Src, [string]$Dst, [bool]$CanOverwrite, [string]$Label) {
  $exists = Test-Path $Dst
  $action = if (-not $exists) { "CREATE" } elseif ($CanOverwrite) { "UPDATE" } else { "KEEP" }

  if ($planMode) {
    Write-Host "[PLAN] $action $Label"
    return
  }

  if ($exists -and -not $CanOverwrite) {
    Write-Host "[SKIP] $Label already exists"
    return
  }

  Copy-Item -Path $Src -Destination $Dst -Force
  Write-Host "[COPIED] $Label"
}

function Get-HookBlock([string]$Kind) {
  $trackedScope = if ($Kind -eq "pre-push") { "outgoing" } else { "staged" }
  $fastCheckArgs = if ($Kind -eq "pre-push") { "" } else { " -DisableAutoEscalation" }
  return @'
# >>> repo-governance-hub begin
ROOT="$(git config --get governance.root)"
if [ -z "$ROOT" ]; then
  ROOT="${GOVERNANCE_ROOT}"
fi

if [ -n "$ROOT" ]; then
  if [ -f "$ROOT/scripts/governance/fast-check.ps1" ]; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/governance/fast-check.ps1"__FAST_CHECK_ARGS__
    status=$?
    if [ $status -ne 0 ]; then
      echo "[BLOCK] governance fast-check failed"
      exit $status
    fi
  fi

  powershell -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/verify.ps1" -TrackedFilesScope __TRACKED_SCOPE__
  status=$?
  if [ $status -ne 0 ]; then
    echo "[BLOCK] governance verify failed"
    exit $status
  fi
fi
# <<< repo-governance-hub end
'@ -replace "__TRACKED_SCOPE__", $trackedScope -replace "__FAST_CHECK_ARGS__", $fastCheckArgs
}

function Ensure-Hook([string]$HookPath, [string]$Kind, [string]$TemplatePath) {
  if ($Mode -eq "force") {
    if ($planMode) {
      Write-Host "[PLAN] UPDATE .git/hooks/$Kind (replace)"
      return
    }
    Copy-Item -Path $TemplatePath -Destination $HookPath -Force
    Write-Host "[COPIED] .git/hooks/$Kind"
    return
  }

  $block = Get-HookBlock $Kind
  if (!(Test-Path $HookPath)) {
    if ($planMode) {
      Write-Host "[PLAN] CREATE .git/hooks/$Kind (governance block)"
      return
    }
    $content = "#!/bin/sh`n" + $block + "`n"
    Set-Content -Path $HookPath -Value $content -Encoding UTF8
    Write-Host "[COPIED] .git/hooks/$Kind"
    return
  }

  $existing = Get-Content -Path $HookPath -Raw
  if ($existing -match "# >>> repo-governance-hub begin" -or $existing -match "# >>> governance-kit begin") {
    $hasLegacyBlock = ($existing -match "# >>> governance-kit begin")
    $repoBlockMatches = [regex]::Matches($existing, '# >>> repo-governance-hub begin').Count
    $hasDuplicateRepoBlocks = ($repoBlockMatches -gt 1)
    $normalizedExisting = $existing -replace "`r`n", "`n"
    $normalizedBlock = $block -replace "`r`n", "`n"
    if ($normalizedExisting.Contains($normalizedBlock) -and -not $hasLegacyBlock -and -not $hasDuplicateRepoBlocks) {
      Write-Host "[SKIP] .git/hooks/$Kind governance block already up-to-date"
      return
    }
    if ($planMode) {
      Write-Host "[PLAN] UPDATE .git/hooks/$Kind (refresh governance block)"
      return
    }
    $pattern = '(?s)# >>> (?:repo-governance-hub|governance-kit) begin.*?# <<< (?:repo-governance-hub|governance-kit) end'
    $stripped = [regex]::Replace($existing, $pattern, "")
    $normalizedStripped = $stripped.TrimEnd()
    if ([string]::IsNullOrWhiteSpace($normalizedStripped)) {
      $newContent = ($block.TrimEnd() + "`n")
    } else {
      $newContent = ($normalizedStripped + "`n`n" + $block.TrimEnd() + "`n")
    }
    Set-Content -Path $HookPath -Value $newContent -Encoding UTF8
    Write-Host "[UPDATED] .git/hooks/$Kind refreshed governance block"
    return
  }

  if ($planMode) {
    Write-Host "[PLAN] UPDATE .git/hooks/$Kind (append governance block)"
    return
  }

  $newContent = $existing.TrimEnd() + "`n`n" + $block + "`n"
  Set-Content -Path $HookPath -Value $newContent -Encoding UTF8
  Write-Host "[UPDATED] .git/hooks/$Kind appended governance block"
}

function Invoke-GitConfigSet([string]$RepoPath, [string[]]$GitArgs) {
  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  try {
    $argList = @("-C", $RepoPath) + $GitArgs
    $proc = Start-Process -FilePath "git" -ArgumentList $argList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    $joined = (@($stdout, $stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine
    return [pscustomobject]@{
      exit_code = $proc.ExitCode
      output = $joined
    }
  } finally {
    if (Test-Path -LiteralPath $stdoutPath) { Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $stderrPath) { Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue }
  }
}

$repos = Read-JsonArray $reposPath
if ($repos.Count -eq 0) {
  Write-Host "[SKIP] no repositories configured"
  exit 0
}

$hookPreCommit = Join-Path $kitRoot "hooks\pre-commit"
$hookPrePush = Join-Path $kitRoot "hooks\pre-push"
$prTemplate = Join-Path $kitRoot "templates\pr-template.md"
$commitTemplate = Join-Path $kitRoot "templates\commit-template.txt"
$evidenceTemplate = Join-Path $kitRoot "templates\change-evidence.md"
$waiverTemplate = Join-Path $kitRoot "templates\waiver-template.md"
$waiverItemTemplate = Join-Path $kitRoot "templates\waiver-item-template.md"
$metricsTemplate = Join-Path $kitRoot "templates\governance-metrics.md"
$editorconfigBase = Join-Path $kitRoot "config\editorconfig.base"
$ghaTpl = Join-Path $kitRoot "ci\github-actions-template.yml"
$azureTpl = Join-Path $kitRoot "ci\azure-pipelines-template.yml"
$gitlabTpl = Join-Path $kitRoot "ci\gitlab-ci-template.yml"

foreach ($repo in $repos) {
  $repoPath = $repo -replace '/', '\\'
  if (!(Test-Path $repoPath)) {
    Write-Host "[SKIP] repo not found: $repoPath"
    continue
  }

  Write-Host "[REPO] $repoPath"

  $githubDir = Join-Path $repoPath ".github"
  $workflowsDir = Join-Path $githubDir "workflows"
  Ensure-Dir $githubDir
  Ensure-Dir $workflowsDir

  Copy-WithPolicy $prTemplate (Join-Path $githubDir "pull_request_template.md") $OverwriteTemplates ".github/pull_request_template.md"
  Copy-WithPolicy $ghaTpl (Join-Path $workflowsDir "quality-gates.yml") $OverwriteCI ".github/workflows/quality-gates.yml"
  Copy-WithPolicy $azureTpl (Join-Path $repoPath "azure-pipelines.yml") $OverwriteCI "azure-pipelines.yml"
  Copy-WithPolicy $gitlabTpl (Join-Path $repoPath ".gitlab-ci.yml") $OverwriteCI ".gitlab-ci.yml"

  $docsDir = Join-Path $repoPath "docs\change-evidence"
  Ensure-Dir $docsDir
  Copy-WithPolicy $evidenceTemplate (Join-Path $docsDir "template.md") $OverwriteTemplates "docs/change-evidence/template.md"

  $governanceDir = Join-Path $repoPath "docs\governance"
  Ensure-Dir $governanceDir
  Copy-WithPolicy $waiverTemplate (Join-Path $governanceDir "waiver-template.md") $OverwriteTemplates "docs/governance/waiver-template.md"
  Copy-WithPolicy $metricsTemplate (Join-Path $governanceDir "metrics-template.md") $OverwriteTemplates "docs/governance/metrics-template.md"

  $waiverItemsDir = Join-Path $governanceDir "waivers"
  Ensure-Dir $waiverItemsDir
  Copy-WithPolicy $waiverItemTemplate (Join-Path $waiverItemsDir "_template.md") $OverwriteTemplates "docs/governance/waivers/_template.md"

  Copy-WithPolicy $editorconfigBase (Join-Path $repoPath ".editorconfig") $false ".editorconfig"

  $gitDir = Join-Path $repoPath ".git"
  if (Test-Path $gitDir) {
    $hooksDir = Join-Path $gitDir "hooks"
    Ensure-Dir $hooksDir

    Ensure-Hook (Join-Path $hooksDir "pre-commit") "pre-commit" $hookPreCommit
    Ensure-Hook (Join-Path $hooksDir "pre-push") "pre-push" $hookPrePush

    $commitMsgFile = Join-Path $repoPath ".gitmessage.txt"
    Copy-WithPolicy $commitTemplate $commitMsgFile $OverwriteTemplates ".gitmessage.txt"

    if ($planMode) {
      Write-Host "[PLAN] SET git commit.template=.gitmessage.txt"
      Write-Host "[PLAN] SET git governance.root"
    } else {
      $setCommit = Invoke-GitConfigSet -RepoPath $repoPath -GitArgs @("config", "commit.template", ".gitmessage.txt")
      if ($setCommit.exit_code -eq 0) {
        Write-Host "[SET] git commit.template=.gitmessage.txt"
      } else {
        Write-Host "[WARN] failed to set git commit.template (exit=$($setCommit.exit_code))"
        if (-not [string]::IsNullOrWhiteSpace($setCommit.output)) {
          Write-Host ("       " + $setCommit.output.Trim())
        }
      }

      $setGovernanceRoot = Invoke-GitConfigSet -RepoPath $repoPath -GitArgs @("config", "governance.root", ($kitRoot -replace '\\','/'))
      if ($setGovernanceRoot.exit_code -eq 0) {
        Write-Host "[SET] git governance.root"
      } else {
        Write-Host "[WARN] failed to set git governance.root (exit=$($setGovernanceRoot.exit_code))"
        if (-not [string]::IsNullOrWhiteSpace($setGovernanceRoot.output)) {
          Write-Host ("       " + $setGovernanceRoot.output.Trim())
        }
      }
    }
  } else {
    Write-Host "[SKIP] .git not found; hooks and commit.template not installed"
  }
}

Write-Host "install-extras done. mode=$Mode"

