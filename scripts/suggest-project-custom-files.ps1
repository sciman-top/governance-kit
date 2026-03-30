param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$RepoName,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
if ([string]::IsNullOrWhiteSpace($RepoName)) {
  $RepoName = Split-Path -Leaf $repo
}

$set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$candidates = [System.Collections.Generic.List[string]]::new()

function Add-Candidate([string]$AbsolutePath) {
  if (!(Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) { return }
  $full = [System.IO.Path]::GetFullPath($AbsolutePath)
  $rel = $full.Substring($repo.Length).TrimStart('\') -replace '\\','/'
  if ($set.Add($rel)) {
    [void]$candidates.Add($rel)
  }
}

# 1) CI workflow candidates
$workflowDir = Join-Path $repo ".github\workflows"
if (Test-Path -LiteralPath $workflowDir -PathType Container) {
  foreach ($f in @(Get-ChildItem -LiteralPath $workflowDir -File -Filter "quality-gate*.yml" -ErrorAction SilentlyContinue)) {
    Add-Candidate $f.FullName
  }
}

# 2) Core governance scripts
Add-Candidate (Join-Path $repo "scripts\install-githooks.ps1")
Add-Candidate (Join-Path $repo "scripts\prebuild-check.ps1")

# 3) ACL-related scripts (repo-specific risk controls)
$scriptsDir = Join-Path $repo "scripts"
if (Test-Path -LiteralPath $scriptsDir -PathType Container) {
  foreach ($f in @(Get-ChildItem -LiteralPath $scriptsDir -File -Filter "*acl*.ps1" -ErrorAction SilentlyContinue)) {
    Add-Candidate $f.FullName
  }
}

# 4) Validation profiles (if present)
$validationDir = Join-Path $repo "scripts\validation"
if (Test-Path -LiteralPath $validationDir -PathType Container) {
  foreach ($f in @(Get-ChildItem -LiteralPath $validationDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".ps1", ".json") })) {
    Add-Candidate $f.FullName
  }
}

$ordered = @($candidates | Sort-Object)
$result = [pscustomobject]@{
  repo_name = $RepoName
  repo_path = ($repo -replace '\\','/')
  candidate_count = $ordered.Count
  candidates = $ordered
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 6
  exit 0
}

if ($ordered.Count -eq 0) {
  Write-Host "No candidate custom files detected for repo: $RepoName"
  exit 0
}

Write-Host "Candidate custom files for repo: $RepoName"
foreach ($c in $ordered) {
  Write-Host ("- " + $c)
}
