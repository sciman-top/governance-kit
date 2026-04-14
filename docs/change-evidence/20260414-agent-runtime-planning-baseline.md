# 20260414 Agent Runtime Planning Baseline

## Goal
- 为 `repo-governance-hub` 补齐 `agent runtime` 专项规划线，形成可执行的差距矩阵、roadmap、backlog 与实施计划。

## Non-goal
- 本次不修改 `config/*`、`scripts/*`、`tests/*` 的运行逻辑。
- 本次不引入新的外部 runtime 平台或 memory 存储。

## Acceptance
- 新增文档能明确回答：
  - 为什么本仓需要单独的 `agent runtime` 主线；
  - 与 `practice-stack`、`ai-self-evolution` 的边界；
  - Q2-Q3 里程碑、P0/P1/P2 backlog、后续实施顺序。

## Key Assumptions
- `scripts/install.ps1` 仍为分发 source of truth。
- 当前四段门禁与证据模型保持不变。
- `agent runtime` 先从 `observe` 开始，不直接进入 `enforce`。

## Basis
- 用户提出对标：Anthropic `costs/hooks/prompt-caching/skills/tool-use`，OpenAI `prompt-caching/prompt-engineering`，以及 `OpenAI Cookbook`、`Agent Skills`、`Aider repo map`、`Cline`、`Mem0`、`Letta`。
- 仓内已存在与此相关的治理入口：
  - `docs/governance/external-baseline-gap-matrix.md`
  - `docs/governance/engineering-practice-system-plan-2026Q2.md`
  - `docs/governance/ai-self-evolution-roadmap-2026Q2-Q3.md`
  - `docs/governance/ai-self-evolution-task-backlog-2026Q2.md`

## Commands
- `Get-ChildItem -Force | Select-Object Name,Mode,Length`
- `rg --files -g README* -g docs/** -g source/** -g config/**`
- `Get-Content README.md -TotalCount 220`
- `Get-Content docs/governance/external-baseline-gap-matrix.md -TotalCount 260`
- `Get-Content config/practice-stack-policy.json -TotalCount 260`
- `Get-Content docs/governance/engineering-practice-system-plan-2026Q2.md -TotalCount 260`
- `Get-Content docs/PLANS.md -TotalCount 240`
- `Get-Content docs/governance/ai-self-evolution-roadmap-2026Q2-Q3.md -TotalCount 240`
- `Get-Content docs/governance/ai-self-evolution-task-backlog-2026Q2.md -TotalCount 240`
- Web references gathered from official Anthropic / OpenAI / MCP / OpenTelemetry docs and selected community repositories.

## Changes
- Added `docs/governance/agent-runtime-gap-matrix-2026Q2.md`
- Added `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`
- Added `docs/governance/agent-runtime-backlog-2026Q2.md`
- Added `docs/superpowers/plans/2026-04-14-agent-runtime-baseline.md`
- Added this evidence file

## Why This Shape
- `gap matrix` 负责“为什么做、差距在哪里”。
- `roadmap` 负责“按什么阶段推进、何时从 observe 进入 enforce”。
- `backlog` 负责“P0/P1/P2 做什么”。
- `implementation plan` 负责“下一轮如何直接开工”。

## Observable Signals
- 文档中已统一术语：
  - `prompt_registry`
  - `tool_contracts`
  - `context_management`
  - `memory_policy`
  - `agent_evals`
  - `agent_observability`
  - `cost_controls`
  - `observe_to_enforce`
- 与既有计划的边界已显式写明，避免与 `practice-stack`、`ai-self-evolution` 重叠。

## Troubleshooting Path
- 若后续实施时出现“字段重复定义”：
  - 优先检查 `config/agent-runtime-policy.json` 是否成为单一入口。
- 若后续实施时出现“报告噪音过大”：
  - 先将运行时指标保持为 advisory，并记录 `false_positive_rate` 与 `gate_latency_delta_ms`。

## Verification
- `build`: `powershell -File scripts/verify-kit.ps1` -> `PASS`
- `test`: `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> `Passed: 146 Failed: 0`
- `contract/invariant`:
  - `powershell -File scripts/validate-config.ps1` -> `PASS`
  - `powershell -File scripts/verify.ps1` -> `Verify done. ok=324 fail=0`
- `hotspot`: `powershell -File scripts/doctor.ps1` -> `HEALTH=GREEN`
- 已知非阻断提示：
  - `verify-kit` 输出 `_common` baseline mapping violations，但 `actionable_violation_count=0`
  - `verify.ps1` 输出 `metrics-auto.md` 缺失与 `token_efficiency_trend.status=missing_metric`，当前为既有 advisory，不是本次文档变更引入

## Risks
- 规划文档可能与后续实现脱节。  
  - 缓解：已补 implementation plan 作为执行桥梁。
- 与现有 `ai-self-evolution` 文档边界仍可能被误读。  
  - 缓解：在新文档中明确“runtime governance”只补运行态，不替代现有演进/技能治理主线。

## Rollback
- 删除新增文档文件即可回退本次规划层变更。
- 若未来实现层落地失败，仍使用 `scripts/restore.ps1 + backups/<timestamp>/`。

## issue_id / clarification_mode
- `issue_id`: `agent-runtime-planning-20260414`
- `attempt_count`: `0`
- `clarification_mode`: `direct_fix`
- `clarification_scenario`: `plan`
- `clarification_questions`: `[]`
- `clarification_answers`: `[]`

## learning_points_3
- `agent runtime` 需要独立于安全/供应链/技能演进的治理主线，否则会分散进多个策略文件。
- `prompt / tool / memory / eval / trace / cost` 最适合以“统一策略源 + 现有门禁聚合”的方式落地。
- 规划先行能减少后续出现平行 prompt 策略、平行 memory 规则、平行工具审批表。

## reusable_checklist
- 是否定义了与既有治理计划的边界
- 是否保留固定门禁顺序
- 是否说明 observe -> enforce 的进入条件
- 是否给出可执行 backlog 与实施计划

## open_questions
- `prompt_registry` 最终是否独立成单独配置文件
- runtime cost 指标在 Q2 是否先局部纳入 recurring review
