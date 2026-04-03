# Contributing to governance-kit

中文说明见 [README.md](README.md)。English contributors can use this file as the primary collaboration guide.

## Scope

This repository accepts contributions related to governance rules, distribution automation, verification, evidence, rollback, and repository-onboarding workflows.

Out-of-scope changes:

- product features unrelated to governance
- local-only IDE or agent configuration
- runtime backups, logs, caches, or temporary debugging files

## Before You Change Anything

1. Read the repository-level [AGENTS.md](AGENTS.md).
2. Confirm the intended source of truth before editing:
   - global rules: `source/global/*`
   - project rules: `source/project/<RepoName>/*`
   - config: `config/*.json`
   - automation: `scripts/*.ps1`
   - tests: `tests/*`
3. Keep changes small, verifiable, and reversible.

## Required Validation Order

Run gates in this exact order:

```powershell
powershell -File scripts/verify-kit.ps1
powershell -File tests/governance-kit.optimization.tests.ps1
powershell -File scripts/validate-config.ps1
powershell -File scripts/verify.ps1
powershell -File scripts/doctor.ps1
```

If a gate is objectively not applicable for a documentation-only change, document it as `gate_na` and include alternative verification evidence.

## Pull Requests

Each pull request should include:

- purpose of the change
- risk level
- validation commands and key outputs
- rollback notes if config structure or behavior changes

Use the repository PR template at `.github/pull_request_template.md`.

## Git Hygiene

Do not commit local runtime artifacts or environment-specific files, including:

- `backups/`
- `.locks/`
- `.codex/`, `.claude/`, `.gemini/`
- `.vscode/`, `.idea/`
- logs, caches, and temporary files

If you accidentally tracked them before, remove them from the Git index as part of the fix.

## Security

Do not commit secrets, tokens, credentials, or private operational data. Report vulnerabilities through the private path documented in [SECURITY.md](SECURITY.md).
