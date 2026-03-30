$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$hooksPath = Join-Path $kitRoot "hooks-global"
$commitTpl = Join-Path $kitRoot "templates\commit-template.txt"

if (!(Test-Path $hooksPath)) { throw "hooks-global not found: $hooksPath" }
if (!(Test-Path $commitTpl)) { throw "commit template not found: $commitTpl" }

try {
  git --version | Out-Null
} catch {
  throw "git not found in PATH"
}

$hooksPathGit = $hooksPath -replace '\\','/'
$commitTplGit = $commitTpl -replace '\\','/'

git config --global core.hooksPath $hooksPathGit
git config --global commit.template $commitTplGit
git config --global governance.kitRoot ($kitRoot -replace '\\','/')

Write-Host "[SET] git config --global core.hooksPath=$hooksPathGit"
Write-Host "[SET] git config --global commit.template=$commitTplGit"
Write-Host "[SET] git config --global governance.kitRoot=$($kitRoot -replace '\\','/')"
Write-Host "install-global-git done"
