param(
  [string]$RepoRoot = ".",
  [string]$PolicyRelativePath = ".governance/risk-tier-approval-policy.json",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath([string]$PathText) {
  $resolved = Resolve-Path -LiteralPath $PathText -ErrorAction Stop
  return ([System.IO.Path]::GetFullPath($resolved.Path) -replace '\\', '/').TrimEnd('/')
}

function New-Result([string]$RepoPath, [string]$PolicyPath) {
  return [ordered]@{
    schema_version = "1.0"
    generated_at = (Get-Date).ToString("o")
    repo_root = $RepoPath
    policy_path = $PolicyPath
    status = "unknown"
    high_risk_operation_count = 0
    high_risk_without_explicit_path_count = 0
    invalid_entry_count = 0
    invalid_entries = @()
  }
}

function Add-InvalidEntry([System.Collections.Generic.List[object]]$Bag, [string]$Group, [string]$Id, [string]$Reason) {
  $Bag.Add([pscustomobject]@{
    group = $Group
    id = $Id
    reason = $Reason
  }) | Out-Null
}

$repoPath = Resolve-NormalizedPath $RepoRoot
$policyPath = Join-Path ($repoPath -replace '/', '\\') ($PolicyRelativePath -replace '/', '\\')
$result = New-Result -RepoPath $repoPath -PolicyPath ($policyPath -replace '\\', '/')
$invalidEntries = New-Object System.Collections.Generic.List[object]

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  $result.status = "missing_policy"
  $result.invalid_entry_count = 1
  Add-InvalidEntry -Bag $invalidEntries -Group "policy" -Id "missing" -Reason "risk-tier-approval policy file not found"
  $result.invalid_entries = @($invalidEntries.ToArray())
  if ($AsJson) { $result | ConvertTo-Json -Depth 8 | Write-Output } else { Write-Host "risk_tier_approval.status=missing_policy" }
  exit 1
}

$policy = $null
try {
  $policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
  $result.status = "invalid_json"
  $result.invalid_entry_count = 1
  Add-InvalidEntry -Bag $invalidEntries -Group "policy" -Id "json" -Reason "policy json parse failed"
  $result.invalid_entries = @($invalidEntries.ToArray())
  if ($AsJson) { $result | ConvertTo-Json -Depth 8 | Write-Output } else { Write-Host "risk_tier_approval.status=invalid_json" }
  exit 1
}

$allowedTiers = @("low", "medium", "high")
$requiredGroups = @("tool_calls", "file_write_scopes", "irreversible_actions")

if ($null -eq $policy.PSObject.Properties['tiers'] -or $null -eq $policy.tiers) {
  Add-InvalidEntry -Bag $invalidEntries -Group "policy" -Id "tiers" -Reason "tiers missing"
} else {
  foreach ($tierName in $allowedTiers) {
    $tierProp = $policy.tiers.PSObject.Properties[$tierName]
    if ($null -eq $tierProp -or $null -eq $tierProp.Value) {
      Add-InvalidEntry -Bag $invalidEntries -Group "tiers" -Id $tierName -Reason "tier missing"
      continue
    }
    $modeProp = $tierProp.Value.PSObject.Properties['approval_mode']
    if ($null -eq $modeProp -or [string]::IsNullOrWhiteSpace([string]$modeProp.Value)) {
      Add-InvalidEntry -Bag $invalidEntries -Group "tiers" -Id $tierName -Reason "approval_mode missing"
    }
  }
}

if ($null -eq $policy.PSObject.Properties['operation_groups'] -or $null -eq $policy.operation_groups) {
  Add-InvalidEntry -Bag $invalidEntries -Group "policy" -Id "operation_groups" -Reason "operation_groups missing"
} else {
  foreach ($groupName in $requiredGroups) {
    $groupProp = $policy.operation_groups.PSObject.Properties[$groupName]
    if ($null -eq $groupProp -or $null -eq $groupProp.Value) {
      Add-InvalidEntry -Bag $invalidEntries -Group "operation_groups" -Id $groupName -Reason "group missing"
      continue
    }
    if ($groupProp.Value -isnot [System.Array]) {
      Add-InvalidEntry -Bag $invalidEntries -Group "operation_groups" -Id $groupName -Reason "group must be array"
      continue
    }

    foreach ($entry in @($groupProp.Value)) {
      $entryId = "<missing-id>"
      if ($null -ne $entry -and $null -ne $entry.PSObject.Properties['id'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.id)) {
        $entryId = [string]$entry.id
      }

      if ($entryId -eq "<missing-id>") {
        Add-InvalidEntry -Bag $invalidEntries -Group $groupName -Id $entryId -Reason "id missing"
      }

      if ($null -eq $entry -or $null -eq $entry.PSObject.Properties['tier'] -or [string]::IsNullOrWhiteSpace([string]$entry.tier)) {
        Add-InvalidEntry -Bag $invalidEntries -Group $groupName -Id $entryId -Reason "tier missing"
        continue
      }

      $tier = ([string]$entry.tier).Trim().ToLowerInvariant()
      if ($allowedTiers -notcontains $tier) {
        Add-InvalidEntry -Bag $invalidEntries -Group $groupName -Id $entryId -Reason ("invalid tier: {0}" -f $tier)
        continue
      }

      if ($tier -eq "high") {
        $result.high_risk_operation_count = [int]$result.high_risk_operation_count + 1
        $approval = if ($null -ne $entry.PSObject.Properties['approval']) { $entry.approval } else { $null }
        $approvalMode = ""
        $approvalStepsCount = 0
        if ($null -ne $approval -and $null -ne $approval.PSObject.Properties['mode']) {
          $approvalMode = ([string]$approval.mode).Trim().ToLowerInvariant()
        }
        if ($null -ne $approval -and $null -ne $approval.PSObject.Properties['steps'] -and $approval.steps -is [System.Array]) {
          $approvalStepsCount = @($approval.steps | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
        }

        if ($approvalMode -ne "explicit_user_approval" -or $approvalStepsCount -le 0) {
          $result.high_risk_without_explicit_path_count = [int]$result.high_risk_without_explicit_path_count + 1
          Add-InvalidEntry -Bag $invalidEntries -Group $groupName -Id $entryId -Reason "high risk operation must define approval.mode=explicit_user_approval and non-empty approval.steps"
        }
      }
    }
  }
}

$result.invalid_entries = @($invalidEntries.ToArray())
$result.invalid_entry_count = @($result.invalid_entries).Count

if ($result.invalid_entry_count -gt 0) {
  $result.status = "invalid_policy"
} elseif ($result.high_risk_operation_count -le 0) {
  $result.status = "no_high_risk_operation"
  Add-InvalidEntry -Bag $invalidEntries -Group "policy" -Id "high-risk" -Reason "at least one high-risk operation is required"
  $result.invalid_entries = @($invalidEntries.ToArray())
  $result.invalid_entry_count = @($result.invalid_entries).Count
} else {
  $result.status = "ok"
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 10 | Write-Output
} else {
  Write-Host ("risk_tier_approval.status={0}" -f $result.status)
  Write-Host ("risk_tier_approval.high_risk_operation_count={0}" -f [int]$result.high_risk_operation_count)
  Write-Host ("risk_tier_approval.high_risk_without_explicit_path_count={0}" -f [int]$result.high_risk_without_explicit_path_count)
  Write-Host ("risk_tier_approval.invalid_entry_count={0}" -f [int]$result.invalid_entry_count)
}

if ([string]$result.status -ne "ok") { exit 1 }
exit 0
