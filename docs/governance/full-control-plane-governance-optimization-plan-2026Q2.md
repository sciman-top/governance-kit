# Full Control-Plane Governance Optimization Plan (2026 Q2)

## Scope
- Repo: `E:/CODE/repo-governance-hub`
- Target repos: `repo-governance-hub`, `skills-manager`, `ClassroomToolkit`
- Planning date: `2026-04-14`
- Coverage: source-of-truth governance, distribution pipeline, target-repo rollout, and cross-repo feedback loop

## Goal / Non-goal / Acceptance / Assumptions
- Goal
  - Build a lighter, stronger, and continuously adjustable governance system across this repo and distributed target repos.
  - Reduce low-value friction before tightening high-value controls.
  - Make every new control measurable, rollbackable, and eligible for `observe -> advisory -> enforce`.
- Non-goal
  - Do not replace the current four-stage hard gate model.
  - Do not promote all advisory controls to blocking controls in one cycle.
  - Do not distribute experimental controls to all target repos before local validation.
- Acceptance
  - Control surfaces are explicitly categorized as `hard`, `progressive`, or `advisory`.
  - Existing hard-gate order remains unchanged: `build -> test -> contract/invariant -> hotspot`.
  - New or adjusted controls include owner, rollout mode, metrics, and rollback path.
  - Target repos receive only validated controls with explicit rollout criteria.
- Assumptions
  - `scripts/install.ps1 -Mode safe` remains the source-of-truth distribution path.
  - `docs/change-evidence/` remains the audit backbone for rollout, rollback, and learning evidence.

## Core Strategy
1. Reduce friction first
- Remove duplicated checks, repetitive rules, noisy prompts, and low-signal blocking behavior before adding force.

2. Strengthen only high-value controls
- Tighten only controls tied to compatibility, safety, rollback, auditability, and distribution correctness.

3. Promote gradually
- Default progression for new controls is `observe -> advisory -> enforce`, not direct blocking.

4. Separate source governance from rollout governance
- This repo defines semantics and execution machinery.
- Target repos receive bounded controls with independent rollout state.

5. Optimize from evidence, not intuition
- Every optimization must be traceable to metrics, recurring review output, failure replay, or change evidence.

## Control-Plane Model

### 1. Rule Plane
- Artifacts
  - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`
  - `source/project/*`
  - `docs/governance/rule-index.md`
- Optimization target
  - Keep semantic boundaries clear.
  - Move volatile detail out of top-level rule files into docs or policy files.
  - Reduce duplicate instruction text across global, repo, and distributed variants.
- Main risks
  - Rule bloat
  - semantic overlap
  - stale guidance after platform evolution

### 2. Runtime Policy Plane
- Artifacts
  - `config/clarification-policy.json`
  - `config/agent-runtime-policy.json`
  - `.governance/proactive-suggestion-policy.json`
  - `config/subagent-trigger-policy.json`
- Optimization target
  - Move agent behavior shaping from prose-only rules into machine-checkable policy.
  - Tune when the agent should ask, suggest, parallelize, compact, or stay silent.
  - Keep token and interaction cost bounded.
- Main risks
  - over-intervention
  - under-clarification
  - parallel work without safe boundaries

### 3. Gate Plane
- Artifacts
  - `scripts/verify-kit.ps1`
  - `tests/repo-governance-hub.optimization.tests.ps1`
  - `scripts/validate-config.ps1`
  - `scripts/verify.ps1`
  - `scripts/doctor.ps1`
  - adjunct governance checks under `scripts/governance/*`
- Optimization target
  - Keep hard-gate order fixed.
  - Shift low-value checks to observe/advisory when they add latency without signal.
  - Tighten checks that protect distribution correctness, config compatibility, and release safety.
- Main risks
  - false positives
  - latency inflation
  - hidden coupling between side checks and hard gates

### 4. Evidence and Metrics Plane
- Artifacts
  - `docs/change-evidence/*`
  - `docs/governance/metrics-template.md`
  - `docs/governance/metrics-auto.md`
  - `.governance/token-efficiency-history.jsonl`
- Optimization target
  - Require enough evidence to replay, grade, compare, and roll back decisions.
  - Track not only correctness but also friction cost.
  - Make underperforming controls visible for downgrade or retirement.
- Main risks
  - evidence exists but is not comparable
  - missing fields for trend analysis
  - governance cost remains invisible

### 5. Distribution Plane
- Artifacts
  - `config/project-custom-files.json`
  - `config/targets.json`
  - `config/project-rule-policy.json`
  - `config/rule-rollout.json`
  - `scripts/install.ps1`
- Optimization target
  - Prevent local experiments from being redistributed prematurely.
  - Define which controls are repo-local, common-custom, or target-specific.
  - Make target rollout state explicit and reversible.
- Main risks
  - over-distribution
  - drift between source and target
  - accidental policy hardening across all repos

### 6. Review and Evolution Plane
- Artifacts
  - `config/update-trigger-policy.json`
  - `scripts/governance/check-update-triggers.ps1`
  - `scripts/governance/run-recurring-review.ps1`
  - `scripts/governance/run-monthly-policy-review.ps1`
- Optimization target
  - Convert monthly and weekly review from passive reporting into policy tuning input.
  - Add trigger coverage for governance bloat, noise, and stale rollout states.
  - Institutionalize retirement and downgrade paths for low-value controls.
- Main risks
  - controls only accumulate
  - no expiry discipline
  - no forced review of friction trends

## Control Classification Standard
Every control should be assigned one of these classes:

| class | meaning | default action |
| --- | --- | --- |
| `hard` | protects safety, compatibility, rollback, or source-of-truth integrity | block on failure |
| `progressive` | high-value but still maturing or context-dependent | start `observe`, then `advisory`, then `enforce` |
| `advisory` | useful signal or optimization hint, but not worth blocking flow by default | report only |

## Phase Plan

### Phase 0: Inventory and Classification
- Objective
  - Build a single inventory of all active controls across the six control planes.
- Tasks
  1. Create a control registry with fields:
     - `control_id`
     - `plane`
     - `artifact`
     - `owner`
     - `repo_scope`
     - `class`
     - `mode`
     - `signal_value`
     - `cost`
     - `rollback_path`
  2. Mark each control as:
     - `too_strict`
     - `too_loose`
     - `duplicated`
     - `stale`
     - `not_observable`
     - `balanced`
  3. Separate local-only controls from distributable controls.
- Deliverables
  - `docs/governance/control-plane-inventory-2026Q2.md`
  - `config/governance-control-registry.json`
- Exit criteria
  - No active control lacks owner, class, mode, and rollback path.

### Phase 1: Noise Reduction and De-dup
- Objective
  - Lower governance friction before any meaningful tightening.
- Tasks
  1. Audit repeated instructions across `AGENTS/CLAUDE/GEMINI/source`.
  2. Audit adjunct checks that duplicate hard-gate signal.
  3. Reduce repetitive proactive suggestions and clarify-upgrade noise.
  4. Add retirement candidates for stale or low-signal controls.
  5. Define a per-control noise budget:
     - false positive rate
     - added latency
     - token overhead
- Deliverables
  - `docs/governance/governance-noise-budget.md`
  - updated trigger policy for noise-budget review
  - first retirement candidate list
- Exit criteria
  - Top repeated low-value signals reduced.
  - No hard-gate semantic regression.

### Phase 2: Runtime and Evidence Hardening
- Objective
  - Strengthen behavior shaping and observability without over-blocking.
- Tasks
  1. Promote more agent behavior into policy-backed runtime controls.
  2. Standardize evidence fields for:
     - friction cost
     - rollout decision
     - downgrade reason
     - retirement reason
  3. Add replay-ready evidence links for control changes.
  4. Add weekly review summaries for:
     - top noisy controls
     - most bypassed advisories
     - stale progressive controls
- Deliverables
  - updated evidence template and metrics fields
  - recurring review output enriched with control-plane summaries
- Exit criteria
  - Runtime policies are measurable.
  - Evidence supports upgrade and downgrade decisions.

### Phase 3: High-Value Control Tightening
- Objective
  - Tighten only controls with clear safety or correctness value.
- Candidate areas
  - distribution correctness
  - source/target drift detection
  - release profile integrity
  - compatibility checks
  - risk-tier approval coverage
- Tasks
  1. Define explicit thresholds for `progressive -> enforce`.
  2. Require observe-window evidence before enforcement.
  3. Add rollback trigger for every newly enforced control.
  4. Keep non-critical cost and style controls non-blocking.
- Deliverables
  - updated rollout criteria in policy and docs
  - enforcement decision evidence pack
- Exit criteria
  - Newly enforced controls show stable value over at least two review cycles.

### Phase 4: Cross-Repo Rollout and Feedback Loop
- Objective
  - Distribute validated controls safely and use target feedback to refine source.
- Tasks
  1. Add per-target rollout state for each distributable progressive control.
  2. Gate redistribution on compatibility and local readiness.
  3. Collect target-repo feedback:
     - pass/fail trend
     - friction delta
     - rollback events
     - local override frequency
  4. Feed that data back into source-side control classification.
- Deliverables
  - target rollout status matrix
  - cross-repo feedback report
  - downgrade or promotion decisions with evidence
- Exit criteria
  - No control is globally distributed without local evidence.
  - Target-repo regressions remain within threshold.

## Priority Backlog

### P0
1. Create unified control inventory across all six planes.
2. Define `hard / progressive / advisory` classification for every active control.
3. Introduce machine-readable registry for control metadata and rollback path.
4. Add noise-budget review fields into recurring review and update-trigger checks.

### P1
1. Identify duplicated rule text and duplicated gate signal, then collapse or demote.
2. Add friction metrics per control: token overhead, latency delta, false positive rate.
3. Add weekly reporting for stale progressive controls and low-value advisories.
4. Formalize source-only vs distributable control boundary.

### P2
1. Define progressive rollout state per target repo.
2. Add downgrade and retirement workflow for over-strict or stale controls.
3. Add target feedback ingestion into source-side policy tuning.
4. Tune top high-value controls from observe/advisory into enforce based on evidence.

## Verification and Review Model
- Planning-stage verification
  - Check plan consistency against existing hard-gate semantics.
  - Confirm every task has owner, artifact, and rollback path.
- Implementation-stage fixed order
  1. `powershell -File scripts/verify-kit.ps1`
  2. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  3. `powershell -File scripts/validate-config.ps1`
  4. `powershell -File scripts/verify.ps1`
  5. `powershell -File scripts/doctor.ps1`
- Review cadence
  - Weekly: friction and signal review
  - Monthly: promotion, downgrade, retirement, and distribution review

## Success Metrics
- Quality
  - `first_pass_rate`
  - `validation_pass_rate`
  - `cross_repo_compatibility_pass_rate`
- Safety
  - `high_risk_approval_coverage`
  - `rollback_ready_coverage`
  - `unsafe_distribution_count`
- Friction
  - `token_per_effective_conclusion`
  - `gate_chain_elapsed_ms`
  - `false_positive_rate`
  - `clarification_escalation_rate`
- Evolution
  - `observe_to_enforce_success_rate`
  - `control_retirement_rate`
  - `stale_progressive_control_count`

## Risks and Rollback
- Risk: inventory becomes a new layer of bloat
  - Mitigation: registry stays metadata-only and drives review automation.
- Risk: friction metrics are collected but not used
  - Mitigation: add trigger checks and monthly review actions tied to thresholds.
- Risk: target repos receive controls too early
  - Mitigation: per-target rollout state and compatibility gate before redistribution.
- Risk: tightening expands blockage without net value
  - Mitigation: require two-cycle observe evidence and rollback trigger before enforce.

## First Execution Slice
1. Write the unified control inventory.
2. Add machine-readable control registry.
3. Extend recurring review to report control noise and stale progressive items.
4. Draft source-only vs distributable boundary rules for every control class.

## Execution Progress (as of 2026-04-14)
- completed
  - unified control inventory + machine-readable registry.
  - rule duplication trigger + rollout metadata coverage trigger.
  - recurring review summary passthrough for duplication/staleness/rollout-coverage signals.
- completed (Phase 1 baseline)
  - `docs/governance/governance-noise-budget.md`
  - `docs/governance/control-retirement-candidates-2026Q2.md`
  - `config/control-retirement-candidates.json`
  - update trigger support for `control_retirement_backlog`.
- completed (Phase 2 slice A)
  - evidence template standardized fields: friction/rollout/downgrade/retirement/replay links.
  - update trigger support for `evidence_template_fields_missing`.
  - recurring review summary added control-plane digest fields:
    - `control_plane_top_noisy_controls`
    - `control_plane_most_bypassed_advisories`
- completed (Phase 4 slice A)
  - per-target rollout matrix source landed: `config/target-control-rollout-matrix.json`.
  - matrix validator landed: `scripts/governance/check-target-rollout-matrix.ps1`.
  - update trigger support for `target_rollout_matrix_gap`.
  - target matrix document landed: `docs/governance/target-rollout-status-matrix-2026Q2.md`.
- next
  - integrate cross-repo feedback counters into recurring review summary.
  - add cross-repo feedback report and ingest counters into recurring review summary.
