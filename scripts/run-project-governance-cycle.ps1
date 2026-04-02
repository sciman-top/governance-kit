param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$RepoName,
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [switch]$ShowScope,
  [switch]$SkipInstall,
  [switch]$SkipOptimize,
  [switch]$SkipBackflow
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "run-project-governance-cycle.ps1" -Mode $Mode

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
if ([string]::IsNullOrWhiteSpace($RepoName)) {
  $RepoName = Split-Path -Leaf $repo
}
$allowProjectRuleRepos = Read-ProjectRuleAllowRepos $kitRoot
$allowProjectRules = Is-RepoAllowedForProjectRules -Repo $repo -AllowRepos $allowProjectRuleRepos
$effectiveSkipOptimize = $SkipOptimize.IsPresent
$effectiveSkipBackflow = $SkipBackflow.IsPresent
if (-not $allowProjectRules) {
  if (-not $effectiveSkipOptimize) {
    Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip optimize-project-rules."
  }
  if (-not $effectiveSkipBackflow) {
    Write-Host "[INFO] project rules are not allow-listed for repo; auto-skip backflow-project-rules."
  }
  $effectiveSkipOptimize = $true
  $effectiveSkipBackflow = $true
}

function Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  & $Action
  Write-Host "[DONE] $Name"
}

if (-not $SkipInstall) {
  Step "install" {
    $argsInstall = @("-Mode", $Mode)
    if ($ShowScope) { $argsInstall += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsInstall
    Invoke-ChildScript (Join-Path $PSScriptRoot "install-extras.ps1") @("-Mode", $Mode)
  }
}

Step "analyze" {
  Invoke-ChildScript (Join-Path $PSScriptRoot "analyze-repo-governance.ps1") @("-RepoPath", $repo)
}

Step "custom-policy-check" {
  $customFiles = @(Get-ProjectCustomFilesForRepo -KitRoot $kitRoot -RepoPath $repo -RepoName $RepoName)
  if ($customFiles.Count -eq 0) {
    Write-Host "[WARN] custom policy is empty for repo: $RepoName"
    Write-Host "[ACTION] running candidate scan: suggest-project-custom-files.ps1"
    Invoke-ChildScript (Join-Path $PSScriptRoot "suggest-project-custom-files.ps1") @("-RepoPath", $repo, "-RepoName", $RepoName)
    Write-Host "[HINT] review candidates and update config/project-custom-files.json before backflow"
  } else {
    Write-Host "[INFO] custom policy files configured: $($customFiles.Count)"
  }
}

if (-not $effectiveSkipOptimize) {
  Step "optimize-project-rules" {
    $argsOptimize = @("-RepoPath", $repo, "-Mode", $Mode)
    if ($ShowScope) { $argsOptimize += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "optimize-project-rules.ps1") $argsOptimize
  }
}

if (-not $effectiveSkipBackflow) {
  Step "backflow-project-rules" {
    $argsBackflow = @("-RepoPath", $repo, "-RepoName", $RepoName, "-Mode", $Mode)
    if ($ShowScope) { $argsBackflow += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "backflow-project-rules.ps1") $argsBackflow
  }
}

if ($Mode -eq "safe") {
  Step "re-distribute-and-verify" {
    $argsRedistribute = @("-Mode", "safe")
    if ($ShowScope) { $argsRedistribute += "-ShowScope" }
    Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") $argsRedistribute
    Invoke-ChildScript (Join-Path $PSScriptRoot "doctor.ps1")
  }
}

Write-Host "run-project-governance-cycle completed: repo=$($repo -replace '\\','/') mode=$Mode"
