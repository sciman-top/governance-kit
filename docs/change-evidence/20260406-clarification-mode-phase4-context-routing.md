# 20260406 clarification-mode phase4 context routing

rule_id=R2/R3/R8
risk_level=medium
owner=codex
status=done
scope=repo-governance-hub + distributed target scripts

## Goal
- Add a bridge so outer AI can provide semantic stage judgment to governance scripts.
- Keep script execution deterministic with explicit precedence and fallback.

## Changes
- Added optional `-ClarificationContextFile` parameter to:
  - `scripts/governance/run-target-autopilot.ps1`
  - `scripts/run-project-governance-cycle.ps1`
  - `scripts/governance/run-project-governance-cycle.ps1`
- Scenario resolution precedence:
  1. explicit `-ClarificationScenario` (non-auto)
  2. `clarification_context_file` JSON (`clarification_scenario`/`scenario`)
  3. script fallback (`plan` mode -> `plan`, else `bugfix`)
- Emitted `clarification_scenario_source` for observability.
- Added template:
  - `templates/clarification-context.template.json`
- Added evidence field:
  - `templates/change-evidence.md` -> `clarification_context_file`

## Verification
- `powershell -File tests/clarification-mode.tests.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/install.ps1 -Mode safe`
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1 -AsJson`
- Smoke:
  - ClassroomToolkit: `run-target-autopilot ... -ClarificationScenario auto -ClarificationContextFile .codex/clarification-context.json -DryRun`
  - skills-manager: same as above
  - repo-governance-hub: `run-project-governance-cycle ... -Mode plan -ClarificationContextFile ...`

## Result
- Outer AI can inject stage semantics.
- Scripts remain runnable without AI context (deterministic fallback).
- Distribution + verify green.

## Rollback
- Revert the three entry scripts and remove `templates/clarification-context.template.json`.
- Re-run `powershell -File scripts/install.ps1 -Mode safe` and `powershell -File scripts/doctor.ps1`.
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
