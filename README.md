# repo-governance-hub

> Governance distribution and verification hub for Codex-managed repositories.

This repository is the source of truth for the governance rules, templates, scripts, and install flows that keep the managed repos aligned.

## What it does
- Publishes shared governance rules from `source/`
- Distributes repo-specific and shared templates to managed targets
- Verifies invariants, cross-repo compatibility, and growth-pack readiness
- Generates the GitHub-facing docs that help target repos look trustworthy and easy to try

## Key entry points
- `scripts/install.ps1`
- `scripts/verify.ps1`
- `scripts/doctor.ps1`
- `scripts/governance/apply-growth-pack.ps1`
- `scripts/governance/verify-growth-pack.ps1`
- `scripts/governance/report-growth-readiness.ps1`

## Quick Start
1. Inspect the current state:
   ```powershell
   powershell -File scripts/verify.ps1
   powershell -File scripts/doctor.ps1
   ```
2. Reinstall governance files into the managed repos:
   ```powershell
   powershell -File scripts/install.ps1 -Mode safe
   ```
3. Refresh the GitHub-facing docs in the target repos:
   ```powershell
   powershell -File scripts/governance/apply-growth-pack.ps1 -Mode safe -Overwrite
   ```

## Where to edit
- Shared rules: `source/global/`
- Repo-specific rules: `source/project/<RepoName>/`
- Common custom assets: `source/project/_common/custom/`
- Policies and rollout wiring: `config/`
- Execution and verification: `scripts/`

## Notes
- Target repos should keep their own root `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, and issue/PR templates synchronized with the growth pack.
- This repo intentionally keeps the growth-pack templates minimal so they can be copied safely and verified quickly.
- If a change affects user-facing docs or repo onboarding, update the growth pack first, then reinstall into targets, then re-run the gates.

## Why this project
- Pain: Inconsistent repo setup and repeated manual checks.
- Result: Predictable setup and faster quality verification.
- Differentiator: Uses governance templates plus scripted validation.

## Who it is for
- Repository maintainers
- Standardizing project governance and docs
- Use this when manual governance work starts to drift

## Quick Start (5 Minutes)
### Prerequisites
- PowerShell 7+
- Git working copy

### Run
```bash
powershell -File scripts/doctor.ps1
```

### Expected Output
- HEALTH=GREEN in doctor output
- Verification gates report PASS

## What you can try first
- Verify current state
- Run install and re-check
- Track evidence and rollback path

## FAQ
- Q: Validation fails
- A: Fix the first failed gate from verify output and rerun doctor

## Limitations
- Requires governance scripts to be present
- Policy files must stay in sync with targets

## Next steps
- docs/
- RELEASE_TEMPLATE.md
- issues/
