# Engineering Practice System Plan (2026 Q2)

## Scope
- Repo: `E:/CODE/repo-governance-hub`
- Related target repos: `ClassroomToolkit`, `skills-manager`, `repo-governance-hub`
- Planning date: `2026-04-13`

## Goal / Non-goal / Acceptance / Assumptions
- Goal
  - Build a practical, high-efficiency, auditable engineering-practice system that can be distributed to target repos.
  - Keep existing hard-gate semantics stable while filling high-value baseline gaps.
- Non-goal
  - Do not replace current governance stack wholesale.
  - Do not enforce all new practices in one step.
- Acceptance
  - Core practices are codified with clear `observe -> enforce` progression.
  - Target repos can run the same baseline with minimal repo-specific overrides.
  - Hard gate order remains: `build -> test -> contract/invariant -> hotspot`.
- Assumptions
  - Existing install/distribution pipeline (`scripts/install.ps1`) remains source of truth for rollout.
  - Existing evidence model in `docs/change-evidence/` continues as the audit backbone.

## Current-State Snapshot (2026-04-13)
- Already strong
  - Practice stack policy exists and includes `sdd/tdd/contract/harness/policy_as_code/ssdf/slsa/sbom/scorecard`.
  - Hard gates, waivers, recurring review, subagent trigger policy, and cross-repo compatibility checks are in place.
  - GitHub workflows already include `quality-gates`, `scorecard`, `sbom`, `slsa`.
- Main gaps to close
  - Missing `CodeQL` workflow in repo baseline.
  - Missing `dependency-review` workflow in repo baseline.
  - Missing `CODEOWNERS` baseline.
  - `SLSA` still at observe placeholder note; not yet verified provenance enforcement.

## Practice Taxonomy (Unified)
- Requirement to test
  - `SDD`, `ATDD/BDD`, `TDD`.
- Quality and compatibility
  - Contract testing, harness engineering, deterministic replay.
- Security and supply chain
  - `SSDF`, `SLSA`, `SBOM`, `Scorecard`, Code scanning, dependency review, secret push protection.
- Change governance
  - Policy as code, rulesets, CODEOWNERS, hooks + CI gates, risk-tier approvals.
- Runtime reliability
  - Observability, SLO/error-budget, progressive delivery.

## Priority Decisions
1. Keep
- Keep current four-stage hard gate model and evidence chain unchanged.
- Keep distributed governance model (`source -> config/targets -> install`).

2. Add (high ROI first)
- Add `codeql.yml` to common custom baseline and target mapping.
- Add `dependency-review.yml` to common custom baseline and target mapping.
- Add `.github/CODEOWNERS` template to baseline.
- Add governance check script to ensure these files exist where required.

3. Delay (observe first)
- SLSA provenance strict enforcement.
- Full policy-bot style advanced approval logic beyond existing risk-tier model.

4. Reduce or avoid
- Avoid duplicating overlapping checks that increase gate latency without new signal.
- Avoid creating parallel skill families for already-converged problems.

## 3-Phase Execution Plan

### Phase 0: Baseline Freeze and Gap Matrix (`2026-04-13` ~ `2026-04-20`)
- Tasks
  - Create a machine-readable matrix: `practice -> script/workflow/policy -> mode(observe/enforce) -> owner`.
  - Mark mandatory core set (`Core`) vs optional advanced set (`Extended`).
  - Define rollout entry criteria for each newly added control.
- Deliverables
  - `docs/governance/execution-practice-gap-matrix-2026Q2.md`
  - `config/practice-stack-policy.json` updated with per-practice rollout metadata.
- Exit criteria
  - No ambiguity for ownership and enforcement level across three repos.

### Phase 1: High-Value Security Baseline Fill (`2026-04-21` ~ `2026-05-11`)
- Tasks
  - Add `source/project/_common/custom/.github/workflows/codeql.yml`.
  - Add `source/project/_common/custom/.github/workflows/dependency-review.yml`.
  - Add `source/project/_common/custom/.github/CODEOWNERS`.
  - Update:
    - `config/project-custom-files.json`
    - `config/targets.json`
    - verification scripts (`scripts/verify-kit.ps1` and related governance checks)
  - Distribute via `scripts/install.ps1 -Mode safe`.
- Deliverables
  - Three new baseline artifacts distributed to all target repos.
  - Evidence record with before/after repo matrix.
- Exit criteria
  - All target repos contain new files.
  - Hard gates pass in fixed order.

### Phase 2: Enforce Tuning and Noise Reduction (`2026-05-12` ~ `2026-06-15`)
- Tasks
  - Promote selected controls from `observe` to `enforce` based on data:
    - first candidate: dependency review block policy.
  - Define gate noise budget:
    - false positive rate threshold
    - max added gate latency threshold.
  - Demote low-value high-noise checks to advisory when needed.
- Deliverables
  - updated enforcement policy and recurring review report fields.
  - trend evidence for pass rate / latency / rollback.
- Exit criteria
  - Quality improves without material throughput regression.

## Task Backlog (Actionable)

### P0 (must-do)
1. Add `CodeQL` baseline workflow and target mapping.
2. Add `dependency-review` baseline workflow and target mapping.
3. Add `CODEOWNERS` baseline template and target mapping.
4. Add verification for presence/consistency of these files in governance gates.

### P1 (high value)
1. Add repository-ruleset policy mapping doc and script check (existence + core fields).
2. Add SLO/error-budget reporting fields into recurring review output.
3. Add per-practice performance cost tracking (`gate latency delta`).

### P2 (optimize)
1. SLSA provenance from placeholder to verifiable attestation pipeline.
2. Integrate org-level settings-as-code workflow (pilot with one repo first).

## Verification Plan (fixed order)
1. `powershell -File scripts/verify-kit.ps1`
2. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `powershell -File scripts/validate-config.ps1`
4. `powershell -File scripts/verify.ps1`
5. `powershell -File scripts/doctor.ps1`

## Risks and Rollback
- Risk
  - Added security workflows may increase CI time or introduce initial false positives.
- Mitigation
  - Start in observe where needed, enforce after trend stability.
- Rollback
  - Revert newly added baseline files and config mappings.
  - Re-run full hard gate chain and record rollback evidence.

## Evidence Fields (for this plan rollout)
- `practice_topic`
- `phase`
- `repo_scope`
- `mode_before`
- `mode_after`
- `gate_latency_delta_ms`
- `false_positive_delta`
- `rollback_ready`

