# Agent Runtime External Practices Design

## Status
Accepted for planning

## Date
2026-04-15

## Goal
Use proven ideas from agent frameworks, coding agents, memory systems, skill ecosystems, and eval tooling to improve `repo-governance-hub` without creating a second governance plane.

## Non-Goals
- Do not introduce LangGraph, OpenHands, SWE-agent, Mem0, Letta, Hermes, or any other framework as a runtime dependency in this design phase.
- Do not change the fixed gate order: `build -> test -> contract/invariant -> hotspot`.
- Do not promote any new runtime control to `enforce` without observe-mode evidence.
- Do not move skill source of truth away from `source/project/repo-governance-hub/custom/overrides/*`.

## Acceptance Criteria
- External practices are mapped to existing repo concepts: `config`, `scripts/governance`, `tests`, `docs/governance`, `docs/change-evidence`, and recurring review.
- The plan extends the existing agent runtime baseline instead of replacing it.
- Every proposed implementation slice has explicit verification and rollback notes.
- Memory, tool, prompt, and subagent improvements remain policy-governed and auditable.

## Current Repo Context
The repo already has a strong foundation:

- Runtime planning: `docs/governance/agent-runtime-gap-matrix-2026Q2.md`, `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`, `docs/governance/agent-runtime-backlog-2026Q2.md`
- Runtime policy: `config/agent-runtime-policy.json`
- Runtime checker: `scripts/governance/check-agent-runtime-baseline.ps1`
- Skill lifecycle controls: `docs/governance/skill-creation-gate-checklist.md`, `scripts/governance/check-skill-trigger-evals.ps1`, `scripts/governance/promote-skill-candidates.ps1`
- Subagent policy: `config/subagent-trigger-policy.json`
- Noise and rollout controls: `docs/governance/governance-noise-budget.md`, `config/update-trigger-policy.json`

This means the next step is not a broad rewrite. The next step is to refine policy fields, evidence fields, eval coverage, and recurring review signals.

## External Practice Mapping

| Source | Practice to Borrow | Repo Action |
|---|---|---|
| LangGraph | Durable execution, state checkpoints, interrupts, memory, testability, observability | Add checkpoint-like evidence fields and runtime state policy; keep implementation as repo-native scripts first |
| OpenHands | Sandbox isolation, SDLC integration, hooks, audit logs, action scope limits | Strengthen tool contracts with `risk_class`, `approval_policy`, `timeout_ms`, `retry_policy`, `trace_attrs`, and audit evidence |
| SWE-agent / mini-SWE-agent | Problem statements, batch runs, cost limits, trajectory inspector, reproducible environments | Add governance trajectory records and replay-oriented runtime eval datasets |
| Agent Skills | `SKILL.md` structure, progressive disclosure, scripts/references/assets, validation | Tighten skill creation gate, trigger descriptions, and reference-file size discipline |
| OpenAI Cookbook / Agents / Evals | Eval-first iteration, graders, prompt optimization, trace, conversation state, prompt caching | Require eval evidence before prompt/tool/memory promotion; add cacheability and cost fields |
| Hermes | Specialist agents, structured aggregation, selective context sharing, resource-aware concurrency | Refine `subagent-trigger-policy.json` outputs and cap parallelism by risk and write-set evidence |
| Mem0 | Long-term memory layer, memory management, retrieval boundaries | Define memory policy fields without requiring durable memory service adoption |
| Letta | Stateful agents, core/archival memory, portable agent state | Add session/durable/forbidden memory classes, retention, audit, and rollback semantics |
| colleague-skill | Knowledge distillation into skills, incremental correction, version archive, rollback | Improve candidate registry, skill version history, correction evidence, and rollback drills |

## Design Decisions

### Decision 1: Extend the Existing Runtime Policy
Use `config/agent-runtime-policy.json` as the canonical entrypoint for runtime governance. Do not create independent `prompt-registry.json`, `tool-registry.json`, or `memory-policy.json` in Q2 unless one section becomes too large to maintain.

Reason: one source of truth reduces drift and matches the repo's current policy-as-code model.

### Decision 2: Start With Trace and Eval Before Optimization
Prioritize trace fields, trajectory evidence, eval freshness, and cost metrics before optimizing prompt, memory, or skill behavior.

Reason: external projects consistently rely on observability and repeatable evals before safe promotion. Without evidence, optimization becomes subjective.

### Decision 3: Memory Governance Before Memory Platform
Borrow Mem0 and Letta's memory taxonomy, but keep durable memory disabled by default.

Reason: this repo governs multiple targets. A memory service dependency would be premature; policy boundaries are useful immediately.

### Decision 4: Subagents Remain Explicit and Bounded
Keep the existing hard guard requiring explicit parallel intent. Add better evidence and routing hints, but do not let policy auto-spawn agents.

Reason: parallel workers can improve throughput only when write sets are disjoint and the task is not on the critical path.

### Decision 5: Skills Stay Lifecycle-Gated
Borrow colleague-skill's distillation and correction loop, but route reusable skills through the existing candidate, eval, promotion, and rollback gates.

Reason: this preserves the repo's `ack + trigger-eval + family uniqueness + lifecycle policy` discipline.

## Proposed Capability Model

### Runtime State and Trajectory
- `run_id`
- `issue_id`
- `problem_statement_ref`
- `trajectory_ref`
- `checkpoint_ref`
- `replay_ref`
- `rollback_ref`
- `human_interrupt_count`

### Tool Contract
- `tool_name`
- `risk_class`
- `approval_policy`
- `timeout_ms`
- `retry_policy`
- `sandbox_boundary`
- `trace_attrs`
- `side_effect_class`

### Prompt Registry
- `prompt_id`
- `owner`
- `task_class`
- `eval_set`
- `rollback_ref`
- `cacheability`
- `last_eval_at`
- `promotion_mode`

### Memory Policy
- `session_memory`
- `durable_memory`
- `forbidden_memory_classes`
- `retention_rules`
- `audit_requirements`
- `purge_on_user_delete`

### Eval and Promotion
- `smoke`
- `regression`
- `adversarial`
- `cost`
- `trace_grading`
- `noise_budget`
- `promotion_threshold`

### Skill Lifecycle
- `candidate_id`
- `family_signature`
- `source_material_refs`
- `trigger_eval_summary`
- `correction_layer_ref`
- `version_archive_ref`
- `rollback_ref`

## Rollout Strategy

### Phase 0: Planning Freeze
Create this design, an implementation plan, and change evidence. No behavior changes.

### Phase 1: Policy and Evidence Schema
Add missing policy fields and evidence fields in observe mode. Validation should detect malformed fields but avoid blocking unrelated repos during initial rollout.

### Phase 2: Trace and Eval Online
Add trajectory and eval freshness checks to recurring review and doctor. Pilot on `repo-governance-hub`.

### Phase 3: Prompt, Tool, Memory, and Skill Controls
Add registry coverage checks. Keep dynamic behavior in observe mode; only static schema presence can later move to enforce.

### Phase 4: Selective Promotion
Promote low-noise static checks after at least three stable observe cycles and documented false-positive rate within budget.

## Verification Strategy
Use the repo's fixed gate sequence after implementation changes:

1. `powershell -File scripts/verify-kit.ps1`
2. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `powershell -File scripts/validate-config.ps1`
4. `powershell -File scripts/verify.ps1`
5. `powershell -File scripts/doctor.ps1`

For this planning-only change, full gates are useful but may be recorded as documentation-scope verification if no executable logic changes.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Policy bloat | High | Keep one runtime policy entrypoint and retire overlapping fields |
| Noisy advisory output | Medium | Track `false_positive_rate`, `gate_latency_delta_ms`, and token overhead |
| Memory overreach | High | Keep durable memory disabled until a target repo has a concrete need |
| Skill duplication | High | Enforce family uniqueness and canonical override path |
| Parallel-agent confusion | Medium | Require explicit intent, disjoint write-set evidence, and structured aggregation |

## Rollback
Planning docs can be reverted with:

```powershell
git restore docs/superpowers/specs/2026-04-15-agent-runtime-external-practices-design.md docs/superpowers/plans/2026-04-15-agent-runtime-external-practices-optimization.md docs/change-evidence/20260415-agent-runtime-external-practices-planning.md
```

Future implementation rollback must use the existing repository path:

```powershell
powershell -File scripts/restore.ps1
```

## Source References
- LangGraph overview: https://docs.langchain.com/oss/python/langgraph/overview
- OpenHands docs: https://docs.openhands.dev/
- SWE-agent docs: https://swe-agent.com/latest/
- Agent Skills specification: https://agentskills.io/specification
- OpenAI evals: https://developers.openai.com/api/docs/guides/evals
- OpenAI skills for Agents SDK: https://developers.openai.com/blog/skills-agents-sdk
- MCP client concepts: https://modelcontextprotocol.io/docs/learn/client-concepts
- OpenTelemetry GenAI MCP conventions: https://opentelemetry.io/docs/specs/semconv/gen-ai/mcp/
- Mem0 repository: https://github.com/mem0ai/mem0
- Letta repository: https://github.com/letta-ai/letta
- Hermes Agent repository: https://github.com/NousResearch/hermes-agent
- colleague-skill repository: https://github.com/titanwings/colleague-skill
