# Skill Lifecycle Health Policy

## Goal
- Add measurable guardrails for `promote/optimize/retire` lifecycle automation.
- Block unsafe backlog growth or quality regression before redistribution.

## Inputs
- Policy: `.governance/skill-lifecycle-health-policy.json`
- Registry: `.governance/skill-candidates/promotion-registry.json`
- Lifecycle plan output: `scripts/governance/run-skill-lifecycle-review.ps1 -Mode plan -AsJson`

## Check Script
- `scripts/governance/check-skill-lifecycle-health.ps1`

## Core Signals
- `retire_candidate_count`
- `retired_avg_latency_days`
- `quality_impact_delta` (`active_avg_health_score - retired_avg_health_score`)

## Fail Conditions
- `retire_candidate_count > max_retire_candidate_count` (when `block_on_retire_backlog=true`)
- `retired_avg_latency_days > max_retired_avg_latency_days` (when `block_on_latency_violation=true`)
- `quality_impact_delta < min_quality_impact_delta` (when `block_on_quality_regression=true`)

## Gate Integration
- Hard gate (`contract/invariant`): `scripts/verify.ps1`
- Weekly recurring snapshot: `scripts/governance/run-recurring-review.ps1`

