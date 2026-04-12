# AI Self-Evolution Roadmap (2026 Q2-Q3, Integrated Edition)

## Scope and Positioning
- Repo: `E:/CODE/repo-governance-hub`
- Time window: `2026-04-13` to `2026-07-11`
- Goal: Build a safe, measurable, rollbackable, and continuously improving AI governance loop.
- Non-goal: Unattended high-risk automation and unverified auto-promotion.
- Current landing zone: `docs/governance/*` planning and runbook artifacts.
- Target destination: `config/* + scripts/governance/* + docs/change-evidence/*` execution-verified closed loop.

## Design Principles (mapped from official/community practice)
1. Closed-loop evolution, not self-modification by default
- Loop: `trace -> eval -> decision -> rollout -> rollback -> relearn`.

2. Evaluation-first promotion
- No candidate can be promoted without reproducible eval evidence.

3. High-risk actions are bounded
- Keep `observe -> enforce` transition and approval matrix.

4. Durable execution and replayability
- Failures must be replayable via taxonomy and evidence.

## Success Criteria
- Hard gates always pass in order: `build -> test -> contract/invariant -> hotspot`.
- Trigger-eval create-path has no `no_data`/`missing` state.
- Unauthorized high-risk action count remains `0`.
- Quality/safety/efficiency metrics improve for 4 consecutive weekly cycles.
- Auto-rollback drills complete within agreed recovery window.

## Architecture of the Evolution Loop
1. Observe
- Collect runs, outcomes, and failure signatures.

2. Evaluate
- Score with `capability + regression + adversarial` slices.

3. Decide
- Use hard guard + score threshold + risk-tier policy.

4. Rollout
- Start from `observe`, then promote to `enforce` on thresholds.

5. Recover
- Trigger rollback on quality/safety regression.

6. Learn
- Register reusable candidates and retire stale low-value entries.

## 90-Day Milestones

### M0 Baseline and Gap Closure (`2026-04-13` ~ `2026-04-19`)
- Deliverables
  - Trigger-eval seed dataset (`.governance/skill-candidates/trigger-eval-runs.jsonl`) with >= 80 labeled samples.
  - Stable summary generation (`.governance/skill-candidates/trigger-eval-summary.json`).
  - Deterministic create-path block on missing/invalid/no-data summary.
- Exit gate
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-skill-trigger-evals.ps1 -RepoRoot . -AsJson`
  - Expect: `status != no_data`, `validation_query_count > 0`.

### M1 Eval and Replay Online (`2026-04-20` ~ `2026-05-10`)
- Deliverables
  - Eval suites versioned: `smoke/regression/adversarial`.
  - Failure taxonomy and replay readiness bound to evidence.
  - Weekly loop live: `failure -> candidate -> eval -> promote/reject`.
- Exit gate
  - Weekly report includes eval freshness, pass trend, and replay coverage.

### M2 Safe Optimization (`2026-05-11` ~ `2026-06-07`)
- Deliverables
  - Risk-tier approval matrix enforced for tool/file/side-effect scopes.
  - `observe -> enforce` thresholds with cooling window.
  - Auto-rollback trigger and drill records.
- Exit gate
  - Zero high-risk bypass.
  - Rollback drill success with time-to-recovery evidence.

### M3 Scale and Lifecycle (`2026-06-08` ~ `2026-07-11`)
- Deliverables
  - Candidate lifecycle automation (`promote/optimize/retire`).
  - Cross-repo compatibility gate before redistribution.
  - Monthly governance report with trend and corrective actions.
- Exit gate
  - Lifecycle metrics published and reviewed.
  - Cross-repo regressions remain below threshold.

## KPI Set
- Quality: `first_pass_rate`, `validation_pass_rate`, `rollback_rate`
- Safety: `high_risk_approval_coverage`, `unsafe_action_count`
- Efficiency: `average_response_token`, `token_per_effective_conclusion`, `gate_chain_elapsed_ms`
- Evolution: `promotion_success_rate`, `optimization_quality_delta`, `retirement_latency`

## Risk and Rollback Strategy
1. False positive policy triggers
- Mitigation: enforce `observe` window and threshold checks.
- Rollback: `scripts/restore.ps1` to latest valid snapshot.

2. Data drift and skewed evals
- Mitigation: balance positive/near-miss negatives and periodic spot-check.
- Rollback: freeze create-promotion and rebuild eval pool.

3. Gate latency inflation
- Mitigation: keep hard-gate semantics unchanged, optimize only peripherals.
- Rollback: disable non-blocking adjunct checks.

4. Rule and script bloat
- Mitigation: monthly de-dup review and complexity budget.
- Rollback: retire low-value checks and merge overlapping policies.

## Governance Constraints Alignment
- Keep fixed order: `build -> test -> contract/invariant -> hotspot`.
- Keep traceability chain: `basis -> command -> evidence -> rollback`.
- `platform_na` and `gate_na` must include `reason`, `alternative_verification`, `evidence_link`, `expires_at`.

## Mapping: External Practice -> Repo Action
1. Hermes-agent (memory/context/skills/security)
- Repo action: strengthen candidate memory and skill lifecycle gates.

2. colleague-skill (knowledge distillation and iterative skill growth)
- Repo action: formalize candidate registry, trigger-eval, and promotion checks.

3. OpenAI guidance (trace + eval + guardrails)
- Repo action: enforce eval-first promotion and trace-grading artifacts.

4. Anthropic harness guidance (long-running reliability)
- Repo action: keep progress logs, replay pool, and E2E gate verification.

5. LangGraph-style persistence/replay (inference)
- Repo action: maintain checkpoint-like evidence snapshots and rollback drills.

## Source References
- `https://raw.githubusercontent.com/NousResearch/hermes-agent/main/README.md`
- `https://hermes-agent.nousresearch.com/docs/user-guide/features/memory`
- `https://hermes-agent.nousresearch.com/docs/user-guide/security`
- `https://raw.githubusercontent.com/titanwings/colleague-skill/main/README.md`
- `https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/`
- `https://developers.openai.com/api/docs/guides/evaluation-best-practices`
- `https://developers.openai.com/api/docs/guides/trace-grading`
- `https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents`
- `https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents`
