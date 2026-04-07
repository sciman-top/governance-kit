param(
  [string]$RepoRoot = ".",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$ruleFiles = @()

$globalRuleDir = Join-Path $root "source\global"
if (Test-Path -LiteralPath $globalRuleDir -PathType Container) {
  foreach ($name in @("AGENTS.md", "CLAUDE.md", "GEMINI.md")) {
    $p = Join-Path $globalRuleDir $name
    if (Test-Path -LiteralPath $p -PathType Leaf) { $ruleFiles += $p }
  }
}

$projectRuleRoot = Join-Path $root "source\project"
if (Test-Path -LiteralPath $projectRuleRoot -PathType Container) {
  $projectFiles = Get-ChildItem -Path $projectRuleRoot -Recurse -File | Where-Object {
    @("AGENTS.md", "CLAUDE.md", "GEMINI.md") -contains $_.Name
  }
  $ruleFiles += @($projectFiles | ForEach-Object { $_.FullName })
}

$issues = New-Object System.Collections.Generic.List[object]

foreach ($file in $ruleFiles) {
  $lines = Get-Content -LiteralPath $file

  # 1) Duplicate headings in the same rule document usually indicate repeated block injection.
  $headingCount = @{}
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = [string]$lines[$i]
    $m = [regex]::Match($line, "^(#{2,4}\s+.+)$")
    if (-not $m.Success) { continue }
    $heading = $m.Groups[1].Value.Trim()
    if (-not $headingCount.ContainsKey($heading)) { $headingCount[$heading] = @() }
    $headingCount[$heading] += ($i + 1)
  }

  foreach ($key in $headingCount.Keys) {
    $positions = @($headingCount[$key])
    if ($positions.Count -gt 1) {
      $issues.Add([pscustomobject]@{
        file = ($file -replace '\\', '/')
        type = "duplicate_heading"
        line = [int]$positions[1]
        detail = "$key (count=$($positions.Count))"
      }) | Out-Null
    }
  }

  # 2) Consecutive non-empty identical lines are usually accidental duplication noise.
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $prev = [string]$lines[$i - 1]
    $curr = [string]$lines[$i]
    if ([string]::IsNullOrWhiteSpace($prev) -or [string]::IsNullOrWhiteSpace($curr)) { continue }
    if ($prev.Trim() -eq $curr.Trim()) {
      $issues.Add([pscustomobject]@{
        file = ($file -replace '\\', '/')
        type = "duplicate_adjacent_line"
        line = [int]($i + 1)
        detail = $curr.Trim()
      }) | Out-Null
    }
  }
}

$result = @{
  repo_root = ($root -replace '\\', '/')
  scanned_file_count = [int]$ruleFiles.Count
  issue_count = [int]$issues.Count
  issues = @($issues.ToArray())
}

if ($AsJson.IsPresent) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  if ($issues.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host ("rule_dup.repo_root=" + $result.repo_root)
Write-Host ("rule_dup.scanned_file_count=" + $result.scanned_file_count)
Write-Host ("rule_dup.issue_count=" + $result.issue_count)
if ($issues.Count -gt 0) {
  foreach ($issue in $issues) {
    Write-Host ("[DUPLICATION] {0}:{1} {2} {3}" -f $issue.file, $issue.line, $issue.type, $issue.detail)
  }
  exit 1
}
Write-Host "[PASS] rule duplication check passed"
exit 0
