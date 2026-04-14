# Target Rollout Status Matrix (2026 Q2)

## Scope
- source repo: `E:/CODE/repo-governance-hub`
- targets:
  - `E:/CODE/ClassroomToolkit`
  - `E:/CODE/skills-manager`
  - `E:/CODE/repo-governance-hub`

## Purpose
- Provide per-target rollout state for each `distributable + progressive` control.
- Make Phase4 rollout decisions measurable and reviewable.

## Matrix (Current Baseline)

| control_id | repo | phase | observe_started_at | planned_enforce_date |
| --- | --- | --- | --- | --- |
| `runtime.clarification_upgrade` | `E:/CODE/ClassroomToolkit` | `observe` | `2026-04-01` | `2026-05-01` |
| `runtime.clarification_upgrade` | `E:/CODE/skills-manager` | `observe` | `2026-04-01` | `2026-05-01` |
| `runtime.clarification_upgrade` | `E:/CODE/repo-governance-hub` | `observe` | `2026-04-01` | `2026-05-01` |
| `runtime.proactive_suggestion_balance` | `E:/CODE/ClassroomToolkit` | `advisory` | `N/A` | `N/A` |
| `runtime.proactive_suggestion_balance` | `E:/CODE/skills-manager` | `advisory` | `N/A` | `N/A` |
| `runtime.proactive_suggestion_balance` | `E:/CODE/repo-governance-hub` | `advisory` | `N/A` | `N/A` |
| `runtime.agent_runtime_profile` | `E:/CODE/repo-governance-hub` | `observe` | `2026-04-10` | `2026-05-10` |
| `gate.fast_check_escalation` | `E:/CODE/ClassroomToolkit` | `advisory` | `N/A` | `N/A` |
| `gate.fast_check_escalation` | `E:/CODE/skills-manager` | `advisory` | `N/A` | `N/A` |
| `gate.fast_check_escalation` | `E:/CODE/repo-governance-hub` | `advisory` | `N/A` | `N/A` |
| `metrics.token_efficiency_trend` | `E:/CODE/ClassroomToolkit` | `observe` | `2026-04-01` | `2026-05-15` |
| `metrics.token_efficiency_trend` | `E:/CODE/skills-manager` | `observe` | `2026-04-01` | `2026-05-15` |
| `metrics.token_efficiency_trend` | `E:/CODE/repo-governance-hub` | `observe` | `2026-04-01` | `2026-05-15` |

## Validation Source
- machine-readable source: `config/target-control-rollout-matrix.json`
- checker: `scripts/governance/check-target-rollout-matrix.ps1`
