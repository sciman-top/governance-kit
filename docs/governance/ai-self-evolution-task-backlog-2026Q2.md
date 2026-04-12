# AI Self-Evolution Task Backlog (2026 Q2)

## Priority Legend
- `P0`: must complete before scaling automation.
- `P1`: safety and reliability expansion.
- `P2`: lifecycle and scale optimization.

## Execution Rule
- Before each task: record task understanding snapshot (`goal/non-goal/acceptance/assumptions`).
- After each task: update evidence in `docs/change-evidence/YYYYMMDD-topic.md`.
- Gate order is immutable: `build -> test -> contract/invariant -> hotspot`.

## P0 Tasks

### P0-01 Build Trigger-Eval Seed Dataset
- Owner: Governance Maintainer
- Inputs
  - `.governance/skill-candidates/trigger-eval-runs.sample.jsonl`
  - `scripts/governance/register-skill-trigger-eval-run.ps1`
- Outputs
  - `.governance/skill-candidates/trigger-eval-runs.jsonl`
- Steps
  1. Seed positive and near-miss negative queries from recent evidence.
  2. Register runs using script with `split=validation` at minimum.
  3. Verify line count >= 50.
- Verification commands
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-skill-trigger-evals.ps1 -RepoRoot . -AsJson`
- DoD
  - `status != no_data`
  - `validation_query_count > 0`
  - `validation_false_trigger_rate` present

### P0-02 Enforce Create-Path Eval Readiness
- Owner: Governance Maintainer
- Inputs
  - `.governance/skill-promotion-policy.json`
  - `scripts/governance/promote-skill-candidates.ps1`
- Outputs
  - Create path blocks if eval summary missing/invalid.
- Steps
  1. Confirm policy flags remain strict (`require_trigger_eval_for_create=true`, `block_create_when_eval_missing=true`).
  2. Add explicit failure message mapping for `eval_summary_missing/no_data/no_validation_split`.
  3. Add regression test cases for create-path blocking.
- Verification commands
  - `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
- DoD
  - Create promotion fails deterministically on missing or empty eval summary.

### P0-03 Upgrade Evidence Template for Evolution Decisions
- Owner: Governance Maintainer
- Inputs
  - `docs/change-evidence/template.md`
- Outputs
  - Template fields include evolution decision observability.
- Required new fields
  - `decision_score`
  - `hard_guard_hits`
  - `spawn_parallel_subagents`
  - `rollback_trigger`
  - `risk_tier`
- Verification commands
  - Manual checklist against at least 3 new evidence files.
- DoD
  - Field completeness >= 95% in spot-check sample.

### P0-04 Weekly Review Automation Additions
- Owner: Governance Maintainer
- Inputs
  - `scripts/governance/run-recurring-review.ps1`
  - `config/update-trigger-policy.json`
- Outputs
  - Weekly report includes trigger-eval freshness and pass trends.
- Verification commands
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson`
- DoD
  - Weekly output contains `trigger_eval_status`, `validation_pass_rate`, `validation_false_trigger_rate`.

## P1 Tasks

### P1-01 Risk-Tier Approval Matrix
- Status: Completed (2026-04-12)
- Owner: Governance + Security
- Inputs
  - approval/risk policies in `.governance/`
- Outputs
  - Documented matrix for tool calls, file write scopes, and irreversible actions.
- DoD
  - High-risk operations require explicit approval path.

### P1-02 Shadow-to-Enforce Rollout Policy
- Status: Completed (2026-04-12)
- Owner: Governance Maintainer
- Outputs
  - `observe -> enforce` promotion criteria with thresholds and rollback conditions.
- DoD
  - At least 2 weeks observe data before enforce switch.

### P1-03 Trace Replay and Failure Taxonomy
- Status: Completed (2026-04-12)
- Owner: Governance Maintainer
- Outputs
  - Replayable failure cases linked by `issue_signature`.
- DoD
  - Top 5 recurring failures can be replayed and compared.

### P1-04 Auto Rollback Drill
- Status: Completed (2026-04-12)
- Owner: Governance + Ops
- Outputs
  - Drill record validating `scripts/restore.ps1` for policy regressions.
- DoD
  - Drill completed with evidence and time-to-recovery metric.

## P2 Tasks

### P2-01 Skill Family De-dup and Health Scoring
- Status: Completed (2026-04-12)
- Owner: Governance Maintainer
- Outputs
  - family-level scorecard for promoted skills.
- DoD
  - Duplicate promotion rate decreases month over month.

### P2-02 Lifecycle Automation (Promote/Optimize/Retire)
- Status: Completed (2026-04-12)
- Owner: Governance Maintainer
- Outputs
  - automatic retirement for stale low-value skills with safeguards.
- DoD
  - retirement latency and quality impact tracked.

### P2-03 Cross-Repo Compatibility Gate
- Status: Completed (2026-04-12)
- Owner: Governance Maintainer
- Outputs
  - redistribution requires compatibility pass signal.
- DoD
  - cross-repo regression failures reduce by target threshold.

### P2-04 Cost and Token Efficiency Loop
- Status: Completed (2026-04-12, Observe Window Active)
- Owner: Governance Maintainer
- Outputs
  - measurable reduction plan for `token_per_effective_conclusion`.
- DoD
  - 4-week downward trend with stable quality.

## Weekly Scheduling Template
- Monday: baseline + backlog re-prioritization.
- Tuesday-Thursday: implement top P0/P1 tasks.
- Friday: full gate run + evidence packaging + risk review.
- End of week: publish metrics and adjust next sprint.

## Blocking Rules
1. Any hard gate failure blocks promotion and redistribution.
2. Any unresolved `review_required` tracked-file signal blocks commit/push.
3. Missing rollback path blocks enforce rollout.
4. Missing evidence chain blocks task closure.
