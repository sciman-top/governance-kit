param(
  [Parameter(Mandatory=$true)]
  [string]$RepoPath,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe"
)

$ErrorActionPreference = "Stop"
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
$kitRoot = Split-Path -Parent $PSScriptRoot
$targetsPath = Join-Path $kitRoot "config\targets.json"
if (!(Test-Path $targetsPath)) {
  throw "targets.json not found: $targetsPath"
}
Write-ModeRisk -ScriptName "merge-rules.ps1" -Mode $Mode

$repoNorm = ([System.IO.Path]::GetFullPath(($RepoPath -replace "/", "\\")) -replace "\\", "/").TrimEnd("/")
$repoWin = $repoNorm -replace "/", "\\"
if (!(Test-Path $repoWin)) {
  throw "Repo path not found: $RepoPath"
}

$targetsRaw = Get-Content -Path $targetsPath -Raw | ConvertFrom-Json
$targets = if ($targetsRaw -is [System.Array]) { @($targetsRaw) } else { @($targetsRaw) }
$targetPrefix = "$repoNorm/"
$entries = @($targets | Where-Object {
  $t = [string]$_.target
  $t.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase)
})

if ($entries.Count -eq 0) {
  Write-Host "[SKIP] no rule targets found for repo: $repoNorm"
  exit 0
}

function Normalize-Eol([string]$Text) {
  return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Get-SectionC([string]$Text) {
  $m = [regex]::Match((Normalize-Eol $Text), "(?ms)^##\s+C\..*?(?=^##\s+|\z)")
  if ($m.Success) { return $m.Value }
  return $null
}

function Merge-RuleContent([string]$SourceText, [string]$DestText, [string]$FileName) {
  $src = Normalize-Eol $SourceText
  $dst = Normalize-Eol $DestText
  $notes = @()
  $merged = $src

  $preserveProjectSectionC = @("AGENTS.md", "CLAUDE.md", "GEMINI.md") -contains $FileName
  if ($preserveProjectSectionC) {
    $srcC = Get-SectionC $src
    $dstC = Get-SectionC $dst
    if ($null -ne $srcC -and $null -ne $dstC) {
      $merged = $src.Replace($srcC, $dstC)
      $notes += "KEEP_LOCAL ## C."
    }
  }

  $localExt = [regex]::Match($dst, "(?ms)^##\s+Local\b.*")
  if ($localExt.Success -and -not $merged.Contains($localExt.Value.Trim())) {
    $merged = $merged.TrimEnd() + "`n`n" + $localExt.Value.Trim() + "`n"
    $notes += "APPEND_LOCAL ## Local"
  }

  return [pscustomobject]@{
    content = ($merged.TrimEnd() + "`n") -replace "`n", "`r`n"
    notes = $notes
  }
}

$plan = $Mode -eq "plan"
$changed = 0
$created = 0
$skipped = 0
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $kitRoot ("backups\\merge-" + $timestamp)

$reportLines = @(
  "# Rule Merge Report",
  "",
  "repo=$repoNorm",
  "mode=$Mode",
  "time=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  ""
)

foreach ($e in $entries) {
  $src = Join-Path $kitRoot ([string]$e.source)
  $dst = [System.IO.Path]::GetFullPath(([string]$e.target -replace "/", [string][System.IO.Path]::DirectorySeparatorChar))
  $label = (Split-Path -Leaf $src) + " -> " + $dst

  if (!(Test-Path $src)) {
    Write-Host "[WARN] source missing: $src"
    $reportLines += "- WARN source missing: $src"
    continue
  }

  if (!(Test-Path $dst)) {
    if ($plan) {
      Write-Host "[PLAN] CREATE $label"
      $reportLines += "- PLAN CREATE $label"
      continue
    }

    $dstDir = Split-Path -Parent $dst
    if (!(Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item -Path $src -Destination $dst -Force
    $created++
    Write-Host "[COPIED] CREATE $label"
    $reportLines += "- CREATE $label"
    continue
  }

  $srcText = Get-Content -Path $src -Raw
  $dstText = Get-Content -Path $dst -Raw
  $fileName = Split-Path -Leaf $dst
  $merged = Merge-RuleContent -SourceText $srcText -DestText $dstText -FileName $fileName

  $same = (Normalize-Eol $dstText).TrimEnd() -eq (Normalize-Eol $merged.content).TrimEnd()
  if ($same) {
    Write-Host "[SKIP] unchanged after merge: $label"
    $skipped++
    $reportLines += "- KEEP $label"
    continue
  }

  if ($plan) {
    Write-Host "[PLAN] MERGE $label"
    foreach ($n in $merged.notes) { Write-Host "       $n" }
    $reportLines += "- PLAN MERGE $label"
    foreach ($n in $merged.notes) { $reportLines += "  - $n" }
    continue
  }

  $rel = $dst.Replace(":", "").TrimStart([char]92)
  $backupPath = Join-Path $backupRoot $rel
  $backupDir = Split-Path -Parent $backupPath
  if (!(Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
  Copy-Item -Path $dst -Destination $backupPath -Force

  Set-Content -Path $dst -Value $merged.content -Encoding UTF8
  $changed++
  Write-Host "[MERGED] $label"
  foreach ($n in $merged.notes) { Write-Host "         $n" }
  $reportLines += "- MERGED $label"
  foreach ($n in $merged.notes) { $reportLines += "  - $n" }
}

if (-not $plan) {
  $reportDir = Join-Path $repoWin "docs\governance"
  if (!(Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
  $reportPath = Join-Path $reportDir "merge-report.md"
  Set-Content -Path $reportPath -Value ($reportLines -join "`r`n") -Encoding UTF8
  Write-Host "[REPORT] $reportPath"
  if ($changed -gt 0) { Write-Host "[BACKUP] $backupRoot" }
}

Write-Host "merge-rules done. created=$created changed=$changed skipped=$skipped mode=$Mode"
