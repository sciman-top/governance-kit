# repo-governance-hub

> Governance distribution and verification hub for Codex-managed repositories.

This repository is the source of truth for shared governance rules, repo-specific rule sets, templates, scripts, and installation flows.

## What It Does
- Publishes shared rules from `source/global/`
- Publishes repo-specific rules from `source/project/<RepoName>/`
- Distributes templates, hooks, and CI entrypoints to managed targets
- Verifies invariants, compatibility, rollout state, and growth-pack readiness
- Generates the GitHub-facing docs used by target repositories

## Main Entry Points
- `scripts/install.ps1`
- `scripts/verify.ps1`
- `scripts/doctor.ps1`
- `scripts/governance/apply-growth-pack.ps1`
- `scripts/governance/verify-growth-pack.ps1`
- `scripts/governance/report-growth-readiness.ps1`

## Quick Start
```powershell
powershell -File scripts/verify.ps1
powershell -File scripts/doctor.ps1
powershell -File scripts/install.ps1 -Mode safe
```

If you are refreshing the GitHub-facing docs in target repositories:

```powershell
powershell -File scripts/governance/apply-growth-pack.ps1 -Mode safe -Overwrite
```

## Repository Layout
- `source/global/`: global rule sources
- `source/project/<RepoName>/`: project-specific rule sources and custom files
- `source/template/project/`: starter template for new repos
- `config/`: targets, rollout policy, allowlists, and custom-file wiring
- `scripts/`: install, verify, audit, backflow, rollback, and gate orchestration
- `tests/`: regression and anti-regression coverage
- `docs/change-evidence/`: change evidence
- `backups/`: local rollback snapshots

## Gate Order
1. `build`: `powershell -File scripts/verify-kit.ps1`
2. `test`: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `contract/invariant`: `powershell -File scripts/validate-config.ps1` then `powershell -File scripts/verify.ps1`
4. `hotspot`: `powershell -File scripts/doctor.ps1`

If a gate is objectively not applicable for a documentation-only change, record it as `gate_na` and keep the fixed order intact.

## Where to Edit
- Shared rules: `source/global/`
- Repo-specific rules: `source/project/<RepoName>/`
- Common custom assets: `source/project/_common/custom/`
- Policies and rollout wiring: `config/`
- Execution and verification: `scripts/`

## Notes
- Keep target repo `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, and issue/PR templates synchronized with the growth pack.
- Update the growth pack first when user-facing docs or onboarding steps change.
- Re-run verification after reinstalling into targets.

## Related Docs
- [English README](./README.en.md)
- [Governance readiness](./docs/governance-readiness.md)
- [Rule index](./docs/governance/rule-index.md)
- [Contribution guide](./CONTRIBUTING.md)
- [Security policy](./SECURITY.md)

## License
MIT
