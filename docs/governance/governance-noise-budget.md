# Governance Noise Budget (2026 Q2 Baseline)

## Scope
- repo: `E:/CODE/repo-governance-hub`
- applies_to: source-side governance checks and recurring review triggers
- baseline_date: `2026-04-14`

## Budget Axes
- `false_positive_rate`: fraction of alerts that do not require actual control change.
- `gate_latency_delta_ms`: added latency compared with stable baseline for the same gate scope.
- `token_overhead_ratio`: governance-only output tokens / effective conclusion tokens.

## Per-Control Budget (Phase 1 Baseline)

| control_id | class | mode | false_positive_rate_max | gate_latency_delta_ms_max | token_overhead_ratio_max | action_on_breach |
| --- | --- | --- | --- | --- | --- | --- |
| `gate.gate_noise_budget` | progressive | observe | `0.05` | `5000` | `0.35` | keep non-blocking, raise weekly alert |
| `gate.update_trigger_review` | progressive | observe | `0.08` | `2500` | `0.20` | tune trigger thresholds first |
| `runtime.proactive_suggestion_balance` | progressive | advisory | `0.10` | `500` | `0.15` | reduce suggestion frequency |
| `runtime.clarification_upgrade` | progressive | observe | `0.08` | `500` | `0.10` | tighten scenario gating |
| `rule.index_indirection` | advisory | advisory | `0.15` | `0` | `0.05` | reduce duplicated rule guidance |

## Review Cadence
- weekly (`run-recurring-review`):
  - evaluate top noisy controls and compare to prior week.
  - keep breaches in observe/advisory unless hard safety issue exists.
- monthly (`run-monthly-policy-review`):
  - decide `promote / downgrade / retire` for controls with two-cycle stable breach.

## Rollout Constraints
- do not promote any progressive control to `enforce` unless:
  - two consecutive review cycles meet budget.
  - target repo compatibility remains green or explicitly waived.
- if budget breach persists for two cycles:
  - downgrade from `enforce -> advisory` or mark retirement candidate.
