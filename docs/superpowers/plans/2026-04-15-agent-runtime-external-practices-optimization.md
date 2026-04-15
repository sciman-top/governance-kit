# Agent Runtime External Practices Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the existing agent runtime governance baseline by mapping external best practices into repo-native policy, evidence, eval, trace, memory, skill, and subagent controls.

**Architecture:** Keep `config/agent-runtime-policy.json` as the canonical runtime governance entrypoint. Add small observe-mode slices that extend existing validation, recurring review, doctor, skill lifecycle, and evidence flows without changing the hard-gate order.

**Tech Stack:** PowerShell scripts, JSON policy files, Markdown governance docs, existing repo verification chain, existing skill lifecycle scripts.

---

## File Structure
- Modify: `config/agent-runtime-policy.json`
- Modify: `config/subagent-trigger-policy.json`
- Modify: `scripts/governance/check-agent-runtime-baseline.ps1`
- Modify: `scripts/governance/run-recurring-review.ps1`
- Modify: `scripts/doctor.ps1`
- Modify: `scripts/validate-config.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/governance/agent-runtime-backlog-2026Q2.md`
- Modify: `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`
- Modify: `docs/governance/metrics-template.md`
- Modify: `docs/governance/skill-creation-gate-checklist.md`
- Modify: `docs/change-evidence/YYYYMMDD-agent-runtime-external-practices.md`

## Checkpoint 0: Planning Freeze
- [ ] Confirm the design doc exists: `docs/superpowers/specs/2026-04-15-agent-runtime-external-practices-design.md`
- [ ] Confirm this plan exists: `docs/superpowers/plans/2026-04-15-agent-runtime-external-practices-optimization.md`
- [ ] Confirm no runtime script behavior has changed during planning

Run:

```powershell
git status --short
```

Expected: only planning docs and change evidence are modified or added.

### Task 1: Add Runtime Trajectory and Replay Fields

**Files:**
- Modify: `config/agent-runtime-policy.json`
- Modify: `scripts/governance/check-agent-runtime-baseline.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/governance/metrics-template.md`

- [ ] **Step 1: Add failing tests for trajectory fields**

Add assertions in `tests/repo-governance-hub.optimization.tests.ps1` that require `agent_observability` to declare these fields:

```powershell
$requiredTrajectoryFields = @(
  'run_id',
  'issue_id',
  'problem_statement_ref',
  'trajectory_ref',
  'checkpoint_ref',
  'replay_ref',
  'rollback_ref',
  'human_interrupt_count'
)
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```

Expected: FAIL because the policy does not yet require the full trajectory field set.

- [ ] **Step 3: Extend `config/agent-runtime-policy.json`**

Add an `agent_observability.trajectory_fields` array containing the exact field names from Step 1. Keep `mode` as `observe`.

- [ ] **Step 4: Extend the runtime checker**

Update `scripts/governance/check-agent-runtime-baseline.ps1` to read `agent_observability.trajectory_fields` and return a `WARN` when a required field is missing.

- [ ] **Step 5: Update metrics template**

Add these lines to `docs/governance/metrics-template.md`:

```text
runtime_trajectory_coverage_rate=
runtime_replay_ref_coverage_rate=
runtime_checkpoint_ref_coverage_rate=
runtime_human_interrupt_count=
```

- [ ] **Step 6: Verify**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/governance/check-agent-runtime-baseline.ps1 -RepoRoot . -AsJson
```

Expected: tests pass; checker JSON includes `status=PASS` or `status=WARN` with explicit trajectory check IDs.

- [ ] **Step 7: Commit**

```powershell
git add config/agent-runtime-policy.json scripts/governance/check-agent-runtime-baseline.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/metrics-template.md
git commit -m "feat: add agent runtime trajectory fields"
```

### Task 2: Strengthen Tool Contract Governance

**Files:**
- Modify: `config/agent-runtime-policy.json`
- Modify: `scripts/validate-config.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/governance/risk-tier-approval-matrix.md`

- [ ] **Step 1: Add failing tests for tool contract fields**

Add assertions that every `tool_contracts.entries` item has:

```powershell
$requiredToolFields = @(
  'tool_name',
  'risk_class',
  'approval_policy',
  'timeout_ms',
  'retry_policy',
  'sandbox_boundary',
  'trace_attrs',
  'side_effect_class'
)
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```

Expected: FAIL because the existing `powershell` entry does not include every new field.

- [ ] **Step 3: Update the policy**

Extend the `powershell` tool contract with:

```json
"sandbox_boundary": "repo_workspace",
"side_effect_class": "filesystem_and_process"
```

Preserve the existing `risk_class`, `approval_policy`, `timeout_ms`, `retry_policy`, and `trace_attrs`.

- [ ] **Step 4: Update validation**

Update `scripts/validate-config.ps1` so malformed tool entries fail contract validation. Accepted `risk_class` values: `low`, `medium`, `high`. Accepted `side_effect_class` values: `read_only`, `filesystem`, `process`, `filesystem_and_process`, `network`, `external_service`.

- [ ] **Step 5: Document mapping**

Add a short section to `docs/governance/risk-tier-approval-matrix.md` explaining that tool contract risk classes must not bypass the existing risk-tier approval matrix.

- [ ] **Step 6: Verify**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/validate-config.ps1
```

Expected: tests pass; validation rejects malformed tool contracts.

- [ ] **Step 7: Commit**

```powershell
git add config/agent-runtime-policy.json scripts/validate-config.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/risk-tier-approval-matrix.md
git commit -m "feat: strengthen agent runtime tool contracts"
```

## Checkpoint 1: Trace and Tool Contracts Online
- [ ] `check-agent-runtime-baseline.ps1` reports trajectory checks
- [ ] `validate-config.ps1` validates expanded tool contracts
- [ ] Existing hard-gate order is unchanged

### Task 3: Add Memory Governance Boundary

**Files:**
- Modify: `config/agent-runtime-policy.json`
- Modify: `scripts/governance/check-agent-runtime-baseline.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`

- [ ] **Step 1: Add failing tests for memory policy shape**

Assert that `memory_policy` includes:

```powershell
$requiredMemoryFields = @(
  'session_memory',
  'durable_memory',
  'forbidden_memory_classes',
  'retention_rules',
  'audit_requirements',
  'purge_on_user_delete'
)
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```

Expected: FAIL if `audit_requirements` or top-level `purge_on_user_delete` is missing.

- [ ] **Step 3: Update memory policy**

Keep durable memory disabled. Add:

```json
"audit_requirements": {
  "record_memory_write_reason": true,
  "record_source_refs": true,
  "record_purge_action": true
},
"purge_on_user_delete": true
```

- [ ] **Step 4: Update runtime checker**

Warn when `forbidden_memory_classes` omits `secrets` or `raw_credentials`. Warn when durable memory is enabled without audit requirements.

- [ ] **Step 5: Update roadmap**

Clarify in `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md` that Q2 memory work is boundary governance only, not external memory-platform adoption.

- [ ] **Step 6: Verify**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/governance/check-agent-runtime-baseline.ps1 -RepoRoot . -AsJson
```

Expected: tests pass; durable memory remains disabled; checker reports memory boundary checks.

- [ ] **Step 7: Commit**

```powershell
git add config/agent-runtime-policy.json scripts/governance/check-agent-runtime-baseline.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/agent-runtime-roadmap-2026Q2-Q3.md
git commit -m "feat: add agent runtime memory governance boundary"
```

### Task 4: Add Eval-First Promotion Checks

**Files:**
- Modify: `config/agent-runtime-policy.json`
- Modify: `scripts/governance/check-agent-runtime-baseline.ps1`
- Modify: `scripts/governance/run-recurring-review.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/governance/agent-runtime-backlog-2026Q2.md`

- [ ] **Step 1: Add failing tests for eval freshness fields**

Require `agent_evals` to include:

```powershell
$requiredEvalFields = @(
  'required_suites',
  'minimum_eval_freshness_days',
  'promotion_blocks_on_missing_eval',
  'trace_grading_enabled'
)
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```

Expected: FAIL because the policy only lists required suites.

- [ ] **Step 3: Update policy**

Set:

```json
"minimum_eval_freshness_days": 14,
"promotion_blocks_on_missing_eval": true,
"trace_grading_enabled": true
```

- [ ] **Step 4: Update checker**

Warn when eval freshness data is absent in observe mode. Fail only when `mode=enforce`.

- [ ] **Step 5: Update recurring review**

Add runtime eval fields to recurring review JSON:

```text
runtime_eval_freshness_days
runtime_eval_missing_blocks_promotion
runtime_trace_grading_enabled
```

- [ ] **Step 6: Update backlog**

Mark runtime eval as a prerequisite for any prompt, tool, memory, or skill promotion.

- [ ] **Step 7: Verify**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson
```

Expected: tests pass; recurring review includes runtime eval freshness fields.

- [ ] **Step 8: Commit**

```powershell
git add config/agent-runtime-policy.json scripts/governance/check-agent-runtime-baseline.ps1 scripts/governance/run-recurring-review.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/agent-runtime-backlog-2026Q2.md
git commit -m "feat: require eval evidence for runtime promotion"
```

## Checkpoint 2: Memory and Eval Boundaries Online
- [ ] Durable memory remains optional and disabled by default
- [ ] Missing eval evidence blocks promotion policy
- [ ] Recurring review exposes runtime eval freshness

### Task 5: Improve Skill Lifecycle With Distillation and Correction Evidence

**Files:**
- Modify: `docs/governance/skill-creation-gate-checklist.md`
- Modify: `scripts/governance/promote-skill-candidates.ps1`
- Modify: `scripts/governance/check-skill-lifecycle-health.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Add failing tests for skill lifecycle evidence**

Require create or optimize candidates to carry:

```powershell
$requiredSkillEvidenceFields = @(
  'candidate_id',
  'family_signature',
  'source_material_refs',
  'trigger_eval_summary',
  'correction_layer_ref',
  'version_archive_ref',
  'rollback_ref'
)
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```

Expected: FAIL because current lifecycle checks do not require every distillation and correction field.

- [ ] **Step 3: Update promotion checks**

Update `scripts/governance/promote-skill-candidates.ps1` so missing `source_material_refs`, `version_archive_ref`, or `rollback_ref` blocks `create` and `optimize` promotion.

- [ ] **Step 4: Update lifecycle health checks**

Update `scripts/governance/check-skill-lifecycle-health.ps1` to warn when `correction_layer_ref` is missing for an evolved skill candidate.

- [ ] **Step 5: Update checklist**

Add a section to `docs/governance/skill-creation-gate-checklist.md` named `Distillation and Correction Evidence`. Include the required fields from Step 1.

- [ ] **Step 6: Verify**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/governance/check-skill-lifecycle-health.ps1 -RepoRoot . -AsJson
```

Expected: tests pass; lifecycle health output includes distillation/correction evidence status.

- [ ] **Step 7: Commit**

```powershell
git add docs/governance/skill-creation-gate-checklist.md scripts/governance/promote-skill-candidates.ps1 scripts/governance/check-skill-lifecycle-health.ps1 tests/repo-governance-hub.optimization.tests.ps1
git commit -m "feat: require skill distillation correction evidence"
```

### Task 6: Refine Subagent Policy Evidence and Aggregation

**Files:**
- Modify: `config/subagent-trigger-policy.json`
- Modify: `scripts/governance/run-target-autopilot.ps1`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`

- [ ] **Step 1: Add failing tests for structured aggregation fields**

Require subagent decision evidence to include:

```powershell
$requiredSubagentFields = @(
  'spawn_parallel_subagents',
  'max_parallel_agents',
  'decision_score',
  'reason_codes',
  'hard_guard_hits',
  'signals',
  'policy_path',
  'disjoint_write_set_refs',
  'structured_result_schema',
  'aggregation_owner'
)
```

- [ ] **Step 2: Run the test and confirm failure**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
```

Expected: FAIL because the current evidence field set lacks aggregation-specific fields.

- [ ] **Step 3: Update policy**

Add the new required fields under `evidence.required_fields`. Keep `require_explicit_parallel_intent=true`.

- [ ] **Step 4: Update autopilot output**

Update `scripts/governance/run-target-autopilot.ps1` to emit the new fields with empty arrays or explicit `null` values when no parallel work is recommended.

- [ ] **Step 5: Update roadmap**

Document that the main agent remains the aggregation owner and that workers must return structured results instead of chained summaries.

- [ ] **Step 6: Verify**

Run:

```powershell
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/governance/run-target-autopilot.ps1 -RepoRoot . -AsJson
```

Expected: tests pass; autopilot JSON includes the new aggregation fields.

- [ ] **Step 7: Commit**

```powershell
git add config/subagent-trigger-policy.json scripts/governance/run-target-autopilot.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/agent-runtime-roadmap-2026Q2-Q3.md
git commit -m "feat: add structured subagent aggregation evidence"
```

## Checkpoint 3: Lifecycle and Subagent Refinements Online
- [ ] Skill promotion records distillation, correction, archive, and rollback evidence
- [ ] Subagent policy keeps explicit intent guard
- [ ] Subagent output has structured aggregation fields

### Task 7: Pilot Observe Runs and Promotion Decision

**Files:**
- Modify: `docs/change-evidence/YYYYMMDD-agent-runtime-external-practices.md`
- Modify: `docs/governance/agent-runtime-backlog-2026Q2.md`
- Modify: `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`

- [ ] **Step 1: Run full hard gate chain**

Run:

```powershell
powershell -File scripts/verify-kit.ps1
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/validate-config.ps1
powershell -File scripts/verify.ps1
powershell -File scripts/doctor.ps1
```

Expected: every command exits `0`.

- [ ] **Step 2: Run runtime-specific observe checks**

Run:

```powershell
powershell -File scripts/governance/check-agent-runtime-baseline.ps1 -RepoRoot . -AsJson
powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson
```

Expected: runtime checks are present; observe-mode warnings are explicit and do not bypass hard gates.

- [ ] **Step 3: Record pilot evidence**

Create or update `docs/change-evidence/YYYYMMDD-agent-runtime-external-practices.md` with:

```text
runtime_policy_mode=
runtime_trajectory_coverage_rate=
runtime_eval_freshness_days=
prompt_registry_coverage=
tool_contract_coverage=
memory_policy_coverage=
false_positive_rate=
gate_latency_delta_ms=
policy_drift_count=
rollback_ref=
```

- [ ] **Step 4: Repeat observe cycle**

Run the full hard gate chain and runtime observe checks three times across separate work sessions or scheduled recurring review runs.

Expected: no policy drift, no high-severity false positive, and no gate latency budget breach.

- [ ] **Step 5: Decide promotion candidates**

Promote only static checks that meet all criteria:

```text
false_positive_rate <= 0.05
policy_drift_count = 0
gate_latency_delta_ms <= 3000
runtime_eval_pass_rate >= 0.95
```

- [ ] **Step 6: Update roadmap and backlog**

Record which controls stay `observe` and which are candidates for `enforce`.

- [ ] **Step 7: Commit**

```powershell
git add docs/change-evidence/*.md docs/governance/agent-runtime-backlog-2026Q2.md docs/governance/agent-runtime-roadmap-2026Q2-Q3.md
git commit -m "docs: record agent runtime external practices pilot"
```

## Final Verification

Run:

```powershell
powershell -File scripts/verify-kit.ps1
powershell -File tests/repo-governance-hub.optimization.tests.ps1
powershell -File scripts/validate-config.ps1
powershell -File scripts/verify.ps1
powershell -File scripts/doctor.ps1
```

Expected: all commands exit `0`.

Run tracked-files policy before any final commit or push:

```powershell
powershell -File scripts/governance/check-tracked-files.ps1 -Scope pending -AsJson
```

Expected: no `review_required` file blocks the commit.

## Rollback

For planning-only files:

```powershell
git restore docs/superpowers/specs/2026-04-15-agent-runtime-external-practices-design.md docs/superpowers/plans/2026-04-15-agent-runtime-external-practices-optimization.md docs/change-evidence/20260415-agent-runtime-external-practices-planning.md
```

For implementation changes:

```powershell
powershell -File scripts/restore.ps1
```

## Self-Review
- Spec coverage: every design capability maps to at least one task.
- Placeholder scan: no unresolved placeholder marker or unspecified implementation step remains.
- Dependency order: trace/tool fields precede memory/eval/lifecycle/subagent refinements; promotion happens last.
- Scope control: no external framework is introduced as a dependency.
