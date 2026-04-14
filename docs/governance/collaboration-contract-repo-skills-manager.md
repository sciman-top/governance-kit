# Collaboration Contract: repo-governance-hub <-> skills-manager

## Purpose
- Make the cross-repo collaboration explicit and enforceable.
- Prevent governance changes from bypassing the skills-manager promotion/distribution chain.

## Roles
- `repo-governance-hub`
  - Governance source of truth and distribution orchestrator.
  - Defines policies, gate semantics, rollout, evidence, and rollback standards.
- `skills-manager`
  - Distribution host for override skills used by multi-CLI environments.
  - Receives synced overrides and continues candidate -> eval -> promote workflow.

## Hard Collaboration Rules
1. New reusable skill definitions must originate from:
   - `source/project/repo-governance-hub/custom/overrides/<skill-name>/SKILL.md`
2. Repository-root `.agents/skills/*` in this repo is not a canonical creation path.
3. Skill creation must satisfy lifecycle/promotion gates:
   - user ack policy
   - trigger-eval summary policy
   - family uniqueness
   - minimum cross-repo evidence thresholds
4. After collaboration-related changes, verification must include:
   - `build -> test -> contract/invariant -> hotspot`
   - source backflow consistency (`source/project/repo-governance-hub/*` vs repo root)
5. Collaboration dependency is not equal to standalone release dependency:
   - If `release_enabled=true`, external absolute repo path dependencies must be validated by standalone-release policy.
   - See `docs/governance/standalone-release-dependency-contract.md`.

## Change Routing
- Governance semantics changes:
  - primary in `repo-governance-hub` project/global rules and governance scripts.
- Skill lifecycle and override skill distribution:
  - primary in `repo-governance-hub` source override path, then synced to `skills-manager/overrides` for governed distribution.

## UTF-8 Guard Ownership (Windows PowerShell)
- Canonical preventive skill:
  - `source/project/repo-governance-hub/custom/overrides/custom-windows-encoding-guard`
- Synced distribution target:
  - `${WORKSPACE_ROOT}/skills-manager/overrides/custom-windows-encoding-guard`
- Governance rule:
  - `pwsh-encoding-mojibake-loop-*` signatures are treated as known family.
  - Promotion policy must block duplicate `create` and converge to canonical guard.
  - No parallel standalone UTF-8 guard skills are allowed for the same family.

## Evidence Requirements
- Must record in `docs/change-evidence/*`:
  - why collaboration boundary is involved
  - which side is source of truth for each artifact
  - gate outputs and rollback path
