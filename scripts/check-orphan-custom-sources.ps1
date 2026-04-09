param(
  [switch]$FailOnOrphans,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

$targetsPath = Join-Path $kitRoot "config\targets.json"
$customPath = Join-Path $kitRoot "config\project-custom-files.json"
$projectRoot = Join-Path $kitRoot "source\project"

if (!(Test-Path -LiteralPath $targetsPath)) { throw "targets.json not found: $targetsPath" }
if (!(Test-Path -LiteralPath $customPath)) { throw "project-custom-files.json not found: $customPath" }
if (!(Test-Path -LiteralPath $projectRoot)) { throw "source/project not found: $projectRoot" }

$targets = @(Read-JsonArray $targetsPath)
$customCfg = Read-JsonFile -Path $customPath -DisplayName $customPath

$mappedSourceSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($t in $targets) {
  if ($null -eq $t) { continue }
  $s = [string]$t.source
  if (-not [string]::IsNullOrWhiteSpace($s)) {
    [void]$mappedSourceSet.Add(($s -replace '\\', '/'))
  }
}

$customPolicyByRepo = @{}
if ($null -ne $customCfg.repos) {
  foreach ($entry in @($customCfg.repos)) {
    if ($null -eq $entry) { continue }
    $repoName = [string]$entry.repoName
    if ([string]::IsNullOrWhiteSpace($repoName)) { continue }
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in @($entry.files)) {
      if ([string]::IsNullOrWhiteSpace([string]$f)) { continue }
      [void]$set.Add((([string]$f) -replace '\\', '/').TrimStart('/'))
    }
    $customPolicyByRepo[$repoName] = $set
  }
}

$orphans = [System.Collections.Generic.List[object]]::new()
$repoDirs = @(Get-ChildItem -Path $projectRoot -Directory -ErrorAction SilentlyContinue)
foreach ($repoDir in $repoDirs) {
  $repoName = $repoDir.Name
  $customDir = Join-Path $repoDir.FullName "custom"
  if (!(Test-Path -LiteralPath $customDir)) { continue }

  $policySet = $null
  if ($customPolicyByRepo.ContainsKey($repoName)) {
    $policySet = $customPolicyByRepo[$repoName]
  }

  $files = @(Get-ChildItem -Path $customDir -Recurse -File -ErrorAction SilentlyContinue)
  foreach ($f in $files) {
    $rel = Get-RelativePathSafe -BasePath $customDir -TargetPath $f.FullName
    $relNorm = $rel -replace '\\', '/'
    $sourceRel = "source/project/$repoName/custom/$relNorm"
    $inTargets = $mappedSourceSet.Contains($sourceRel)
    $inPolicy = ($null -ne $policySet) -and $policySet.Contains($relNorm)
    if (-not $inTargets -and -not $inPolicy) {
      [void]$orphans.Add([pscustomobject]@{
        repo = $repoName
        source = $sourceRel
        path = $f.FullName
      })
    }
  }
}

if (-not $AsJson) {
  foreach ($o in $orphans) {
    Write-Host "[ORPHAN] $($o.source)"
  }
  Write-Host "orphan-custom-source check done. count=$($orphans.Count)"
}

if ($AsJson) {
  @{
    orphan_count = $orphans.Count
    items = @($orphans)
  } | ConvertTo-Json -Depth 6 | Write-Output
}

if ($FailOnOrphans -and $orphans.Count -gt 0) {
  exit 1
}
