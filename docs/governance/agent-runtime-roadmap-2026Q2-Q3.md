# AI Agent Runtime Roadmap (2026 Q2-Q3)

## Scope and Positioning
- Repo: `repo-governance-hub`
- Planning date: `2026-04-14`
- Time window: `2026-04-14` to `2026-07-31`
- Goal: Build a thin-core, auditable, rollbackable `agent runtime` governance baseline for governed repositories.
- Non-goal: Ship a new general-purpose agent framework or replace the current governance stack.
- Current landing zone: `docs/governance/agent-runtime-*.md`
- Target destination: `config/agent-runtime-policy.json + scripts/governance/* + tests/* + recurring review / doctor aggregation`

## Goal / Non-goal / Acceptance / Assumptions
- Goal
  - Add a unified governance layer for `prompt / tool / context / memory / eval / trace / cost`.
  - Reuse the repo's existing source-of-truth and distribution model.
  - Keep hard-gate order unchanged: `build -> test -> contract/invariant -> hotspot`.
- Non-goal
  - No immediate external vendor lock-in.
  - No default durable-memory requirement in Q2.
  - No second evidence system outside `docs/change-evidence/`.
- Acceptance
  - A single runtime policy source exists and is validated.
  - Runtime metrics appear in recurring review and doctor output.
  - At least one target repo can run the runtime baseline in `observe` mode without regressions.
  - Promotion from `observe` to `enforce` uses evidence, not intuition.
- Assumptions
  - `scripts/install.ps1` remains the rollout source of truth.
  - Existing governance docs and evidence model stay intact and are extended, not replaced.

## Design Principles
1. Thin core first
- Only encode the smallest stable cross-repo runtime rules in Q2.

2. Observe before enforce
- All new runtime controls start in `observe`, then promote selectively.

3. Runtime governance, not framework worship
- Absorb ideas from OpenAI, Anthropic, MCP, OTel, Langfuse, Promptfoo, OpenHands, PydanticAI, Mem0, Letta.
- Do not mirror any one project wholesale.

4. Metrics before optimization
- No prompt/tool/memory optimization becomes policy without measurable before/after evidence.

5. One source of truth
- Policy fields live in config.
- Scripts verify and aggregate.
- Docs explain intent and rollout.

## Runtime Capability Model

### 1. Prompt Layer
- Versioned prompt assets
- Owner and rollback reference
- Eval-set linkage

### 2. Tool Layer
- Contract metadata
- Risk and approval boundary
- Retry/timeout/caching hints

### 3. Context Layer
- Context compaction policy
- Cacheability markers
- Conversation-state visibility

### 4. Memory Layer
- Session-only memory
- Durable memory policy boundary
- Forbidden write/read classes

### 5. Evaluation Layer
- Smoke
- Regression
- Adversarial
- Cost-efficiency

### 6. Observability Layer
- Trace fields
- Tool-call metrics
- Token/cost metrics
- Replayability links

## Milestones

### M0 Runtime Gap Freeze (`2026-04-14` ~ `2026-04-20`)
- Deliverables
  - `agent-runtime-gap-matrix-2026Q2.md`
  - `agent-runtime-roadmap-2026Q2-Q3.md`
  - `agent-runtime-backlog-2026Q2.md`
  - one execution plan for implementation slicing
- Exit gate
  - Scope is explicit.
  - No overlap ambiguity with `practice-stack` or `ai-self-evolution`.

### M1 Policy Skeleton and Metric Schema (`2026-04-21` ~ `2026-05-04`)
- Deliverables
  - `config/agent-runtime-policy.json`
  - metric schema additions in `docs/governance/metrics-template.md`
  - script stub or checker for runtime baseline presence
- Exit gate
  - `verify-kit + validate-config` can read policy schema.
  - New fields are optional/advisory only.

### M2 Observe-Mode Runtime Signals (`2026-05-05` ~ `2026-05-25`)
- Deliverables
  - recurring review includes runtime KPI snapshot
  - doctor includes runtime advisory status
  - prompt/tool/memory baseline checks available
- Exit gate
  - one repo pilot in `observe` mode completes 3 cycles with acceptable noise.

### M3 Eval and Replay Integration (`2026-05-26` ~ `2026-06-22`)
- Deliverables
  - runtime eval suites: `smoke/regression/adversarial/cost`
  - replay dataset linked to runtime issue signatures
  - promotion precondition: no eval evidence, no runtime promotion
- Exit gate
  - recurring review shows runtime eval freshness and pass trend.

### M4 Selective Enforce Promotion (`2026-06-23` ~ `2026-07-31`)
- Deliverables
  - promote low-noise static runtime checks to enforce
  - keep high-variance runtime heuristics in observe
  - publish promotion/rollback criteria
- Exit gate
  - 3 consecutive cycles pass with stable latency and acceptable false positives.

## Recommended Delivery Sequence
1. `trace / metrics / cost`
2. `prompt registry`
3. `tool contract registry`
4. `memory policy`
5. `runtime eval suites`
6. `observe -> enforce` promotion

## KPI Set
- Quality
  - `agent_task_success_rate`
  - `runtime_eval_pass_rate`
  - `first_pass_rate`
- Stability
  - `tool_error_rate`
  - `retry_rate`
  - `compaction_count`
- Cost
  - `average_input_tokens`
  - `average_output_tokens`
  - `cache_hit_rate`
  - `cost_per_successful_run`
- Governance
  - `prompt_registry_coverage`
  - `tool_contract_coverage`
  - `memory_policy_coverage`
  - `runtime_policy_drift_count`

## Risks and Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Runtime policy grows into a second governance plane | High | Keep one config entrypoint and reuse current gates |
| Observability fields create reporting noise | Medium | Start advisory-only, track noise budget |
| Memory governance gets overdesigned too early | High | Q2 only define allowed/forbidden boundary |
| Prompt optimization becomes subjective | Medium | Require eval and cost evidence before promotion |
| Tool registry drifts from actual runtime behavior | Medium | Bind registry checks to tests and recurring review |

## Mapping: External Practice -> Repo Action
1. Anthropic prompt caching / tool use / hooks
- Repo action: add runtime fields for cacheability, tool approval boundary, hook-like interception points.

2. OpenAI evals / prompt caching / built-in tools / conversation state
- Repo action: formalize runtime eval slices, state visibility, and prompt version linkage.

3. MCP client/server concepts
- Repo action: standardize `tool / prompt / resource / root` terminology in docs and policy.

4. OpenTelemetry GenAI + MCP semantic conventions
- Repo action: normalize trace field names for `doctor` and recurring review.

5. Langfuse / Promptfoo / OpenLIT / OpenLLMetry / PydanticAI / OpenHands
- Repo action: borrow patterns for prompt registry, eval-in-CI, OTel-native tracing, typed contracts, and replayable agent runs.

## Verification Strategy
1. Planning/document phase
- Verify docs are internally consistent and non-overlapping.

2. Policy introduction phase
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1`

3. Pilot phase
- run recurring review three times on pilot repo
- inspect `false_positive_rate`, `gate_latency_delta_ms`, `policy_drift_count`

## Pilot Success Thresholds (Observe Mode)
- `false_positive_rate <= 5%`
- `gate_latency_delta_ms <= +3000`
- `policy_drift_count = 0`
- `runtime_eval_pass_rate >= 95%`
- Promotion guard: any threshold breach keeps runtime controls in `observe` and requires evidence-backed tuning before next cycle.

## Rollback Strategy
- Revert runtime policy additions and related checker hooks.
- Restore last validated snapshot through `scripts/restore.ps1`.
- Keep evidence in `docs/change-evidence/`.
- Re-run full four-stage gate chain before redistributing.

## 2026-04-15 Runtime Progress Snapshot
- policy/checker coverage: `PASS` (no warnings) for runtime baseline.
- hard gate chain: `PASS` (`verify-kit`, `tests`, `validate-config`, `verify`, `doctor`).
- recurring review: runtime fields are present; current observe cycles still report governance alerts outside hard-gate failure.

### Promotion posture
- keep `observe` for runtime controls in Q2 current state.
- do not promote to `enforce` until:
  - `policy_drift_count = 0`
  - runtime eval pass trend is available and meets threshold
  - cross-repo feedback alert is cleared

### Aggregation and lifecycle refinements now online
- subagent evidence includes:
  - `disjoint_write_set_refs`
  - `structured_result_schema`
  - `aggregation_owner`
- skill lifecycle evidence includes distillation/correction fields:
  - `source_material_refs`
  - `trigger_eval_summary`
  - `correction_layer_ref`
  - `version_archive_ref`
  - `rollback_ref`
