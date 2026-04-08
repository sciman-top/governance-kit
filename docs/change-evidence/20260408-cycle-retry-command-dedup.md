# 2026-04-08 Cycle Retry Command Dedup

## Goal
- Reduce duplicated retry-command string construction in `run-project-governance-cycle.ps1` without changing runtime behavior.

## Scope
- File: `scripts/run-project-governance-cycle.ps1`
- Type: low-risk refactor (readability/maintainability)

## Changes
- Added helper functions:
  - `Get-NormalizedRepoPathForCmd`
  - `New-CycleRetryCommand`
  - `New-ChildScriptRetryCommand`
- Replaced repeated inline retry command strings in:
  - `install`
  - `analyze`
  - `custom-policy-check`
  - `optimize-project-rules`
  - `backflow-project-rules`
  - `re-distribute-and-verify`

## Why
- Centralizes command-string formatting rules.
- Lowers drift risk when command shape changes later.
- Keeps failure context retry suggestions consistent.

## Verification
- `powershell -File scripts/verify-kit.ps1` -> pass
- `powershell -File tests/governance-kit.optimization.tests.ps1` -> pass
- `powershell -File scripts/validate-config.ps1` -> pass
- `powershell -File scripts/verify.ps1` -> `ok=73 fail=0`
- `powershell -File scripts/doctor.ps1` -> `HEALTH=GREEN`

## Risk
- Low. Refactor only; no gate order or policy logic changed.

## Rollback
- Revert `scripts/run-project-governance-cycle.ps1` to previous revision if needed.
