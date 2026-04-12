# Shadow-to-Enforce Rollout Policy (P1-02)

## Goal
- Enforce `observe -> enforce` transition with measurable criteria.
- Block enforce switch if observe data window is insufficient.

## Criteria
- Minimum observe window: `14` days.
- `observe_started_at` is required.
- `planned_enforce_date` is required while phase is `observe`.
- Violation blocks promotion readiness.

## Policy and Gate
- Policy: `.governance/rollout-promotion-policy.json`
- Gate script: `scripts/governance/check-rollout-promotion-readiness.ps1`
- Verify integration: `scripts/verify.ps1`
- Weekly snapshot fields:
  - `rollout_promotion_status`
  - `rollout_observe_window_violation_count`

## Rollback Conditions
- `observe_window_violation`
- `post_enforce_regression_detected`
- `waiver_expired_unrecovered`

## Example
- `observe_started_at=2026-04-01`
- `planned_enforce_date=2026-04-15`
- Observe window = `14` days, meets minimum.
