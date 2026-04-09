param(
  [Parameter(Mandatory=$true)]
  [string]$RepoPath,
  [ValidateSet("plan", "safe", "force")]
  [string]$Mode = "safe"
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot
$commonPath = Join-Path $PSScriptRoot "lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath
Write-ModeRisk -ScriptName "remove-repo.ps1" -Mode $Mode
$repo = ([System.IO.Path]::GetFullPath(($RepoPath -replace '/', '\')) -replace '\\','/').TrimEnd('/')

$reposPath = Join-Path $kitRoot "config\repositories.json"
$targetsPath = Join-Path $kitRoot "config\targets.json"
$projectPolicyPath = Get-ProjectRulePolicyPath $kitRoot
$projectCustomPath = Join-Path $kitRoot "config\project-custom-files.json"
$repoName = Split-Path -Leaf $repo

$repos = Read-JsonArray $reposPath
$newRepos = @($repos | Where-Object { -not ([string]$_).Equals($repo, [System.StringComparison]::OrdinalIgnoreCase) })
$repoRemoved = $repos.Count - $newRepos.Count

$targets = Read-JsonArray $targetsPath
$repoPrefix = "$repo/"
$filtered = @($targets | Where-Object {
  $target = [string]$_.target
  -not $target.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)
})
$removed = $targets.Count - $filtered.Count

$projectRuleAllowRemoved = 0
$projectRuleAllowUpdated = $false
$policy = $null
$policyFilteredAllow = @()
if (Test-Path $projectPolicyPath) {
  $policy = Read-JsonFile -Path $projectPolicyPath -DisplayName $projectPolicyPath
  $allowRepos = if ($null -eq $policy.allowProjectRulesForRepos) { @() } else { @($policy.allowProjectRulesForRepos) }
  foreach ($allow in $allowRepos) {
    $allowNorm = Normalize-Repo ([string]$allow)
    if ($allowNorm.Equals($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
      $projectRuleAllowRemoved++
    } else {
      $policyFilteredAllow += $allowNorm
    }
  }
  $projectRuleAllowUpdated = $projectRuleAllowRemoved -gt 0
}

$customPolicyRemoved = 0
$customPolicyUpdated = $false
$customCfg = $null
$customCfgReposFiltered = @()
if (Test-Path -LiteralPath $projectCustomPath) {
  try {
    $customCfg = Read-JsonFile -Path $projectCustomPath -DisplayName $projectCustomPath
  } catch {
    throw "project-custom-files.json invalid JSON: $projectCustomPath"
  }

  $customCfgRepos = if ($null -eq $customCfg.repos) { @() } else { @($customCfg.repos) }
  foreach ($entry in $customCfgRepos) {
    if ($null -eq $entry) { continue }
    $matched = $false
    if ($entry.PSObject.Properties['repoName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repoName)) {
      if (([string]$entry.repoName).Equals($repoName, [System.StringComparison]::OrdinalIgnoreCase)) {
        $matched = $true
      }
    }
    if (-not $matched -and $entry.PSObject.Properties['repo'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.repo)) {
      $entryRepoNorm = Normalize-Repo ([string]$entry.repo)
      if ($entryRepoNorm.Equals($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
        $matched = $true
      }
    }

    if ($matched) {
      $customPolicyRemoved++
    } else {
      $customCfgReposFiltered += $entry
    }
  }
  $customPolicyUpdated = $customPolicyRemoved -gt 0
}

if ($Mode -eq "plan") {
  Write-Host "[PLAN] repositories removed=$repoRemoved target_repo=$repo"
  Write-Host "[PLAN] removed_targets=$removed"
  if ($projectRuleAllowUpdated) {
    Write-Host "[PLAN] removed_project_rule_allow_repos=$projectRuleAllowRemoved"
  }
  if ($customPolicyUpdated) {
    Write-Host "[PLAN] removed_custom_policy_repos=$customPolicyRemoved"
  }
  Write-Host "Plan done."
  exit 0
}

Write-JsonArray $reposPath $newRepos 4
Write-Host "[UPDATED] repositories removed: $repo"
Write-JsonArray $targetsPath $filtered 6
if ($projectRuleAllowUpdated) {
  $policy.allowProjectRulesForRepos = @($policyFilteredAllow)
  $policy | ConvertTo-Json -Depth 8 | Set-Content -Path $projectPolicyPath -Encoding UTF8
  Write-Host "[UPDATED] removed_project_rule_allow_repos=$projectRuleAllowRemoved"
}
if ($customPolicyUpdated) {
  $customCfg.repos = @($customCfgReposFiltered)
  $customCfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $projectCustomPath -Encoding UTF8
  Write-Host "[UPDATED] removed_custom_policy_repos=$customPolicyRemoved"
}
Write-Host "[UPDATED] removed_targets=$removed mode=$Mode"
