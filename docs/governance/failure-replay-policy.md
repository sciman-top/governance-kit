# Trace Replay and Failure Taxonomy (P1-03)

## Goal
- Keep replayable failure cases linked by `issue_signature`.
- Ensure top recurring signatures are continuously covered by replay cases.

## Assets
- Policy: `.governance/failure-replay/policy.json`
- Replay catalog: `.governance/failure-replay/replay-cases.json`
- Readiness gate: `scripts/governance/check-failure-replay-readiness.ps1`

## Readiness Rule
- Compute top signatures from observed events + registry hit counts.
- Target top size: `5`.
- `status=ok` only when top signatures all have enabled replay case with:
  - `replay.command`
  - `replay.expected_pattern`

## Weekly Outputs
- `failure_replay_status`
- `failure_replay_top5_coverage_rate`
- `failure_replay_missing_top5_count`

## Rollback
- Revert policy/catalog/script changes and rerun hard gates.
