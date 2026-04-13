# Verification Entrypoints (Repo Level)

## Scope
- This file hosts verbose verification entry lists that were previously in `C.8`.
- Main rule files should keep only a short index pointer to this file.

## CI Entrypoints
- GitHub Actions: `.github/workflows/quality-gates.yml`
- Azure Pipelines: `azure-pipelines.yml`
- GitLab CI: `.gitlab-ci.yml`

## Local Repo Entrypoints
- Hooks:
  - `Test-Path .git/hooks/pre-commit`
  - `Test-Path .git/hooks/pre-push`
- Git config:
  - `git config --get commit.template`
  - `git config --get governance.root`

## Two-Stage Gate Entrypoint
- Purpose: faster feedback without changing hard-gate semantics.
- Stage 1 (fast precheck): skip heavy target verification.
- Stage 2 (full gate): run complete `doctor` chain.
- Entrypoint:
  - `powershell -File scripts/run-two-stage-gate.ps1`
  - JSON output: `powershell -File scripts/run-two-stage-gate.ps1 -AsJson`

## Fast Check Entrypoint
- Purpose: default local fast path with risk-based auto escalation.
- Default behavior:
  - always run `doctor -SkipVerifyTargets` as fast precheck;
  - auto run full `doctor` only when pending files hit high-risk paths (`config/`, `scripts/`, `tests/`, `source/`, `hooks/`, `ci/`, `templates/`, `.governance/`, root `AGENTS/CLAUDE/GEMINI`).
- Entrypoint:
  - `powershell -File scripts/governance/fast-check.ps1`
  - JSON output: `powershell -File scripts/governance/fast-check.ps1 -AsJson`
- Controls:
  - force full gate: `powershell -File scripts/governance/fast-check.ps1 -RunFullGate`
  - disable auto escalation: `powershell -File scripts/governance/fast-check.ps1 -DisableAutoEscalation`

## Release Profile Coverage Entrypoints
- `powershell -File scripts/verify-release-profile.ps1 -RepoPath <repo> [-AsJson]`
- `powershell -File scripts/check-release-profile-coverage.ps1 [-AsJson]`
- standalone dependency policy:
  - `config/standalone-release-policy.json`
  - enforce rule: `release_enabled=true` + external absolute repo path hit => `FAIL`
  - advisory rule: `release_enabled=false` + external absolute repo path hit => warning only

## Install/Sync Semantics
- `install/sync` default sequence:
  1. `scripts/refresh-targets.ps1` (based on `repositories.json + project-custom-files.json`)
  2. distribution install

## Milestone Auto-Commit Guardrails
- Allowed checkpoints (policy-controlled): `after_backflow`, `after_redistribute_verify`, `cycle_complete`
- Auto-commit shape: `git add -A + Chinese message`
- Mandatory guard: isolate unrelated changes before `git add -A`.

## Template Presence Checks
- `Test-Path docs/change-evidence/template.md`
- `Test-Path docs/governance/waiver-template.md`
- `Test-Path docs/governance/metrics-template.md`
