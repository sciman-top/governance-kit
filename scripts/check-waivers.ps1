param(
  [switch]$ForceBlock
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$reposPath = Join-Path $kitRoot "config\repositories.json"
$rolloutPath = Join-Path $kitRoot "config\rule-rollout.json"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

if (!(Test-Path $rolloutPath)) {
  throw "rule-rollout.json not found: $rolloutPath"
}

$rollout = Get-Content -Path $rolloutPath -Raw | ConvertFrom-Json
$defaultBlock = [bool]$rollout.default.blockExpiredWaiver
$rules = @($rollout.repos)
$repos = Read-JsonArray $reposPath

$today = (Get-Date).Date
$totalFiles = 0
$expired = 0
$blocked = 0

foreach ($repoRaw in $repos) {
  $repo = Normalize-Repo ([string]$repoRaw)
  if (!(Test-Path ($repo -replace '/', '\'))) {
    Write-Host "[SKIP] repo not found: $repo"
    continue
  }

  $rule = $rules | Where-Object { (Normalize-Repo ([string]$_.repo)).Equals($repo, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
  $repoBlock = if ($ForceBlock) { $true } elseif ($null -ne $rule -and $null -ne $rule.blockExpiredWaiver) { [bool]$rule.blockExpiredWaiver } else { $defaultBlock }

  $waiverDir = Join-Path ($repo -replace '/', '\') "docs\governance\waivers"
  if (!(Test-Path $waiverDir)) {
    Write-Host "[SKIP] no waiver dir: $waiverDir"
    continue
  }

  $files = Get-ChildItem -Path $waiverDir -File -Filter *.md | Where-Object { $_.Name -ne "_template.md" -and $_.Name -ne "waiver-template.md" }
  foreach ($f in $files) {
    $totalFiles++
    $kv = Parse-KeyValueFile $f.FullName
    $status = ""
    if ($kv.ContainsKey("status")) { $status = [string]$kv["status"] }
    $statusNorm = $status.ToLowerInvariant()
    if ($statusNorm -eq "closed" -or $statusNorm -eq "recovered" -or $statusNorm -eq "done") {
      continue
    }

    $expRaw = ""
    if ($kv.ContainsKey("expires_at")) { $expRaw = [string]$kv["expires_at"] }
    if ([string]::IsNullOrWhiteSpace($expRaw)) {
      Write-Host "[WARN] waiver missing expires_at: $($f.FullName)"
      continue
    }

    $exp = Parse-IsoDate $expRaw
    if ($null -eq $exp) {
      Write-Host "[WARN] invalid expires_at: $($f.FullName) => $expRaw"
      continue
    }

    if ($exp.Date -lt $today) {
      $expired++
      if ($repoBlock) {
        Write-Host "[BLOCK] expired waiver: $($f.FullName) expires_at=$($exp.ToString('yyyy-MM-dd'))"
        $blocked++
      } else {
        Write-Host "[REMIND] expired waiver: $($f.FullName) expires_at=$($exp.ToString('yyyy-MM-dd'))"
      }
    }
  }
}

Write-Host "Waiver check done. files=$totalFiles expired=$expired blocked=$blocked"
if ($blocked -gt 0) { exit 1 }
