param(
  [string]$RepoPath,
  [string]$RepoName,
  [Parameter(Mandatory = $true)]
  [string]$Enabled,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe"
)

$ErrorActionPreference = "Stop"
$legacyScript = Join-Path $PSScriptRoot "set-codex-runtime-policy.ps1"
if (-not (Test-Path -LiteralPath $legacyScript -PathType Leaf)) {
  throw "Missing script: $legacyScript"
}

$argsList = @()
foreach ($key in $PSBoundParameters.Keys) {
  $argsList += "-$key"
  $argsList += [string]$PSBoundParameters[$key]
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $legacyScript @argsList
exit $LASTEXITCODE
