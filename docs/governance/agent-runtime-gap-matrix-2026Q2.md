# AI Agent Runtime Gap Matrix (2026 Q2)

更新时间：2026-04-14  
适用范围：`repo-governance-hub` 及其已纳管目标仓（当前重点：`repo-governance-hub`、`skills-manager`、`ClassroomToolkit`）  
状态：Draft v1（用于 `observe -> enforce` 迁移前的差距收敛）

## 1. 目标与非目标
- 目标：为本仓补齐 `agent runtime` 治理基线，覆盖 `prompt / tool / context / memory / eval / trace / cost`。
- 目标：把 Anthropic、OpenAI、MCP、OTel 以及高质量社区项目中的共识做法，映射到本仓现有 `config + scripts + tests + docs + recurring review` 闭环。
- 目标：保持本仓既有四段硬门禁与证据链不变，不引入第二套平行治理系统。
- 非目标：不在 2026 Q2 一次性引入完整代理框架、外部托管平台或持久化记忆服务。
- 非目标：不把 prompt 优化、记忆存储、工具契约直接升级为默认阻断项。

## 2. 为什么要单列一条 `agent runtime` 主线
- 本仓现有计划已较强覆盖：规则分发、硬门禁、供应链、安全基线、实践栈、技能生命周期。
- 当前仍偏弱的区域：运行态状态管理、工具调用契约、prompt 资产版本化、agent eval、GenAI trace 语义、成本闭环。
- 如果不单列主线，后续很容易出现：
  - 在多个策略文件中重复定义 token/cost/prompt 规则。
  - 只有“经验型优化”，缺少可对比、可回滚、可观测的运行时基线。
  - 跨 Codex / Claude / Cline / MCP 的抽象层次不一致。

## 3. 外部参考分层

### 3.1 官方参考（优先吸收）
- Anthropic：`prompt caching`、`tool use`、`hooks`、`context editing`、`token counting`、`test and evaluate`。
- OpenAI：`prompt caching`、`prompt engineering / optimizer`、`working with evals`、`conversation state`、`built-in tools`、`background mode`。
- MCP 官方：`tools / prompts / resources / roots / sampling` 的跨客户端统一语义。
- OpenTelemetry：GenAI 与 MCP semantic conventions，用于统一 trace 字段。

### 3.2 社区高价值项目（用于模式抽样，不直接照搬）
- `Langfuse`：prompt registry + trace + eval + cost 归集。
- `Promptfoo`：离线/CI eval、回归集、红队测试。
- `OpenLIT` / `OpenLLMetry`：OTel 原生 GenAI 观测模型。
- `PydanticAI`：typed agent dependencies / result schema / tool contract 设计。
- `OpenHands`：长流程 coding-agent 的执行、回放、失败恢复。
- 已纳入对标语境：`Aider`、`Cline`、`Mem0`、`Letta`。

## 4. 当前能力快照（2026-04-14）
- 已有：
  - `build -> test -> contract/invariant -> hotspot` 固定门禁。
  - `docs/change-evidence/` 证据链与 `scripts/restore.ps1` 回滚入口。
  - `clarification / proactive suggestion / tracked-files / subagent trigger / token efficiency` 等治理策略。
  - `ai-self-evolution`、`practice-stack`、`external-baseline-gap` 等规划文档。
- 缺口：
  - 没有独立的 `agent-runtime-policy.json` 作为运行时统一策略源。
  - 没有 `prompt registry` 和 `tool contract registry`。
  - 没有 `memory policy` 的最小治理边界。
  - `metrics-template / recurring review / doctor` 尚未统一纳入 agent 运行态 KPI。
  - `eval` 更偏技能触发与治理演进，尚未形成覆盖 prompt/tool/memory/runtime 的统一 agent eval 套件。

## 5. 差距矩阵
| 领域 | 外部参考共识 | 当前状态 | 差距判定 | 本仓落地动作 |
|---|---|---|---|---|
| Prompt 资产治理 | prompt 可版本化、可评测、可回滚 | 仅有零散 token/cost 文档与提示词经验 | 未达成 | 新增 `prompt registry` 策略与证据字段，建立 `prompt -> owner -> eval_set -> rollback` 映射 |
| Tool 契约治理 | tool schema、风险等级、重试/超时、审批边界 | 有风险分级与子代理策略，但无统一 tool registry | 部分达成 | 新增 `tool contract registry`，统一 `risk_class / timeout / retry / approval / trace attrs` |
| Context 管理 | 长会话 compaction/context editing/state 边界 | 已有 token 节省与 lite teaching，但缺少统一 context policy | 部分达成 | 新增 `context_management` 策略，记录 `compaction_count / truncation / cacheability` |
| Memory 治理 | session / durable / retrieval memory 分层 | 仅有技能/证据层沉淀，无 memory policy | 未达成 | 新增 `memory_policy`，定义 `allowed / forbidden / retention / audit` |
| Agent Eval | 任务成功定义、回归集、对抗集、CI 评测 | 技能触发评测已成形，runtime eval 未系统化 | 部分达成 | 扩展为 `smoke / regression / adversarial / cost` 四类 agent eval |
| Trace / Observability | GenAI spans + MCP semconv + cost/tokens | 有 evidence 和 recurring review，但 trace 字段不统一 | 部分达成 | 在 `metrics-template`、`doctor`、周期复盘中加入 OTel 风格字段 |
| Cost / Token | cache 命中、token 分布、单位成功成本 | 已有 token 轻量优化文档 | 部分达成 | 新增 `cache_hit_rate / token_per_success / cost_per_successful_run / tool_rounds_per_task` |
| Runtime State | background / async / long-running 会话管理 | 当前更偏同步治理脚本 | 未达成 | 先建立状态字段与审计要求，不急于引入运行时框架 |
| Human Approval Boundary | 高风险动作需显式边界 | 已有风险分级与 approval matrix | 达成（基础版） | 扩展到 tool/memory/runtime 维度，保持与现有矩阵对齐 |
| Replay / Recovery | 可重放失败、可比较前后版本 | 已有 failure replay 和 rollback drill | 达成（基础版） | 将 replay 样本扩展到 agent runtime 任务集 |

## 6. 建议的最小落地单元

### 6.1 策略层
- `config/agent-runtime-policy.json`
- 初始字段建议：
  - `prompt_registry`
  - `tool_contracts`
  - `context_management`
  - `memory_policy`
  - `agent_evals`
  - `agent_observability`
  - `cost_controls`
  - `observe_to_enforce`

### 6.2 脚本层
- `scripts/governance/check-agent-runtime-baseline.ps1`
- `scripts/governance/report-agent-runtime-readiness.ps1`
- 在 `run-recurring-review.ps1`、`doctor.ps1` 中聚合 runtime 指标

### 6.3 测试层
- `tests/` 增加 policy schema、metrics presence、observe/enforce gating 的回归测试

### 6.4 文档层
- `docs/governance/agent-runtime-*`
- `docs/change-evidence/` 增加统一 evidence 字段样例

## 7. 迁移建议（按风险排序）
1. 先上 `trace / eval / cost` 可观测层，不阻断。
2. 再上 `prompt registry / tool contracts / memory policy` 的结构化策略。
3. 最后从 `observe` 提升部分控制到 `enforce`，优先只提升“缺失即漂移”的静态检查。

## 8. 建议 KPI
- 质量：`agent_task_success_rate`、`first_pass_rate`
- 稳定性：`tool_error_rate`、`retry_rate`、`compaction_count`
- 成本：`average_input_tokens`、`average_output_tokens`、`cache_hit_rate`、`cost_per_successful_run`
- 治理：`policy_coverage_rate`、`eval_freshness_days`、`observe_to_enforce_promotion_count`

## 9. 风险与回滚
- 风险1：策略字段增多，导致 `doctor` 和周期报告噪音上升。  
  - 缓解：先 advisory，建立噪音预算。
- 风险2：引入 prompt/tool/memory 三套注册表，出现平行真相源。  
  - 缓解：统一由 `config/agent-runtime-policy.json` 承接入口，其他文档只解释、不重复定义。
- 风险3：过早要求 durable memory 或复杂状态机。  
  - 缓解：Q2 只定义治理边界，不强制接入外部 memory 平台。
- 回滚：撤回新增 runtime policy 与聚合脚本，恢复到现有 `practice-stack + self-evolution + token efficiency` 基线，重跑四段门禁。

## 10. 参考链接
- Anthropic MCP: https://docs.anthropic.com/en/docs/build-with-claude/mcp
- Anthropic Hooks: https://code.claude.com/docs/en/hooks
- Anthropic Prompt Caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Anthropic Tool Use: https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
- Anthropic Context Editing: https://platform.claude.com/docs/en/build-with-claude/context-editing
- Anthropic Token Counting: https://platform.claude.com/docs/en/build-with-claude/token-counting
- OpenAI API Docs: https://developers.openai.com/api/docs
- OpenAI Prompt Caching: https://developers.openai.com/api/docs/guides/prompt-caching
- OpenAI Working with Evals: https://developers.openai.com/api/docs/guides/evals
- MCP Client Concepts: https://modelcontextprotocol.io/docs/learn/client-concepts
- OpenTelemetry MCP SemConv: https://opentelemetry.io/docs/specs/semconv/gen-ai/mcp/
- Langfuse: https://github.com/langfuse/langfuse
- Promptfoo: https://github.com/promptfoo/promptfoo
- OpenLIT: https://github.com/openlit/openlit
- OpenLLMetry: https://github.com/traceloop/openllmetry
- PydanticAI: https://github.com/pydantic/pydantic-ai
- OpenHands: https://github.com/OpenHands/OpenHands
