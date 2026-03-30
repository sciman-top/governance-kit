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
. $commonPath
Write-ModeRisk -ScriptName "bootstrap-repo.ps1" -Mode $Mode
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Run-Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  & $Action
  Write-Host "[DONE] $Name"
}

if (-not $SkipInstallGlobalGit) {
  if ($Mode -eq "plan") {
    Run-Step "install-global-git" { Write-Host "[PLAN] SET global git core.hooksPath/commit.template/governance.kitRoot" }
  } else {
    Run-Step "install-global-git" { Invoke-ChildScript (Join-Path $scriptRoot 'install-global-git.ps1') }
  }
}

Run-Step "add-repo" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'add-repo.ps1') -ScriptArgs @('-RepoPath', $RepoPath, '-Mode', $Mode) }
Run-Step "merge-rules" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'merge-rules.ps1') -ScriptArgs @('-RepoPath', $RepoPath, '-Mode', $Mode) }
Run-Step "install-extras" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'install-extras.ps1') -ScriptArgs @('-Mode', $Mode) }

$installArgs = @('-Mode', $Mode)
if ($NoOverwriteRules) { $installArgs += '-NoOverwriteRules' }
if ($Mode -ne "force") {
  $installArgs += @('-NoOverwriteUnderRepo', $RepoPath)
}
Run-Step "install" { Invoke-ChildScript -ScriptPath (Join-Path $scriptRoot 'install.ps1') -ScriptArgs $installArgs }
if ($Mode -eq "plan") {
  Run-Step "doctor" { Write-Host "[PLAN] SKIP doctor in read-only mode" }
} else {
  Run-Step "doctor" { Invoke-ChildScript (Join-Path $scriptRoot 'doctor.ps1') }
}

Write-Host "bootstrap-repo completed: $RepoPath"
