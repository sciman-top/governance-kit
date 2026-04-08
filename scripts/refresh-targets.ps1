param(
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$reposPath = Join-Path $kitRoot "config\repositories.json"
$addRepoScript = Join-Path $PSScriptRoot "add-repo.ps1"
if (-not (Test-Path -LiteralPath $reposPath -PathType Leaf)) {
  throw "repositories.json not found: $reposPath"
}
if (-not (Test-Path -LiteralPath $addRepoScript -PathType Leaf)) {
  throw "add-repo.ps1 not found: $addRepoScript"
}

$repos = Read-JsonArray $reposPath
$items = New-Object System.Collections.Generic.List[object]
$updatedTargets = 0

foreach ($repo in @($repos)) {
  $repoText = [string]$repo
  if ([string]::IsNullOrWhiteSpace($repoText)) { continue }

  $out = Invoke-ChildScriptCapture -ScriptPath $addRepoScript -ScriptArgs @("-RepoPath", $repoText, "-Mode", $Mode)
  $text = ($out | Out-String).Trim()

  $m = [regex]::Match($text, "updated_targets=([0-9]+)")
  if ($m.Success) {
    $updatedTargets += [int]$m.Groups[1].Value
  }

  $mAdd = [regex]::Match($text, "added_targets=([0-9]+)")
  if ($mAdd.Success) {
    $updatedTargets += [int]$mAdd.Groups[1].Value
  }

  $items.Add([pscustomobject]@{
    repo = $repoText
    mode = $Mode
    key_output = $text
  }) | Out-Null
}

$result = @{
  mode = $Mode
  repo_count = @($repos).Count
  target_change_count = [int]$updatedTargets
  items = @($items.ToArray())
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6 | Write-Output
} else {
  Write-Host ("refresh_targets.mode=" + $Mode)
  Write-Host ("refresh_targets.repo_count=" + $result.repo_count)
  Write-Host ("refresh_targets.target_change_count=" + $result.target_change_count)
}
