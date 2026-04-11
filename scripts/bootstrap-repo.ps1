param(
  [Parameter(Mandatory=$true)]
  [string]$RepoPath,
  [switch]$SkipInstallGlobalGit,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$NoOverwriteRules
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
Write-ModeRisk -ScriptName "bootstrap-repo.ps1" -Mode $Mode
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$kitRoot = Split-Path -Parent $scriptRoot
$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repoFullPath = [System.IO.Path]::GetFullPath($repoResolved.Path)
$skipRepoOverwriteProtection = $repoFullPath.Equals($kitRoot, [System.StringComparison]::OrdinalIgnoreCase)

function Run-Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  & $Action
  Write-Host "[DONE] $Name"
}

if (-not $SkipInstallGlobalGit) {
  if ($Mode -eq "plan") {
    Run-Step "install-global-git" { Write-Host "[PLAN] SET global git core.hooksPath/commit.template/governance.kitRoot" }
  } else {
    Run-Step "install-global-git" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'install-global-git.ps1') }
  }
}

Run-Step "add-repo" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'add-repo.ps1') -ScriptArgs @('-RepoPath', $RepoPath, '-Mode', $Mode) }
Run-Step "merge-rules" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'merge-rules.ps1') -ScriptArgs @('-RepoPath', $RepoPath, '-Mode', $Mode) }
Run-Step "install-extras" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'install-extras.ps1') -ScriptArgs @('-Mode', $Mode) }

$installArgs = @('-Mode', $Mode)
if ($NoOverwriteRules) { $installArgs += '-NoOverwriteRules' }
if ($Mode -ne "force" -and -not $skipRepoOverwriteProtection) {
  $installArgs += @('-NoOverwriteUnderRepo', $RepoPath)
} elseif ($skipRepoOverwriteProtection) {
  Write-Host "[INFO] bootstrap target is repo-governance-hub itself; skip -NoOverwriteUnderRepo self-protection."
}
Run-Step "install" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'install.ps1') -ScriptArgs $installArgs }
if ($Mode -eq "plan") {
  Run-Step "doctor" { Write-Host "[PLAN] SKIP doctor in read-only mode" }
} else {
  Run-Step "doctor" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'doctor.ps1') }
}

Write-Host "bootstrap-repo completed: $RepoPath"

