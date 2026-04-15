# Change Evidence: Agent Runtime External Practices Planning

## Task Snapshot
- issue_id: `agent-runtime-external-practices-20260415`
- mode: `direct_fix`
- risk_level: `low`
- proactive_suggestion_mode: `lite`
- current_landing: `docs/superpowers/specs/`, `docs/superpowers/plans/`, `docs/change-evidence/`
- target_destination: existing `agent runtime` governance baseline, primarily `config/agent-runtime-policy.json` and related governance scripts in future implementation phases

## Goal / Non-Goal / Acceptance / Assumptions
- Goal: map LangGraph, OpenHands, SWE-agent, Agent Skills, OpenAI Cookbook/Agents/Evals, Hermes, Mem0, Letta, and colleague-skill practices into a repo-native optimization plan.
- Non-goal: change runtime behavior, rule source files, scripts, tests, or distribution mappings in this planning step.
- Acceptance: design doc and implementation plan exist, external practice mapping is explicit, rollback is documented, and worktree remains limited to planning artifacts.
- Assumptions: existing `agent-runtime-policy.json`, runtime checker, roadmap, and backlog are the correct starting point.

## Basis
- User confirmed proceeding after the external-practice analysis.
- Repo rule requires `basis -> command -> evidence -> rollback`.
- Existing runtime baseline already exists and should be extended rather than replaced.

## Commands and Evidence

| Command | Exit Code | Key Output |
|---|---:|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File source/project/repo-governance-hub/custom/overrides/custom-windows-encoding-guard/scripts/bootstrap.ps1 -AsJson` | `0` | `compliant_after=true` |
| `codex --version` | `0` | `codex-cli 0.120.0` |
| `codex --help` | `0` | `exec`, `review`, `mcp`, `sandbox`, `cloud`, `app-server`, `features` available |
| `codex status` | `1` | `stdin is not a terminal` |
| `git status --short` | `0` | no output before planning edits |
| `git branch --show-current` | `0` | `main` |

## platform_na
- reason: `codex status` requires an interactive terminal in this environment.
- alternative_verification: captured `codex --version`, `codex --help`, active repo path, and active project rules from provided context.
- evidence_link: this file, `Commands and Evidence`.
- expires_at: `2026-05-15`

## Files Added
- `docs/superpowers/specs/2026-04-15-agent-runtime-external-practices-design.md`
- `docs/superpowers/plans/2026-04-15-agent-runtime-external-practices-optimization.md`
- `docs/change-evidence/20260415-agent-runtime-external-practices-planning.md`

## External Practices Mapped
- LangGraph: durable execution, interrupts, memory, observability.
- OpenHands: sandbox, SDLC integration, hooks, audit and approval boundaries.
- SWE-agent / mini-SWE-agent: problem statements, trajectories, batch evaluation, inspectability.
- Agent Skills: `SKILL.md`, progressive disclosure, validation, scripts/references/assets split.
- OpenAI Cookbook / Agents / Evals: eval-first promotion, graders, trace, prompt caching, cost controls.
- Hermes: specialist agents, structured aggregation, selective context sharing.
- Mem0: long-term memory taxonomy and memory management boundaries.
- Letta: stateful agents, session/durable memory, portable state concepts.
- colleague-skill: knowledge distillation, correction layer, version archive, rollback.

## Verification
- Planning self-review completed:
  - no behavior changes in scripts or policy files
  - design has goal, non-goals, acceptance, decisions, rollout, risks, rollback
  - implementation plan has ordered tasks, file paths, commands, expected outcomes, and rollback
- Full hard gates were executed after planning docs were added:
  - build: `powershell -File scripts/verify-kit.ps1` -> exit `0`, `repo-governance-hub integrity OK`
  - test: `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> exit `0`, `Passed: 150 Failed: 0`
  - contract/invariant: `powershell -File scripts/validate-config.ps1` -> exit `0`, `Config validation passed`
  - contract/invariant: `powershell -File scripts/verify.ps1` -> exit `0`, `Verify done. ok=324 fail=0`
  - hotspot: `powershell -File scripts/doctor.ps1` -> exit `0`, `HEALTH=GREEN`
- Test rerun note: the first test invocation timed out at the tool limit while the background `pwsh -File tests/repo-governance-hub.optimization.tests.ps1` process continued. Root cause was command duration, not a failing test; the same command completed in about 230 seconds with all tests passing when rerun with a longer timeout.

## Rollback
Planning rollback:

```powershell
git restore docs/superpowers/specs/2026-04-15-agent-runtime-external-practices-design.md docs/superpowers/plans/2026-04-15-agent-runtime-external-practices-optimization.md docs/change-evidence/20260415-agent-runtime-external-practices-planning.md
```

If future implementation changes affect distributed governance artifacts, use:

```powershell
powershell -File scripts/restore.ps1
```

## Learning Points
- `agent runtime` should remain a thin governance layer, not become a framework dependency.
- Eval and trace evidence should precede prompt, tool, memory, and skill optimization.
- Memory policy can borrow Mem0/Letta concepts without adopting durable memory by default.

## Reusable Checklist
- Map external practice to an existing repo control before adding a new control.
- Prefer observe-mode evidence over immediate enforcement.
- Add rollout, noise budget, and rollback criteria before promotion.

## Open Questions
- Whether runtime trajectory evidence should be stored as Markdown evidence, JSONL, or both.
- Whether prompt/tool/memory registry fields should remain nested in `agent-runtime-policy.json` for all of Q2.
