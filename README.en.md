# repo-governance-hub

[中文](README.md) | English

`repo-governance-hub` is a source-of-truth repository for multi-repository governance. It maintains global and project-level rule documents, then distributes them to target repositories through audited configuration and PowerShell automation.

This repository is not only about authoring rules. It is about keeping rules, templates, hooks, CI entrypoints, evidence, and rollback paths consistent across multiple repositories.

## What It Does

- Maintains global rule sources in `source/global/*`
- Maintains project-level rule sources in `source/project/<RepoName>/*`
- Uses `config/*.json` to manage targets, rollout policy, allowlists, and custom-file distribution
- Uses `scripts/*.ps1` to install, verify, audit, backflow, roll back, and run full governance loops

## Main Capabilities

- One-command onboarding for new repositories
- Full governance cycle orchestration: install, analyze, optimize, backflow, redistribute, verify
- Rollout control with observe/enforce phases and waiver checks
- Evidence and rollback support with backups, templates, and restore scripts
- Project-specific custom file management through `config/project-custom-files.json`
- Layered one-click distribution policy through `config/oneclick-distribution-policy.json` (`core/default/optional`)
- Agent-first remediation: scripts orchestrate gates and emit failure context; the outer AI session performs fixes
- Browser session baseline: `tools/browser-session/*` is distributed by default for stable profile + CDP attach workflows

## Quick Start

Recommended public entrypoint:

```powershell
powershell -File E:\CODE\repo-governance-hub\scripts\install-full-stack.ps1 -RepoPath E:\CODE\NewRepo -Mode safe
```

Preview only:

```powershell
powershell -File E:\CODE\repo-governance-hub\scripts\install-full-stack.ps1 -RepoPath E:\CODE\NewRepo -Mode plan
```

## Standard Workflow

### Onboard or reinstall a target repository

```powershell
powershell -File E:\CODE\repo-governance-hub\scripts\install-full-stack.ps1 -RepoPath E:\CODE\TargetRepo -Mode safe
```

Default flow:

`bootstrap-repo -> run-project-governance-cycle -> target-autopilot dry-run -> doctor`

### Run only the project-rule closed loop

```powershell
powershell -File E:\CODE\repo-governance-hub\scripts\run-project-governance-cycle.ps1 -RepoPath E:\CODE\TargetRepo -RepoName TargetRepo -Mode safe
```

### Backflow only the target repository project rules

```powershell
powershell -File E:\CODE\repo-governance-hub\scripts\backflow-project-rules.ps1 -RepoPath E:\CODE\TargetRepo -RepoName TargetRepo -Mode safe
```

## Repository Layout

- `source/global/`: global user-level rule sources
- `source/project/`: project-level rule sources and repository-specific custom files
- `source/template/project/`: default project templates for new repositories
- `config/targets.json`: `source -> target` distribution mapping
- `config/project-rule-policy.json`: allowlist, autonomy boundaries, and blocking policy
- `config/project-custom-files.json`: project custom-file manifest
- `config/oneclick-distribution-policy.json`: one-click default layer policy (`core/default/optional`)
- `config/install-size-guard.json`: one-click entry script size guard (`warn/block`)
- `scripts/`: install, verify, audit, backflow, rollback, and gate orchestration scripts
- `tests/`: regression and anti-regression tests
- `docs/change-evidence/`: change evidence
- `backups/`: runtime backup snapshots for local rollback only; they should not be pushed to the remote repository

## Gate Order

This repository uses a fixed validation order:

1. `build`: `powershell -File scripts/verify-kit.ps1`
2. `test`: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `contract/invariant`: `powershell -File scripts/validate-config.ps1` then `powershell -File scripts/verify.ps1`
4. `hotspot`: `powershell -File scripts/doctor.ps1`

If the change is documentation-only and a gate is objectively not applicable, record it as `gate_na` and include alternative verification evidence.

If a target repository needs persistent browser login state for automation, use the distributed helper:

```powershell
powershell -ExecutionPolicy Bypass -File tools/browser-session/start-browser-session.ps1 -Name github -Url https://github.com
agent-browser --cdp 9222 open https://github.com
```

## Files That Should Not Be Pushed

The following are local runtime artifacts, agent/IDE configuration, or temporary leftovers and should not live in Git history:

- `backups/`
- `.locks/`
- `.codex/`, `.claude/`, `.gemini/`
- `.vscode/`, `.idea/`
- `*.log`, `*.tmp`, `*.bak`, `tmp/`, `temp/`, `logs/`

If any of these are already tracked, adding `.gitignore` is not enough. They also need to be removed from the Git index.

## Contribution and Security

- Contribution guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Security policy: [`SECURITY.md`](SECURITY.md)
- Changelog: [`CHANGELOG.md`](CHANGELOG.md)
- PR template: [`.github/pull_request_template.md`](.github/pull_request_template.md)

## License

This project is licensed under the [`MIT`](LICENSE) License.


