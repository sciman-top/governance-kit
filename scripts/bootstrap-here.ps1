param(
  [switch]$SkipInstallGlobalGit,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$NoOverwriteRules
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonPath = Join-Path $scriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "bootstrap-here.ps1" -Mode $Mode
$repoPath = (Get-Location).Path
$psExe = (Get-Process -Id $PID).Path

$args = @(
  "-File", (Join-Path $scriptRoot "bootstrap-repo.ps1"),
  "-RepoPath", $repoPath,
  "-Mode", $Mode
)
if ($SkipInstallGlobalGit) { $args += "-SkipInstallGlobalGit" }
if ($NoOverwriteRules) { $args += "-NoOverwriteRules" }

& $psExe -NoProfile -ExecutionPolicy Bypass @args
if ($LASTEXITCODE -ne 0) {
  throw "bootstrap-here failed with exit code ${LASTEXITCODE}"
}
