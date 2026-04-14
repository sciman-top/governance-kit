param(
  [Parameter(Mandatory = $true)]
  [string]$ScriptPath,
  [string[]]$ScriptArgs = @(),
  [string]$RepoRoot = ".",
  [ValidateSet("advisory", "raw")]
  [string]$Mode = "advisory",
  [int]$MaxPreviewLines = 60,
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$repoWin = $repoPath -replace '/', '\'
$scriptResolved = Resolve-Path -LiteralPath $ScriptPath -ErrorAction Stop
$scriptWin = $scriptResolved.Path

$psExe = (Get-Command powershell).Source
$captured = & $psExe -NoProfile -ExecutionPolicy Bypass -File $scriptWin @ScriptArgs 2>&1
$exitCode = $LASTEXITCODE
$allText = ($captured | Out-String)
$lines = @($allText -split "`r?`n")
$nonEmptyLines = @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

$logDir = Join-Path $repoWin ("tmp\governance-output-filter\" + (Get-Date).ToString("yyyyMMdd"))
if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
  New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logName = ("{0}-{1}.log" -f (Get-Date).ToString("HHmmss"), [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
$rawLogPath = Join-Path $logDir $logName
Set-Content -LiteralPath $rawLogPath -Value $allText -Encoding UTF8

$keyPattern = "(?i)\[FAIL\]|\[VIOLATION\]|\[MISS\]|HEALTH=|result=|status=|error|warning|alert"
$keyLines = @($nonEmptyLines | Where-Object { [regex]::IsMatch([string]$_, $keyPattern) })

$previewLines = @()
if ($Mode -eq "raw" -or $exitCode -ne 0) {
  $previewLines = @($nonEmptyLines | Select-Object -First $MaxPreviewLines)
} else {
  $head = @($nonEmptyLines | Select-Object -First ([Math]::Min(12, $MaxPreviewLines)))
  $tailQuota = [Math]::Max(0, $MaxPreviewLines - $head.Count)
  $tail = @($nonEmptyLines | Select-Object -Last ([Math]::Min(12, $tailQuota)))
  $restQuota = [Math]::Max(0, $MaxPreviewLines - $head.Count - $tail.Count)
  $middleKeys = @($keyLines | Select-Object -First $restQuota)
  $previewLines = @($head + $middleKeys + $tail)
}

$result = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToString("o")
  repo_root = $repoPath
  mode = $Mode
  script_path = ($scriptWin -replace '\\', '/')
  exit_code = [int]$exitCode
  raw_log_path = ($rawLogPath -replace '\\', '/')
  line_count_total = [int]$nonEmptyLines.Count
  line_count_key = [int]$keyLines.Count
  line_count_preview = [int]$previewLines.Count
  preview = @($previewLines)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
} else {
  Write-Host "OUTPUT_FILTER_WRAPPER"
  Write-Host ("mode={0}" -f $result.mode)
  Write-Host ("script_path={0}" -f $result.script_path)
  Write-Host ("exit_code={0}" -f $result.exit_code)
  Write-Host ("raw_log_path={0}" -f $result.raw_log_path)
  Write-Host ("line_count_total={0}" -f $result.line_count_total)
  Write-Host ("line_count_key={0}" -f $result.line_count_key)
  Write-Host ("line_count_preview={0}" -f $result.line_count_preview)
  foreach ($line in @($previewLines)) {
    Write-Host $line
  }
}

exit $exitCode

