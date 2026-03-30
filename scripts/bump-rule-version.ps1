param(
  [Parameter(Mandatory = $true)]
  [string]$Version,
  [ValidateSet("global", "project", "all")]
  [string]$Scope = "all",
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe"
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath

if ($Version -notmatch '^[0-9]+\.[0-9]+$') {
  throw "Version must match NN.NN format, got: $Version"
}
if ($Date -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') {
  throw "Date must match yyyy-MM-dd, got: $Date"
}

$targets = @()
if ($Scope -eq "global" -or $Scope -eq "all") {
  $targets += @(
    "source\global\AGENTS.md",
    "source\global\CLAUDE.md",
    "source\global\GEMINI.md"
  )
}
if ($Scope -eq "project" -or $Scope -eq "all") {
  $projectRoot = Join-Path $kitRoot "source\project"
  if (!(Test-Path $projectRoot)) {
    throw "Project rule root not found: $projectRoot"
  }
  $projectFiles = @(Get-ChildItem -Path $projectRoot -Recurse -File | Where-Object {
    @("AGENTS.md", "CLAUDE.md", "GEMINI.md") -contains $_.Name
  })
  if ($projectFiles.Count -eq 0) {
    throw "No project rule files found under: $projectRoot"
  }
  $targets += @($projectFiles | ForEach-Object { $_.FullName })
}

$updated = 0
foreach ($rel in $targets) {
  $path = if ([System.IO.Path]::IsPathRooted([string]$rel)) { [string]$rel } else { Join-Path $kitRoot $rel }
  $display = if ([System.IO.Path]::IsPathRooted([string]$rel)) {
    $pathNorm = ([System.IO.Path]::GetFullPath($path) -replace '\\', '/')
    $rootNorm = (([System.IO.Path]::GetFullPath($kitRoot)).TrimEnd('\') -replace '\\', '/')
    if ($pathNorm.StartsWith("$rootNorm/", [System.StringComparison]::OrdinalIgnoreCase)) {
      $pathNorm.Substring($rootNorm.Length + 1)
    } else {
      $pathNorm
    }
  } else {
    ([string]$rel -replace '\\', '/')
  }
  if (!(Test-Path $path)) {
    throw "Rule file not found: $path"
  }

  $text = Read-Utf8NoBom -Path $path
  $lines = @($text -split "`r?`n")
  $versionReplaced = $false
  $dateReplaced = $false

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if (-not $versionReplaced -and $lines[$i] -match '^\*\*.+?\*+:\s*[0-9]+\.[0-9]+\s*$') {
      $lines[$i] = [regex]::Replace($lines[$i], '([0-9]+\.[0-9]+)', $Version, 1)
      $versionReplaced = $true
      continue
    }

    if (-not $dateReplaced -and $lines[$i] -match '^\*\*.+?\*+:\s*[0-9]{4}-[0-9]{2}-[0-9]{2}\s*$') {
      $lines[$i] = [regex]::Replace($lines[$i], '([0-9]{4}-[0-9]{2}-[0-9]{2})', $Date, 1)
      $dateReplaced = $true
      continue
    }
  }

  $next = ($lines -join "`r`n")
  if (-not $next.EndsWith("`r`n")) {
    $next += "`r`n"
  }

  if ($next -ne $text) {
    if ($Mode -eq "plan") {
      Write-Host "[PLAN] UPDATE $display version=$Version date=$Date"
    } else {
      Write-Utf8NoBom -Path $path -Content $next
      Write-Host "[UPDATED] $display version=$Version date=$Date"
    }
    $updated++
  } else {
    Write-Host "[SKIP] unchanged $display"
  }
}

if ($Mode -eq "plan") {
  Write-Host "Plan done. files_to_update=$updated"
} else {
  Write-Host "Done. files_updated=$updated"
}
