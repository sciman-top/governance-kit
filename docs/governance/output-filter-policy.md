# Output Filter Policy (Phase 3 Pilot)

## Goal
- Reduce noisy command output tokens without losing failure signals or rollback evidence.

## Scope (Pilot)
- Commands: build/test/install/verify/doctor related high-volume logs.
- Repos: start with `repo-governance-hub` only, then evaluate for `skills-manager` and `ClassroomToolkit`.

## Guardrails
- Never filter away:
  - non-zero exit code
  - `[FAIL]` / `[VIOLATION]` / `[MISS]` / `HEALTH=RED`
  - gate summary lines and rollback hints
- Always keep raw log file locally for audit and replay.

## Strategy
1. Success-path compression:
   - Keep summary + key counters.
   - Collapse repeated `[OK]` lines when count is high.
2. Failure-path full fidelity:
   - Keep full failing step block and nearest context.
3. Progressive rollout:
   - Week 1: advisory-only filtering (show both filtered summary + raw log path).
   - Week 2: enforce filtered display if no quality regression.

## White/Black List
- Allow filtering:
  - repeated `[OK] source -> target` distribution lines
  - repeated pass confirmations from unchanged gates
- Disallow filtering:
  - token-balance, anti-bloat, tracked-files, release-profile violations
  - check/update trigger alerts

## Tooling Notes
- Prefer lightweight pipeline filters (`tokf`/`RTK`) for stream compaction.
- If unavailable, use PowerShell fallback summarizer in wrapper scripts.
- Hook mode must remain opt-in and reversible.

## Acceptance
- One-pass rate not lower than baseline.
- Rework rate not higher than baseline.
- No missed failure in sampled replay set.

## Rollback
- Disable filter wrapper and revert to raw output mode immediately.
- Preserve evidence link to raw logs and affected command IDs.
