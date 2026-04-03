# One-Click Target-State Acceptance Matrix

## Scope
- This matrix defines "target-state" acceptance levels for one-click install/governance.
- It separates "converges to endstate" from "immediate endstate after first run."

## Acceptance Levels

### L1: Convergent Baseline (Minimum)
- One-click flow completes core installation and governance bootstrap.
- Hard gate order is preserved: `build -> test -> contract/invariant -> hotspot`.
- On failure, scripts emit `[FAILURE_CONTEXT_JSON]`; outer AI session performs remediation and retries.
- No script-level nested model CLI auto-fix is used.

### L2: Stable Automation (Expected)
- L1 satisfied.
- Target repo can run local governance cycle repeatedly without policy regression.
- Required templates/hooks/git config are present or explicitly tracked as N/A with expiry.
- For non-allow-list repos, optimization/backflow policy is enforced by configuration.

### L3: Best-Practice Endstate (Preferred)
- L2 satisfied.
- Repo-specific project rules are evidence-backed and aligned with real repo gates.
- Continuous cycle reaches green doctor plus zero hard-gate failures after remediation loop.
- Over-design controls are preserved (no unsupported abstractions, no speculative optimizations).

## Repo Classes and Required Outcome

### Class A: Allow-list Existing Repo
- Expected level: L3.
- Behavior: run full cycle with optimize + backflow + re-distribution verification.

### Class B: Non-Allow-List New Repo
- Expected level: L2 (default) and L3 if explicitly promoted.
- Behavior (default): template rules + governance scripts installed, no backflow.
- Optional behavior: allow local optimize without backflow when policy enables it.

### Class C: High-Debt Existing Repo
- Expected level: L1 immediately, then converge to L2/L3 via remediation iterations.
- Behavior: install succeeds, failures are handed off to outer AI remediation until green chain.

## Exit Criteria (Release Gate)
- `verify-kit` pass
- `tests/governance-kit.optimization.tests.ps1` pass
- `validate-config` pass
- `verify` pass
- `doctor` pass
- Failure context contract validation pass (when failure path is exercised)

## Autonomous Execution Boundaries
- `max_autonomous_iterations`: cap autonomous cycles in one run.
- `max_repeated_failure_per_step`: stop after repeated failures on same step.
- `stop_on_irreversible_risk`: immediate stop on irreversible-risk boundaries (default for `contract.*` failures).
