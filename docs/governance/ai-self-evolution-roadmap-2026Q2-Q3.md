# AI Self-Evolution Roadmap (2026 Q2-Q3)

## Scope
- Repo: `E:/CODE/repo-governance-hub`
- Time window: `2026-04-13` to `2026-07-11`
- Goal: Build a safe, measurable, and rollbackable self-evolution loop for AI governance.
- Non-goal: No unattended high-risk automation in this cycle.

## Success Criteria
- Hard gates always pass in fixed order: `build -> test -> contract/invariant -> hotspot`.
- Skill promotion create-path has no `no_data` state for trigger eval summary.
- High-risk action unauthorized count remains `0`.
- Metrics improve for at least 4 consecutive weekly cycles.

## Milestones

### M0 Baseline and Gap Closure (`2026-04-13` ~ `2026-04-19`)
- Deliverables
  - Trigger eval dataset seed (`.governance/skill-candidates/trigger-eval-runs.jsonl`) with >= 50 labeled runs.
  - Summary file generation (`.governance/skill-candidates/trigger-eval-summary.json`) stabilized.
  - Block create promotion when summary is missing/invalid/no_data.
- Exit gate
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-skill-trigger-evals.ps1 -RepoRoot . -AsJson`
  - Expect: `status != no_data`, `validation_query_count > 0`.

### M1 Eval Loop Online (`2026-04-20` ~ `2026-05-10`)
- Deliverables
  - Capability eval + regression eval split defined and versioned.
  - Failure signatures mapped to trace/outcome evidence templates.
  - Weekly loop enabled: failure -> candidate -> eval -> promote/reject.
- Exit gate
  - Weekly recurring review includes trigger-eval freshness and pass-rate trend.

### M2 Safe Self-Optimization (`2026-05-11` ~ `2026-06-07`)
- Deliverables
  - Risk-tier approvals (`low/medium/high`) for tools, file changes, and external side effects.
  - Shadow mode (`observe`) with enforce transition thresholds.
  - Automated rollback trigger and drill records.
- Exit gate
  - No high-risk action bypass.
  - Rollback drill succeeds with evidence.

### M3 Scale and Lifecycle (`2026-06-08` ~ `2026-07-11`)
- Deliverables
  - Skill family lifecycle automation (promote/optimize/retire).
  - Cross-repo compatibility gate before redistribution.
  - Monthly governance report with quality/safety/efficiency trend.
- Exit gate
  - Lifecycle metrics published and reviewed.
  - Cross-repo regressions remain within threshold.

## KPI Set
- Quality
  - `first_pass_rate`
  - `validation_pass_rate`
  - `rollback_rate`
- Safety
  - `high_risk_approval_coverage`
  - `unsafe_action_count`
- Efficiency
  - `average_response_token`
  - `token_per_effective_conclusion`
  - gate chain elapsed time
- Evolution
  - promotion success rate
  - optimization quality delta
  - retirement latency

## Risk and Rollback Strategy
1. False-positive policy triggers
- Mitigation: run `observe` first, switch to `enforce` only after threshold.
- Rollback: revert policy file to previous snapshot via `scripts/restore.ps1`.

2. Data drift or biased eval samples
- Mitigation: enforce negative sample ratio and manual spot-check.
- Rollback: freeze promotion create-path and rebuild dataset.

3. Gate latency inflation
- Mitigation: keep hard gate order unchanged; optimize surrounding checks only.
- Rollback: disable non-blocking auxiliary checks.

4. Unclear ownership across workflows
- Mitigation: explicit owner per task in backlog.
- Rollback: pause automation on unresolved ownership conflicts.

## Governance Constraints Alignment
- Must keep fixed hard gate order from project AGENTS.
- Must keep evidence chain: `basis -> command -> evidence -> rollback`.
- `platform_na` and `gate_na` need complete fields and expiry.

## Source Inspirations (for design direction)
- OpenAI safety/eval guidance:
  - `https://developers.openai.com/api/docs/guides/agent-builder-safety`
  - `https://developers.openai.com/api/docs/guides/evaluation-best-practices`
- OpenAI practical guide:
  - `https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf`
- Anthropic eval harness concepts:
  - `https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents`
- Community references:
  - `https://github.com/NousResearch/hermes-agent`
  - `https://github.com/titanwings/colleague-skill`
