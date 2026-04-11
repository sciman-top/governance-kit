# Rule Release Process

## Goal
- Standardize governance rule releases with verifiable gates, JSON contract compatibility, and rollback readiness.

## Steps
1. Prepare changes on `source/`, `config/`, `scripts/`, `tests/`.
2. Validate local gates:
   - `powershell -File scripts/verify-kit.ps1`
   - `powershell -File scripts/validate-config.ps1`
   - `powershell -File scripts/verify.ps1`
   - `powershell -File scripts/doctor.ps1`
   - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. Validate JSON contracts:
   - `powershell -File scripts/verify-json-contract.ps1`
4. Validate real repositories (smoke):
   - `powershell -File scripts/run-real-repo-regression.ps1 -Mode smoke`
5. Fill release record using:
   - `docs/governance/rule-release-template.md`
6. Run one-click distribution (single external entry):
   - `powershell -File scripts/install-full-stack.ps1 -RepoPath <target-repo> -Mode safe`
7. Re-run doctor after distribution:
   - `powershell -File scripts/doctor.ps1`
8. Attach evidence in `docs/change-evidence/YYYYMMDD-*.md`.

## Versioning Policy
- Rule document version (`AGENTS/CLAUDE/GEMINI`) and JSON schema version are independently versioned.
- JSON contract major bump is required for breaking field changes.

## Rollback
- Use backup snapshots in `backups/`.
- Use:
  - `powershell -File scripts/restore.ps1 -BackupName <snapshot>`
- Record rollback evidence in `docs/change-evidence/`.

