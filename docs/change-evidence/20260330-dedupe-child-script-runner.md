# 2026-03-30 Dedupe child script runner

## Basis
- User request: evaluate optimization opportunities and reduce over-optimization/over-design.
- Repo policy: keep fixed gates order `build -> test -> contract/invariant -> hotspot`.

## Destination
- Source of truth path: `E:/CODE/governance-kit/source/project/governance-kit/*` (rule docs unchanged in this task).
- Code landing path: `E:/CODE/governance-kit/scripts/*` + tests.

## Changes
- Added shared helpers in `scripts/lib/common.ps1`:
  - `Get-CurrentPowerShellPath`
  - `Invoke-ChildScript`
  - `Invoke-ChildScriptCapture`
- Removed duplicated child-script execution logic from:
  - `scripts/bootstrap-repo.ps1`
  - `scripts/run-project-governance-cycle.ps1`
  - `scripts/optimize-project-rules.ps1`
  - `scripts/prune-orphan-custom-sources.ps1`
- Updated `scripts/doctor.ps1` to use shared helper, with compatibility fallback when `lib/common.ps1` is absent in isolated temp tests.
- Added regression test:
  - `tests/governance-kit.optimization.tests.ps1`
  - case: `common Invoke-ChildScriptCapture returns script output and enforces exit code`

## Commands and Evidence
- `codex --version` => `codex-cli 0.117.0`
- `codex --help` => success
- `codex status` => non-interactive failure (`stdin is not a terminal`)

### platform_na
- type: `platform_na`
- reason: `codex status` cannot run in current non-interactive session.
- alternative_verification: used `codex --version` and `codex --help`, and manually referenced active project rule file `E:/CODE/governance-kit/AGENTS.md`.
- evidence_link: this file
- expires_at: `2026-04-30`

### gate execution (fixed order)
1. build: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1` => pass
2. test: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/governance-kit.optimization.tests.ps1` => pass (all cases)
3. contract/invariant:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1` => pass
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1` => pass
4. hotspot: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1` => `HEALTH=GREEN`

### gate_na
- type: `gate_na`
- reason: quick gate script is not present in this repository policy baseline.
- alternative_verification: executed full hard gates in required order.
- evidence_link: this file
- expires_at: `2026-04-30`

## Rollback
- Revert edited files to pre-change snapshots via VCS if available, or restore from latest backup process.
- Repo rollback entry: `powershell -File scripts/restore.ps1` with corresponding backup timestamp.

## Incremental optimization (round 2)
- Unified UTF8 no-BOM file read/write helpers into `scripts/lib/common.ps1`.
- Removed duplicated UTF8 helpers from:
  - `scripts/bump-rule-version.ps1`
  - `scripts/optimize-project-rules.ps1`
- `scripts/audit-governance-readiness.ps1` now reuses `common.ps1` helper functions (`Get-CurrentPowerShellPath`, `Invoke-ChildScriptCapture`, `Read-JsonArray`).
- Updated test fixtures to include `scripts/lib/common.ps1` in isolated temp workspaces for:
  - bump-rule-version tests
  - audit-governance-readiness test

### Round 2 verification
1. build: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1` => pass
2. test: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/governance-kit.optimization.tests.ps1` => pass
3. contract/invariant:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1` => pass
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1` => pass
4. hotspot: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1` => `HEALTH=GREEN`
