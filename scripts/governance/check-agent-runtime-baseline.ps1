param(
  [string]$RepoRoot = ".",
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$commonPath = Join-Path $repoPath "scripts\lib\common.ps1"
if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
  throw "Missing common helper: $commonPath"
}
. $commonPath

$policyPath = Resolve-AgentRuntimePolicyPath -KitRoot $repoPath
$policyRel = [System.IO.Path]::GetRelativePath($repoPath, $policyPath).Replace('\', '/')
$policyName = Split-Path -Leaf $policyPath
$isAgentRuntimePolicy = $policyName.Equals("agent-runtime-policy.json", [System.StringComparison]::OrdinalIgnoreCase)

$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
  param(
    [string]$Id,
    [string]$Status,
    [string]$Message
  )
  $checks.Add([pscustomobject]@{
    id = $Id
    status = $Status
    message = $Message
  }) | Out-Null
}

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  Add-Check -Id "runtime_policy_exists" -Status "WARN" -Message "runtime policy file not found"
} else {
  $policy = $null
  try {
    $policy = Read-JsonFile -Path $policyPath -DisplayName $policyPath
    Add-Check -Id "runtime_policy_json" -Status "PASS" -Message "runtime policy JSON parsed"
  } catch {
    Add-Check -Id "runtime_policy_json" -Status "WARN" -Message "runtime policy JSON parse failed"
    $policy = $null
  }

  if ($null -ne $policy) {
    if ($isAgentRuntimePolicy) {
      $requiredSections = @(
        "prompt_registry",
        "tool_contracts",
        "context_management",
        "memory_policy",
        "agent_evals",
        "agent_observability",
        "cost_controls",
        "observe_to_enforce"
      )
      foreach ($sectionName in $requiredSections) {
        $hasSection = ($null -ne $policy.PSObject.Properties[$sectionName] -and $null -ne $policy.$sectionName)
        if ($hasSection) {
          Add-Check -Id ("section_" + $sectionName) -Status "PASS" -Message ("agent runtime section present: " + $sectionName)
        } else {
          Add-Check -Id ("section_" + $sectionName) -Status "WARN" -Message ("agent runtime section missing: " + $sectionName)
        }
      }

      $modeValue = $null
      if ($null -ne $policy.PSObject.Properties["mode"]) {
        $modeValue = [string]$policy.mode
      }
      if ([string]::IsNullOrWhiteSpace($modeValue)) {
        Add-Check -Id "agent_runtime_mode" -Status "WARN" -Message "agent runtime mode missing"
      } else {
        $normalized = $modeValue.ToLowerInvariant()
        if (@("observe", "enforce", "advisory") -contains $normalized) {
          Add-Check -Id "agent_runtime_mode" -Status "PASS" -Message ("agent runtime mode=" + $normalized)
        } else {
          Add-Check -Id "agent_runtime_mode" -Status "WARN" -Message "agent runtime mode invalid"
        }
      }

      $requiredTrajectoryFields = @(
        "run_id",
        "issue_id",
        "problem_statement_ref",
        "trajectory_ref",
        "checkpoint_ref",
        "replay_ref",
        "rollback_ref",
        "human_interrupt_count"
      )
      $trajectoryFields = @()
      if ($null -ne $policy.PSObject.Properties["agent_observability"] -and $null -ne $policy.agent_observability) {
        if ($null -ne $policy.agent_observability.PSObject.Properties["trajectory_fields"] -and $policy.agent_observability.trajectory_fields -is [System.Array]) {
          $trajectoryFields = @($policy.agent_observability.trajectory_fields | ForEach-Object { [string]$_ })
        }
      }
      foreach ($fieldName in $requiredTrajectoryFields) {
        if ($trajectoryFields -contains $fieldName) {
          Add-Check -Id ("trajectory_field_" + $fieldName) -Status "PASS" -Message ("trajectory field present: " + $fieldName)
        } else {
          Add-Check -Id ("trajectory_field_" + $fieldName) -Status "WARN" -Message ("trajectory field missing: " + $fieldName)
        }
      }

      $requiredToolFields = @(
        "tool_name",
        "risk_class",
        "approval_policy",
        "timeout_ms",
        "retry_policy",
        "trace_attrs",
        "sandbox_boundary",
        "side_effect_class"
      )
      $toolEntries = @()
      if ($null -ne $policy.PSObject.Properties["tool_contracts"] -and $null -ne $policy.tool_contracts) {
        if ($null -ne $policy.tool_contracts.PSObject.Properties["entries"] -and $policy.tool_contracts.entries -is [System.Array]) {
          $toolEntries = @($policy.tool_contracts.entries)
        }
      }
      if ($toolEntries.Count -eq 0) {
        Add-Check -Id "tool_contract_entries" -Status "WARN" -Message "tool contract entries missing"
      } else {
        $toolIndex = 0
        foreach ($toolEntry in $toolEntries) {
          foreach ($fieldName in $requiredToolFields) {
            if ($null -ne $toolEntry.PSObject.Properties[$fieldName] -and -not [string]::IsNullOrWhiteSpace([string]$toolEntry.$fieldName)) {
              Add-Check -Id ("tool_entry_" + $toolIndex + "_" + $fieldName) -Status "PASS" -Message ("tool field present: " + $fieldName)
            } else {
              Add-Check -Id ("tool_entry_" + $toolIndex + "_" + $fieldName) -Status "WARN" -Message ("tool field missing: " + $fieldName)
            }
          }
          $toolIndex++
        }
      }

      $forbiddenMemoryClasses = @()
      if ($null -ne $policy.PSObject.Properties["memory_policy"] -and $null -ne $policy.memory_policy) {
        if ($null -ne $policy.memory_policy.PSObject.Properties["forbidden_memory_classes"] -and $policy.memory_policy.forbidden_memory_classes -is [System.Array]) {
          $forbiddenMemoryClasses = @($policy.memory_policy.forbidden_memory_classes | ForEach-Object { ([string]$_).ToLowerInvariant() })
        }
      }
      if ($forbiddenMemoryClasses -contains "secrets") {
        Add-Check -Id "memory_forbidden_secrets" -Status "PASS" -Message "memory forbidden class includes secrets"
      } else {
        Add-Check -Id "memory_forbidden_secrets" -Status "WARN" -Message "memory forbidden class missing secrets"
      }
      if ($forbiddenMemoryClasses -contains "raw_credentials") {
        Add-Check -Id "memory_forbidden_raw_credentials" -Status "PASS" -Message "memory forbidden class includes raw_credentials"
      } else {
        Add-Check -Id "memory_forbidden_raw_credentials" -Status "WARN" -Message "memory forbidden class missing raw_credentials"
      }

      $hasMemoryPolicy = ($null -ne $policy.PSObject.Properties["memory_policy"] -and $null -ne $policy.memory_policy)
      $durableEnabled = $false
      if ($hasMemoryPolicy -and $null -ne $policy.memory_policy.PSObject.Properties["durable_memory"] -and $null -ne $policy.memory_policy.durable_memory) {
        if ($null -ne $policy.memory_policy.durable_memory.PSObject.Properties["enabled"]) {
          $durableEnabled = [bool]$policy.memory_policy.durable_memory.enabled
        }
      }
      $hasAuditRequirements = ($hasMemoryPolicy -and $null -ne $policy.memory_policy.PSObject.Properties["audit_requirements"] -and $null -ne $policy.memory_policy.audit_requirements)
      if ($durableEnabled -and -not $hasAuditRequirements) {
        Add-Check -Id "memory_durable_requires_audit" -Status "WARN" -Message "durable memory enabled without audit requirements"
      } else {
        Add-Check -Id "memory_durable_requires_audit" -Status "PASS" -Message "durable memory audit requirement satisfied"
      }

      $evalRequiredFields = @(
        "required_suites",
        "minimum_eval_freshness_days",
        "promotion_blocks_on_missing_eval",
        "trace_grading_enabled"
      )
      $hasAgentEvals = ($null -ne $policy.PSObject.Properties["agent_evals"] -and $null -ne $policy.agent_evals)
      foreach ($fieldName in $evalRequiredFields) {
        if ($hasAgentEvals -and $null -ne $policy.agent_evals.PSObject.Properties[$fieldName]) {
          Add-Check -Id ("agent_evals_" + $fieldName) -Status "PASS" -Message ("agent eval field present: " + $fieldName)
        } else {
          Add-Check -Id ("agent_evals_" + $fieldName) -Status "WARN" -Message ("agent eval field missing: " + $fieldName)
        }
      }
    } else {
      Add-Check -Id "agent_runtime_sections" -Status "PASS" -Message "legacy codex runtime policy active, agent runtime sections not required"
    }
  }
}

$warningCount = @($checks | Where-Object { $_.status -eq "WARN" }).Count
$status = if ($warningCount -gt 0) { "WARN" } else { "PASS" }
$modeCheck = @($checks | Where-Object { $_.id -eq "agent_runtime_mode" } | Select-Object -First 1)
$isEnforceMode = ($null -ne $modeCheck -and $modeCheck.status -eq "PASS" -and $modeCheck.message -match "mode=enforce")
if ($isEnforceMode -and $warningCount -gt 0) {
  $status = "FAIL"
}

$result = [pscustomobject]@{
  schema_version = "1.0"
  status = $status
  policy_path = $policyRel
  policy_name = $policyName
  warning_count = $warningCount
  check_count = $checks.Count
  checks = @($checks)
}

if ($AsJson) {
  $result | ConvertTo-Json -Depth 8 | Write-Output
  exit 0
}

Write-Host ("agent_runtime_baseline.status=" + $result.status)
Write-Host ("agent_runtime_baseline.policy_path=" + $result.policy_path)
Write-Host ("agent_runtime_baseline.warning_count=" + $result.warning_count)
exit 0
