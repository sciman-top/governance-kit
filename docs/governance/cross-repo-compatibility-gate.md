# Cross-Repo Compatibility Gate

## Goal
- Require explicit compatibility pass signal before redistribution.
- Ensure all managed repos meet minimum governance compatibility baseline.

## Policy
- `.governance/cross-repo-compatibility-policy.json`

## Check Script
- `scripts/governance/check-cross-repo-compatibility.ps1`

## Validation Dimensions
- Required file presence per repo (`required_relative_files`)
- Release profile validation (`scripts/verify-release-profile.ps1`) when enabled

## Output Signal
- `.governance/cross-repo-compatibility-signal.json`
- Key fields:
  - `status`
  - `repo_failure_count`
  - `missing_required_file_count`

## Gate Integration
- Hard gate (`contract/invariant`): `scripts/verify.ps1`
- Weekly recurring snapshot: `scripts/governance/run-recurring-review.ps1`

