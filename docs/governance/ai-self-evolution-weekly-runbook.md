# AI Self-Evolution Weekly Runbook

## Purpose
- Execute weekly governance cycles for safe and efficient AI self-evolution.
- Keep all actions auditable and rollbackable.
- Keep execution deterministic under `direct_fix` mode unless clarification trigger conditions are hit.

## Cadence
- Weekly cycle day: Every Friday (local timezone `Asia/Shanghai`).
- Monthly review day: day `1` (aligned with `config/update-trigger-policy.json`).

## Preconditions
1. Working tree status is clean or task-isolated.
2. Required scripts exist:
- `scripts/verify-kit.ps1`
- `tests/repo-governance-hub.optimization.tests.ps1`
- `scripts/validate-config.ps1`
- `scripts/verify.ps1`
- `scripts/doctor.ps1`
3. Evidence target file prepared in `docs/change-evidence/`.

## Weekly Procedure

### Step 1: Trigger-Eval Data Health
- Run
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-skill-trigger-evals.ps1 -RepoRoot . -AsJson
```
- Check
  - `status` is not `no_data`
  - `validation_query_count > 0`
  - `validation_pass_rate` and `validation_false_trigger_rate` are populated
- Failure handling
  - If no data: block create-path promotion and regenerate runs.

### Step 1.5: Trace Grading Snapshot
- Run
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/report-growth-readiness.ps1 -RepoRoot . -AsJson
```
- Check
  - decision evidence includes `decision_score`, `hard_guard_hits`, `reason_codes`
  - recent failures are linked to taxonomy signatures

### Step 2: Recurring Review
- Run
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson
```
- Check
  - update trigger alerts
  - waiver expiry warnings
  - rollout overdue warnings
  - trigger eval freshness and pass/fail drift

### Step 3: Hard Gate Chain (Fixed Order)
- Build
```powershell
powershell -File scripts/verify-kit.ps1
```
- Test
```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```
- Contract/Invariant
```powershell
powershell -File scripts/validate-config.ps1
powershell -File scripts/verify.ps1
```
- Hotspot
```powershell
powershell -File scripts/doctor.ps1
```
- Rule
  - Any failure blocks distribution/promotion.

### Step 4: Promotion and Lifecycle Checks
- Run promotion summary and lifecycle review
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/promote-skill-candidates.ps1 -AsJson
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-skill-lifecycle-review.ps1 -RepoRoot . -AsJson
```
- Check
  - create-path gate status
  - promoted count
  - stale/retire candidates
  - adversarial threshold and regression guard status

### Step 5: Evidence and Metrics Update
- Update change evidence with required fields:
  - `issue_id`, `attempt_count`, `clarification_mode`, `decision_score`, `hard_guard_hits`, `rollback_trigger`.
- Update monthly metrics placeholders if week crosses month boundary.

### Step 6: Auto-Rollback Trigger Scan
- Trigger rollback path when any condition holds
  - `validation_pass_rate` drops below policy threshold
  - `unsafe_action_count > 0`
  - hard gate chain fails after a promotion action
- Run rollback drill when rollback path is entered
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-rollback-drill.ps1 -RepoRoot . -AsJson
```

## Incident Paths

### A. Hard gate failed
1. Stop promotion and distribution.
2. Open/append evidence with root-cause hypothesis and commands.
3. Fix root cause, rerun full gate chain.

### B. Trigger-eval no_data or stale summary
1. Register missing eval runs.
2. Rebuild summary.
3. Re-run recurring review and promotion checks.

### C. High-risk policy conflict
1. Force `observe` mode.
2. Require manual approval path.
3. Run rollback drill if regression suspected.

## Exit Checklist (Weekly)
- [ ] Trigger eval summary fresh and valid.
- [ ] All hard gates passed in fixed order.
- [ ] No unresolved blocker alerts.
- [ ] Evidence file complete and linked.
- [ ] Next-week top 3 priorities selected.
- [ ] Trace grading sample updated.
- [ ] Auto-rollback trigger scan completed.

## Monthly Add-on
- Run
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-monthly-policy-review.ps1 -RepoRoot . -AsJson
```
- Publish to `docs/governance/reviews/YYYY-MM-monthly-review.md`.
- Validate trend for quality/safety/efficiency KPIs.
