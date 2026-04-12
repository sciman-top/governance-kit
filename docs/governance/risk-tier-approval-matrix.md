# Risk-Tier Approval Matrix (P1-01)

## Goal
- Define executable approval boundaries for governance automation.
- Ensure every high-risk operation has explicit user approval path.

## Tier Definitions
- `low`: safe read-only or reversible local updates; can auto-execute with evidence.
- `medium`: policy/gate impacting changes; require pre-publish confirmation.
- `high`: irreversible or broad side-effect actions; require explicit user approval.

## Matrix
| Group | Operation ID | Tier | Approval Path |
|---|---|---|---|
| tool_calls | read_only_diagnostics | low | auto execute + evidence |
| tool_calls | network_write_or_publish | medium | pre-publish confirmation |
| tool_calls | prod_or_external_state_change | high | explicit user approval |
| file_write_scopes | docs_and_local_templates | low | auto execute + evidence |
| file_write_scopes | policy_or_gate_script | medium | pre-publish confirmation |
| file_write_scopes | cross_repo_distribution_bulk_write | high | explicit user approval |
| irreversible_actions | recursive_delete_or_force_history_ops | high | explicit user approval |

## Explicit Approval Requirements (High)
- Evidence must include `issue_id`, `risk_tier`, `hard_guard_hits`, `rollback_trigger`, `approval_reference`.
- Approval steps must be present in policy for each high-risk operation.
- Gate blocks when any high-risk operation lacks explicit approval mode/steps.

## Enforcement
- Policy source: `.governance/risk-tier-approval-policy.json`.
- Contract gate script: `scripts/governance/check-risk-tier-approval.ps1`.
- Recurring review snapshot fields:
  - `risk_tier_approval_status`
  - `high_risk_without_explicit_path_count`

## Rollback
- Revert policy/script/doc changes and rerun hard gates:
  - `powershell -File scripts/verify-kit.ps1`
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -File scripts/validate-config.ps1`
  - `powershell -File scripts/verify.ps1`
  - `powershell -File scripts/doctor.ps1`
