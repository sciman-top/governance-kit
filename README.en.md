# repo-governance-hub

[中文](README.md) | English

`repo-governance-hub` is the source of truth for multi-repository governance. It keeps global and project-level rules, then distributes them to managed repositories through audited configuration and PowerShell automation.

## What It Does
- Maintains global rule sources in `source/global/`
- Maintains project-level rule sources in `source/project/<RepoName>/`
- Uses `config/*.json` to control targets, rollout policy, allowlists, and custom-file distribution
- Uses `scripts/*.ps1` to install, verify, audit, backflow, roll back, and run governance loops

## Core Capabilities
- One-command onboarding for new repositories
- Full governance cycle orchestration: install, analyze, optimize, backflow, redistribute, verify
- Rollout control with observe/enforce phases and waiver checks
- Evidence and rollback support with backups, templates, and restore scripts
- Browser-session baseline for stable profile and CDP workflows
- Agent-first remediation: scripts orchestrate gates and emit failure context; the outer AI session performs fixes

## Quick Start
```powershell
powershell -File .\scripts\install-full-stack.ps1 -RepoPath .\NewRepo -Mode plan
powershell -File .\scripts\install-full-stack.ps1 -RepoPath .\NewRepo -Mode safe
```

## Standard Workflow
### Onboard or reinstall a target repository
```powershell
powershell -File .\scripts\install-full-stack.ps1 -RepoPath .\TargetRepo -Mode safe
```

Default flow:

`bootstrap-repo -> run-project-governance-cycle -> target-autopilot dry-run -> doctor`

### Run only the project-rule closed loop
```powershell
powershell -File .\scripts\run-project-governance-cycle.ps1 -RepoPath .\TargetRepo -RepoName TargetRepo -Mode safe
```

### Backflow only the target repository project rules
```powershell
powershell -File .\scripts\backflow-project-rules.ps1 -RepoPath .\TargetRepo -RepoName TargetRepo -Mode safe
```

## Repository Layout
- `source/global/`: global user-level rule sources
- `source/project/`: project-level rule sources and repository-specific custom files
- `source/template/project/`: default project templates for new repositories
- `config/targets.json`: source-to-target distribution mapping
- `config/project-rule-policy.json`: allowlist, autonomy boundaries, and blocking policy
- `config/project-custom-files.json`: project custom-file manifest
- `scripts/`: install, verify, audit, backflow, rollback, and gate orchestration scripts
- `tests/`: regression and anti-regression tests
- `docs/change-evidence/`: change evidence
- `backups/`: local rollback snapshots

## Gate Order
1. `build`: `powershell -File scripts/verify-kit.ps1`
2. `test`: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `contract/invariant`: `powershell -File scripts/validate-config.ps1` then `powershell -File scripts/verify.ps1`
4. `hotspot`: `powershell -File scripts/doctor.ps1`

If a change is documentation-only and a gate is objectively not applicable, record it as `gate_na` and include alternative verification evidence.

## Files That Should Not Be Pushed
- `backups/`
- `.locks/`
- `.codex/`, `.claude/`, `.gemini/`
- `.vscode/`, `.idea/`
- `*.log`, `*.tmp`, `*.bak`, `tmp/`, `temp/`, `logs/`

If any of these are already tracked, `.gitignore` is not enough. They must also be removed from the Git index.

## Contribution and Security
- Contribution guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Security policy: [`SECURITY.md`](SECURITY.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- PR template: [`.github/pull_request_template.md`](.github/pull_request_template.md)

## License
This project is licensed under the [`MIT`](LICENSE) License.
