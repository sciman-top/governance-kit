# Rule Layering Pilot Closeout Checklist

## Scope
- pilot_repo: `repo-governance-hub`
- observe_window: `2026-04-13` to `2026-04-27`
- baseline_evidence: `docs/change-evidence/20260413-rule-layering-week0-baseline.md`
- mid_window_evidence: `docs/change-evidence/20260413-phase4-mid-window-checkpoint.md`

## Closeout Preconditions (all required)
1. Hard gate chain passes in fixed order:
   - `powershell -File scripts/verify-kit.ps1`
   - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
   - `powershell -File scripts/validate-config.ps1`
   - `powershell -File scripts/verify.ps1`
   - `powershell -File scripts/doctor.ps1`
2. `run-recurring-review` summary is healthy:
   - `doctor_health=GREEN`
   - `token_balance_status=OK`
   - `cross_repo_compatibility_status=ok`
   - `auto_rollback_triggered=false`
3. Observe window data is complete:
   - at least one baseline + one mid-window + one closeout snapshot.

## Decision Metrics
- `first_pass_rate` (higher is better)
- `rework_after_clarification_rate` (lower is better)
- `token_per_effective_conclusion` (lower is better)
- `average_response_token` (stable/downward preferred)

## Decision Matrix
1. Promote to wider rollout
- Conditions:
  - `first_pass_rate` not lower than W0 baseline by > 5 percentage points.
  - `rework_after_clarification_rate` not higher than W0 baseline by > 5 percentage points.
  - `token_per_effective_conclusion` shows non-worsening trend.
  - No blocker alerts in recurring review.

2. Continue observe (one more week)
- Conditions:
  - Quality metrics are stable but token trend is `insufficient_history` or ambiguous.
  - No hard-gate or safety regressions.

3. Rollback pilot changes
- Conditions:
  - Any hard gate fails repeatedly after root-cause fix attempt.
  - Recurring review shows persistent `token_balance=VIOLATION` or `auto_rollback_triggered=true`.
  - Quality regression exceeds threshold.

## Closeout Commands (2026-04-27)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-token-efficiency-trend.ps1 -RepoRoot . -AsJson
powershell -File scripts/verify-kit.ps1
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/validate-config.ps1
powershell -File scripts/verify.ps1
powershell -File scripts/doctor.ps1
```

## Closeout Evidence Template
- file: `docs/change-evidence/YYYYMMDD-rule-layering-phase4-closeout.md`
- minimum fields:
  - `window_start/window_end`
  - `baseline_vs_closeout` (3 core metrics)
  - `decision` (`promote | continue_observe | rollback`)
  - `reason_codes`
  - `rollback_entry` (`scripts/restore.ps1 + backups/<timestamp>/`)

## Notes
- If `token_efficiency_trend.status=insufficient_history` on 2026-04-27 and quality/safety are stable, prefer `continue_observe` over forced promote.
