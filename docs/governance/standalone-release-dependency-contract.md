# Standalone Release Dependency Contract

## Purpose
- Clarify the boundary between cross-repo collaboration and standalone release portability.
- Prevent `repo-governance-hub` standalone release from hard depending on local absolute paths like `E:/CODE/skills-manager`.

## Decision
- `source/project/repo-governance-hub/custom/overrides` is the canonical authoring source for custom reusable skills.
- In this repo, any `E:/CODE/skills-manager` reference is treated as collaboration context, not standalone release runtime requirement.
- If a repo is published in standalone mode (`release_enabled=true`), unresolved external absolute repo dependencies must fail release-profile verification.

## Enforcement
- Policy file: `config/standalone-release-policy.json`
- Gate script: `scripts/verify-release-profile.ps1`
  - `release_enabled=true`: external absolute dependency hit => `FAIL`
  - `release_enabled=false`: external absolute dependency hit => advisory `warning` only
- Coverage entry: `scripts/check-release-profile-coverage.ps1` includes `warning_count`.

## Practical Guidance
- Keep skill implementation source in:
  - `source/project/repo-governance-hub/custom/overrides/<skill-name>/SKILL.md`
- When preparing standalone release:
  - keep collaboration rules as optional docs/contracts
  - avoid making release/preflight scripts require external local path repos
  - if collaboration dependency is unavoidable, keep release disabled or add explicit migration step before enabling release

## Evidence Fields
- `standalone_dependency_hits`
- `warnings`
- `errors` (contains violation reason when blocked)
