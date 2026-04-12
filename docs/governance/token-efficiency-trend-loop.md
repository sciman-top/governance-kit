# Token Efficiency Trend Loop

## Goal
- Continuously track `token_per_effective_conclusion`.
- Detect regression trend and block when policy requires.

## Policy
- `.governance/token-efficiency-trend-policy.json`

## Check Script
- `scripts/governance/check-token-efficiency-trend.ps1`

## Behavior
- Read latest metric from `docs/governance/metrics-auto.md`.
- Append/refresh daily sample in `.governance/token-efficiency-history.jsonl`.
- Evaluate trend over last `min_points_for_trend` samples.

## Status Semantics
- `missing_metric`: metric absent, non-blocking by default.
- `insufficient_history`: not enough points for trend decision.
- `improving|stable|regressing`: trend decision after enough points.

## Gate Integration
- Hard gate (`contract/invariant`): `scripts/verify.ps1`
- Weekly recurring snapshot: `scripts/governance/run-recurring-review.ps1`

