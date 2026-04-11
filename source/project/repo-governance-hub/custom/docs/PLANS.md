# PLANS.md

## Objective
Land the Codex-first runtime asset baseline for governed repositories without expanding scope beyond thin-core governance.

## Scope
- In scope:
  - Default distributable assets: docs/PLANS.md, repo-scope .agents skills, local plugin marketplace seed, internal plugin skeleton.
  - Profile metadata registry for Codex runtime artifacts.
  - Mapping refresh, install distribution, and full gate verification.
- Out of scope:
  - Default distribution of .codex/* artifacts.
  - Public plugin publishing and third-party runtime ingestion.

## Current phase
Bootstrap complete: codex-native reusable assets + minimal plugin packaging seed.

## Steps
1. Add reusable assets under source/project/_common/custom.
2. Register assets in config/project-custom-files.json defaults.
3. Refresh targets and distribute to configured repositories.
4. Validate via build -> test -> contract/invariant -> hotspot.

## Validation
- build: powershell -File scripts/verify-kit.ps1
- test: powershell -File tests/repo-governance-hub.optimization.tests.ps1
- contract: powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- hotspot: powershell -File scripts/doctor.ps1

## Risks
- New repo-level .agents/plugins artifacts may require downstream repo hygiene alignment.
- Plugin marketplace path changes must stay synchronized with project-custom-files and targets.

## Rollback
- Restore using scripts/restore.ps1 and backups/<timestamp>/.
- Revert source/project/_common/custom asset additions and config default-file entries.

