# Control Retirement Candidates (2026 Q2)

## Purpose
- Keep governance controls adjustable.
- Identify low-signal, stale, or non-observable controls before they become permanent friction.

## Candidate List

### runtime.agent_runtime_profile
- control_id: `runtime.agent_runtime_profile`
- plane: `runtime_policy`
- reason: `not_observable_candidate`
- current_mode: `observe`
- decision_due_date: `2026-05-15`
- target_action: add direct observability; if still weak after two cycles, downgrade or retire.
- rollback_path: `git restore config/agent-runtime-policy.json scripts/set-agent-runtime-policy.ps1`

### distribution.rollout_phase
- control_id: `distribution.rollout_phase`
- plane: `distribution`
- reason: `too_loose_candidate`
- current_mode: `observe`
- decision_due_date: `2026-05-15`
- target_action: either complete metadata coverage and split scopes, or retire current coarse control.
- rollback_path: `git restore config/rule-rollout.json`

## Decision Rule
- if a candidate stays active past `decision_due_date`, it becomes `overdue` and is surfaced by update triggers.
- every retirement or downgrade decision must include:
  - evidence link
  - replacement coverage (if any)
  - rollback entry
