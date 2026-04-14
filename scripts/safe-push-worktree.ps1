param(
  [Parameter(Mandatory = $true)]
  [string]$RepoPath,
  [string]$Commit = "HEAD",
  [string]$Remote = "origin",
  [string]$Branch = "main",
  [ValidateSet("plan", "safe")]
  [string]$Mode = "safe",
  [string]$WorktreeRoot = "",
  [switch]$KeepWorktreeOnSuccess,
  [switch]$KeepWorktreeOnError
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
. $commonPath
Write-ModeRisk -ScriptName "safe-push-worktree.ps1" -Mode $Mode

function Get-RunStamp {
  return (Get-Date -Format "yyyyMMdd-HHmmss")
}

function Run-Git {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string[]]$Args
  )
  & git -C $Repo @Args
  if ($LASTEXITCODE -ne 0) {
    throw "git failed (repo=$Repo): git -C $Repo $($Args -join ' ')"
  }
}

function Resolve-HeadCommit {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$Ref
  )
  $value = (& git -C $Repo rev-parse --verify $Ref 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
    throw "Cannot resolve commit/ref '$Ref' in repo: $Repo"
  }
  return $value.Trim()
}

function Test-CommitContainedInRef {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$CommitSha,
    [Parameter(Mandatory = $true)][string]$RefName
  )

  & git -C $Repo merge-base --is-ancestor $CommitSha $RefName 2>$null
  if ($LASTEXITCODE -eq 0) { return $true }
  if ($LASTEXITCODE -eq 1) { return $false }
  throw "Cannot determine ancestry for commit=$CommitSha ref=$RefName in repo=$Repo"
}

$resolved = Resolve-Path -LiteralPath $RepoPath -ErrorAction SilentlyContinue
if ($null -eq $resolved -or -not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
  throw "Repo path not found: $RepoPath"
}
$repo = [System.IO.Path]::GetFullPath($resolved.Path)
$repoName = Split-Path -Leaf $repo
$commitSha = Resolve-HeadCommit -Repo $repo -Ref $Commit
$stamp = Get-RunStamp
$workspaceRoot = Split-Path -Parent $repo
$defaultWorktreeRoot = Join-Path $env:USERPROFILE ".config\superpowers\worktrees"
if ([string]::IsNullOrWhiteSpace($WorktreeRoot)) {
  $WorktreeRoot = Join-Path $defaultWorktreeRoot $repoName
}
$worktreeBase = [System.IO.Path]::GetFullPath(($WorktreeRoot -replace '/', '\'))
$worktreePath = Join-Path $worktreeBase ($repoName + "-" + $stamp)
$remoteRef = "$Remote/$Branch"

Write-Host "repo=$repo"
Write-Host "commit=$commitSha"
Write-Host "remote_ref=$remoteRef"
Write-Host "worktree=$worktreePath"

if ($Mode -eq "plan") {
  Write-Host "[PLAN] git -C $repo fetch $Remote $Branch"
  Write-Host "[PLAN] git -C $repo worktree add $worktreePath $remoteRef"
  Write-Host "[PLAN] git -C $worktreePath cherry-pick $commitSha"
  Write-Host "[PLAN] git -C $worktreePath push $Remote HEAD:$Branch"
  Write-Host "[PLAN] git -C $repo worktree remove $worktreePath --force"
  exit 0
}

New-Item -ItemType Directory -Force -Path $worktreeBase | Out-Null
Run-Git -Repo $repo -Args @("fetch", $Remote, $Branch)
if (Test-CommitContainedInRef -Repo $repo -CommitSha $commitSha -RefName $remoteRef) {
  Write-Host "[NOOP] commit already exists in $remoteRef, nothing to push."
  exit 0
}
Run-Git -Repo $repo -Args @("worktree", "add", $worktreePath, $remoteRef)

$success = $false
try {
  Run-Git -Repo $worktreePath -Args @("cherry-pick", $commitSha)
  Run-Git -Repo $worktreePath -Args @("push", $Remote, "HEAD:$Branch")
  $success = $true
  Write-Host "[DONE] pushed commit $commitSha to $Remote/$Branch via worktree"
}
catch {
  Write-Host "[FAIL] $($_.Exception.Message)"
  if ($KeepWorktreeOnError.IsPresent) {
    Write-Host "[KEEP] worktree kept for troubleshooting: $worktreePath"
  } else {
    try {
      Run-Git -Repo $repo -Args @("worktree", "remove", $worktreePath, "--force")
    } catch {
      Write-Host "[WARN] failed to cleanup worktree: $worktreePath"
    }
  }
  throw
}
finally {
  if ($success -and -not $KeepWorktreeOnSuccess.IsPresent) {
    try {
      Run-Git -Repo $repo -Args @("worktree", "remove", $worktreePath, "--force")
    } catch {
      Write-Host "[WARN] failed to cleanup worktree: $worktreePath"
    }
  }
}
