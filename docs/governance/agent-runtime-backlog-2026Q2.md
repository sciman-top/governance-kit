# AI Agent Runtime Backlog (2026 Q2)

## Priority Legend
- `P0`: baseline definition before any runtime rollout.
- `P1`: observe-mode implementation and signal collection.
- `P2`: enforce tuning and cross-repo distribution.

## Execution Rules
- Before each task: record `goal / non-goal / acceptance / assumptions`.
- After each task: update `docs/change-evidence/YYYYMMDD-topic.md`.
- Gate order remains immutable: `build -> test -> contract/invariant -> hotspot`.
- Promotion rule remains immutable: `no runtime eval evidence -> no enforce promotion`.

## 30-45 Day Window (`2026-04-14` ~ `2026-05-31`)

### Week 1: Planning Freeze
- `P0-01` finalize gap matrix and roadmap.
- `P0-02` create implementation plan for runtime baseline.
- `P0-03` define initial policy schema and terminology.

### Week 2: Policy Skeleton
- `P0-04` add `agent-runtime-policy.json`.
- `P0-05` add metrics template fields.
- `P0-06` add config/schema validation tests.

### Week 3: Observe Signals
- `P1-01` add runtime baseline checker.
- `P1-02` add recurring review advisory fields.
- `P1-03` add doctor advisory summary.

### Week 4-5: Runtime Controls
- `P1-04` prompt registry baseline.
- `P1-05` tool contract registry baseline.
- `P1-06` memory policy baseline.

### Week 6+: Eval and Promotion Prep
- `P2-01` runtime eval suites and sample datasets.
- `P2-02` pilot observe cycles on one repo.
- `P2-03` promote low-noise checks to enforce.

## P0 Tasks

### P0-01 Freeze Runtime Scope
- Owner: Governance Maintainer
- Inputs
  - `docs/governance/external-baseline-gap-matrix.md`
  - `docs/governance/engineering-practice-system-plan-2026Q2.md`
  - `docs/governance/ai-self-evolution-roadmap-2026Q2-Q3.md`
- Outputs
  - runtime gap matrix, roadmap, backlog
- DoD
  - Runtime planning docs explicitly state boundaries with existing governance plans.

### P0-02 Create Execution Plan
- Owner: Governance Maintainer
- Inputs
  - runtime gap matrix and roadmap
- Outputs
  - one implementation plan with ordered tasks and checkpoints
- DoD
  - downstream implementation can start without redefining scope.

### P0-03 Define Runtime Terminology and Policy Schema
- Owner: Governance Maintainer
- Target files
  - Create: `config/agent-runtime-policy.json`
  - Update: `docs/governance/metrics-template.md`
- Required top-level keys
  - `prompt_registry`
  - `tool_contracts`
  - `context_management`
  - `memory_policy`
  - `agent_evals`
  - `agent_observability`
  - `cost_controls`
  - `observe_to_enforce`
- DoD
  - schema parses, names are stable, and docs do not duplicate field semantics elsewhere.

### P0-04 Config Validation Coverage
- Owner: Governance Maintainer
- Target files
  - Update: `scripts/validate-config.ps1`
  - Update: `tests/repo-governance-hub.optimization.tests.ps1`
- Output
  - validate new runtime policy presence, schema, and required defaults
- DoD
  - failing or malformed runtime policy is detected deterministically.

### P0-05 Runtime Metrics Template
- Owner: Governance Maintainer
- Target files
  - Update: `docs/governance/metrics-template.md`
- Required new fields
  - `agent_task_success_rate`
  - `runtime_eval_pass_rate`
  - `cache_hit_rate`
  - `cost_per_successful_run`
  - `tool_error_rate`
  - `compaction_count`
  - `prompt_registry_coverage`
  - `tool_contract_coverage`
  - `memory_policy_coverage`
- DoD
  - metrics template can be used without external platform dependency.

## P1 Tasks

### P1-01 Runtime Baseline Checker
- Owner: Governance Maintainer
- Target files
  - Create: `scripts/governance/check-agent-runtime-baseline.ps1`
  - Update: `scripts/verify-kit.ps1`
- Output
  - advisory checker for runtime policy, required docs, and metrics coverage
- DoD
  - missing runtime artifacts are surfaced as advisory in Q2 initial phase.

### P1-02 Recurring Review Enrichment
- Owner: Governance Maintainer
- Target files
  - Update: `scripts/governance/run-recurring-review.ps1`
- Output
  - recurring review includes runtime KPI summary and policy drift hints
- DoD
  - weekly output contains runtime section with no missing-key ambiguity.

### P1-03 Doctor Advisory Summary
- Owner: Governance Maintainer
- Target files
  - Update: `scripts/doctor.ps1`
- Output
  - doctor prints or exports runtime baseline status
- DoD
  - doctor can show `GREEN/YELLOW` style runtime readiness without blocking unrelated healthy repos initially.

### P1-04 Prompt Registry Baseline
- Owner: Governance Maintainer
- Target files
  - Create: `config/prompt-registry.json` or nested section under `agent-runtime-policy.json`
  - Update: docs and tests accordingly
- Required fields per prompt
  - `prompt_id`
  - `owner`
  - `task_class`
  - `eval_set`
  - `rollback_ref`
  - `cacheability`
- DoD
  - at least one prompt class is registered and validated end-to-end.

### P1-05 Tool Contract Registry Baseline
- Owner: Governance Maintainer
- Required fields per tool
  - `tool_name`
  - `risk_class`
  - `approval_policy`
  - `timeout_ms`
  - `retry_policy`
  - `trace_attrs`
- DoD
  - registry fields map cleanly to existing risk-tier semantics.

### P1-06 Memory Policy Baseline
- Owner: Governance Maintainer
- Required policy slices
  - `session_memory`
  - `durable_memory`
  - `forbidden_memory_classes`
  - `retention_rules`
  - `audit_requirements`
- DoD
  - durable memory remains optional, but forbidden classes are explicit.

## P2 Tasks

### P2-01 Runtime Eval Suites
- Owner: Governance Maintainer
- Output
  - `smoke / regression / adversarial / cost` runtime eval slices
- DoD
  - promotion to enforce is blocked when runtime eval data is missing.

### P2-02 Pilot Observe Cycles
- Owner: Governance Maintainer
- Pilot repo
  - `repo-governance-hub`
- Output
  - three observe cycles with trend evidence
- Pilot thresholds
  - `false_positive_rate <= 5%`
  - `gate_latency_delta_ms <= +3000`
  - `policy_drift_count = 0`
  - `runtime_eval_pass_rate >= 95%`
- DoD
  - false positives and latency deltas are recorded.

### P2-03 Selective Enforce Promotion
- Owner: Governance Maintainer
- Candidate controls
  - policy/schema presence
  - required metrics fields
  - prompt/tool registry coverage floor
- DoD
  - only low-noise static controls move to enforce in Q2.

### P2-04 Cross-Repo Runtime Distribution
- Owner: Governance Maintainer
- Output
  - distribute stable runtime baseline to `skills-manager` and `ClassroomToolkit`
- DoD
  - cross-repo compatibility gate passes before redistribution.

## Verification Plan
1. `powershell -File scripts/verify-kit.ps1`
2. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `powershell -File scripts/validate-config.ps1`
4. `powershell -File scripts/verify.ps1`
5. `powershell -File scripts/doctor.ps1`

## Blocking Rules
1. Any existing hard gate failure blocks runtime rollout.
2. Missing rollback path blocks promote-to-enforce work.
3. Missing runtime eval evidence blocks enforce promotion.
4. Repeated noisy advisory without tuning blocks cross-repo rollout.
5. Any runtime policy field that duplicates an existing canonical policy must be merged, not redefined.

## 2026-04-15 Execution Update

### Completed in this cycle
- `P1-01` runtime baseline checker strengthened (trajectory/tool/memory/eval checks complete).
- `P1-02` recurring review runtime fields expanded (trajectory/replay/checkpoint/interrupt/eval freshness).
- `P1-04` prompt registry baseline extended with `task_class`, `last_eval_at`, `promotion_mode`.
- `P1-05` tool contract baseline extended with `sandbox_boundary`, `side_effect_class`.
- `P1-06` memory boundary completed with audit requirements and `purge_on_user_delete`.
- `P2-01` promotion precondition fields added in policy/checker (`minimum_eval_freshness_days`, `promotion_blocks_on_missing_eval`, `trace_grading_enabled`).
- `P2-04` subagent evidence model extended with structured aggregation fields.

### Observe pilot status
- 3 observe cycles captured on `2026-04-15` (see `docs/change-evidence/20260415-agent-runtime-external-practices.md`).
- Current result: remain `observe`, do not promote to `enforce`.

### Remaining items
- clear update-trigger alert sources (`policy_drift_count` currently non-zero in recurring review).
- complete runtime eval pass-rate data path in metrics for promotion readiness.
- re-run 3-cycle observe with target thresholds:
  - `false_positive_rate <= 5%`
  - `gate_latency_delta_ms <= +3000`
  - `policy_drift_count = 0`
  - `runtime_eval_pass_rate >= 95%`
