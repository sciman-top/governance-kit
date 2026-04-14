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
    } else {
      Add-Check -Id "agent_runtime_sections" -Status "PASS" -Message "legacy codex runtime policy active, agent runtime sections not required"
    }
  }
}

$warningCount = @($checks | Where-Object { $_.status -eq "WARN" }).Count
$status = if ($warningCount -gt 0) { "WARN" } else { "PASS" }

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
