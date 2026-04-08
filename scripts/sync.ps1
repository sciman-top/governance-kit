param(
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [switch]$NoOverwriteRules,
  [string]$NoOverwriteUnderRepo,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
Write-ModeRisk -ScriptName "sync.ps1" -Mode $Mode

if ($NoOverwriteRules -and -not [string]::IsNullOrWhiteSpace($NoOverwriteUnderRepo)) {
  & "$PSScriptRoot\install.ps1" -NoBackup -Mode $Mode -NoOverwriteRules -NoOverwriteUnderRepo $NoOverwriteUnderRepo -AsJson:$AsJson
} elseif ($NoOverwriteRules) {
  & "$PSScriptRoot\install.ps1" -NoBackup -Mode $Mode -NoOverwriteRules -AsJson:$AsJson
} elseif (-not [string]::IsNullOrWhiteSpace($NoOverwriteUnderRepo)) {
  & "$PSScriptRoot\install.ps1" -NoBackup -Mode $Mode -NoOverwriteUnderRepo $NoOverwriteUnderRepo -AsJson:$AsJson
} else {
  & "$PSScriptRoot\install.ps1" -NoBackup -Mode $Mode -AsJson:$AsJson
}

if ($LASTEXITCODE -ne 0) {
  throw "sync failed with exit code ${LASTEXITCODE}"
}
