param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$RepoName,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe",
  [ValidateSet("changed", "all")]
  [string]$EvidenceMode = "all",
  [double]$EvidenceThreshold = 98.0,
  [switch]$AutoBackfillEvidence = $true,
  [switch]$SkipEndstateLoop,
  [switch]$AsJson
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "run-endstate-onboarding.ps1" -Mode $Mode

$repoResolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $repoResolved -or -not (Test-Path -LiteralPath $repoResolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($repoResolved.Path)
if ([string]::IsNullOrWhiteSpace($RepoName)) {
  $RepoName = Split-Path -Leaf $repo
}

$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Step([string]$Name, [scriptblock]$Action) {
  Write-Host "=== $Name ==="
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $ok = $false
  $err = $null
  try {
    & $Action
    $ok = $true
    Write-Host "[PASS] $Name"
  } catch {
    $err = $_.Exception.Message
    Write-Host "[FAIL] $Name"
    Write-Host $_
  } finally {
    $sw.Stop()
  }

  $row = [pscustomobject]@{
    step = $Name
    status = if ($ok) { "PASS" } else { "FAIL" }
    duration_ms = [int][math]::Round($sw.Elapsed.TotalMilliseconds)
    error = $err
  }
  [void]$results.Add($row)
  if (-not $ok) {
    throw "Step failed: $Name"
  }
}

Invoke-Step "add-repo" {
  Invoke-ChildScript (Join-Path $PSScriptRoot "add-repo.ps1") @("-RepoPath", $repo, "-Mode", $Mode)
}

Invoke-Step "install" {
  Invoke-ChildScript (Join-Path $PSScriptRoot "install.ps1") @("-Mode", $Mode)
}

Invoke-Step "install-extras" {
  Invoke-ChildScript (Join-Path $PSScriptRoot "install-extras.ps1") @("-Mode", $Mode)
}

$checkEvidence = Join-Path $repo "scripts/governance/check-evidence-completeness.ps1"
$backfillEvidence = Join-Path $repo "scripts/governance/backfill-evidence-template-fields.ps1"
$runLoop = Join-Path $repo "scripts/governance/run-endstate-loop.ps1"
$isPlan = $Mode -eq "plan"

if (-not $isPlan -and (Test-Path -LiteralPath $checkEvidence -PathType Leaf)) {
  $evidenceArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $checkEvidence, "-Mode", $EvidenceMode, "-Threshold", ([string]$EvidenceThreshold))

  $evidenceOk = $true
  try {
    Invoke-Step "evidence-check-initial" {
      & powershell @evidenceArgs
      if ($LASTEXITCODE -ne 0) { throw "evidence check failed: exit=$LASTEXITCODE" }
    }
  } catch {
    $evidenceOk = $false
    if (-not $AutoBackfillEvidence) { throw }
  }

  if (-not $evidenceOk -and $AutoBackfillEvidence -and (Test-Path -LiteralPath $backfillEvidence -PathType Leaf)) {
    Invoke-Step "evidence-backfill" {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $backfillEvidence
      if ($LASTEXITCODE -ne 0) { throw "evidence backfill failed: exit=$LASTEXITCODE" }
    }

    Invoke-Step "evidence-check-after-backfill" {
      & powershell @evidenceArgs
      if ($LASTEXITCODE -ne 0) { throw "evidence re-check failed: exit=$LASTEXITCODE" }
    }
  }
}

if (-not $isPlan -and -not $SkipEndstateLoop -and (Test-Path -LiteralPath $runLoop -PathType Leaf)) {
  Invoke-Step "endstate-loop" {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runLoop -Profile quick -Configuration Debug -EvidenceMode $EvidenceMode
    if ($LASTEXITCODE -ne 0) { throw "endstate loop failed: exit=$LASTEXITCODE" }
  }
}

if (-not $isPlan) {
  Invoke-Step "doctor" {
    Invoke-ChildScript (Join-Path $PSScriptRoot "doctor.ps1") @()
  }
} else {
  Write-Host "[PLAN] skip evidence/backfill/endstate-loop/doctor"
}

$failed = @($results | Where-Object { $_.status -ne "PASS" })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
Write-Host "run-endstate-onboarding completed. repo=$($repo -replace '\\','/') mode=$Mode status=$status"

if ($AsJson) {
  [pscustomobject]@{
    repo = ($repo -replace '\\','/')
    repo_name = $RepoName
    mode = $Mode
    evidence_mode = $EvidenceMode
    auto_backfill_evidence = [bool]$AutoBackfillEvidence
    status = $status
    steps = @($results)
  } | ConvertTo-Json -Depth 8 | Write-Output
}

if ($status -ne "PASS") {
  exit 1
}
