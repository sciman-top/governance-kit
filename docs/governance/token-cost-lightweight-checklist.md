# Token Cost Lightweight Checklist (Codex/Claude)

## 目标
- 在不改变硬门禁与治理语义的前提下，降低常驻上下文与命令输出 token 成本。

## 本轮范围（轻量）
- 只做可快速回滚的改动：规则精简、输出过滤、会话管理、参数预算。
- 不做：大规模重写脚本、强制引入新系统依赖。

## 执行清单（先做这些）
- [x] `main rules` 保持短小：`AGENTS.md/CLAUDE.md/GEMINI.md` 仅保留核心协议与索引入口。
- [x] `渐进披露`：长流程迁移到 `docs/governance/*.md`，主规则只放“触发条件 + 文档/skill 入口”。
- [x] `skills 化`：将高频、可复用、流程型内容沉淀到 skills（避免每轮常驻注入）。
- [x] `输出过滤`：默认走现有 PowerShell fallback；仅在高噪声命令启用摘要模式。
- [x] `RTK/tokf` 暂不硬依赖：触发条件满足后再单工具试点（优先 `tokf`，先 advisory）。
- [x] `会话压缩`：长轨迹任务设置 compaction/clear 触发阈值（如反复返工、上下文过长）。
- [ ] `上下文缩减`：按任务启停 MCP，保持最小集合。（进行中：以会话运行时策略为主）
- [ ] `成本参数`：按任务等级统一 `reasoning effort + verbosity + max_output_tokens`。（进行中：平台运行时配置）

## 触发阈值（建议）
- `安装 tokf/RTK 触发`：输出 token 成本连续 2 个周检周期不达标，或回放出现关键信息漏失。
- `会话压缩触发`：同一 issue 连续返工 >= 2，或单会话明显出现“历史过长影响执行”。
- `升级到标准方案触发`：质量指标波动（一次通过率下降/返工率上升）时暂停扩展，仅保留核心节流项。

## 每周验证（最小）
- [x] 质量不退化：`first_pass_rate` 不低于基线，`rework_rate` 不高于基线。
- [x] 成本有效：`average_response_token`、`token_per_effective_conclusion` 趋势不变差。
- [x] 安全可观测：失败信息、阻断信号、回滚提示未被过滤丢失。

## 当前状态（2026-04-13）
- 已落地脚本：
  - `scripts/governance/invoke-output-filter-wrapper.ps1`
  - `scripts/governance/check-session-compaction-trigger.ps1`
  - `scripts/governance/run-recurring-review.ps1`（新增 compaction + 质量/成本并排摘要字段）
- 已落地策略：
  - `.governance/session-compaction-trigger-policy.json`
- 已通过本仓硬门禁顺序复验：
  - `build -> test -> contract/invariant -> hotspot`
- 尚需持续观察项（非阻断）：
  - `token_efficiency_trend` 仍处于 `insufficient_history`，需累积更多周检样本后判定趋势。

## 回滚
- 关闭输出过滤包装，回退到原始输出模式。
- 回退主规则到上个稳定提交，仅保留索引可用性。
- 撤销新增 hooks/代理集成，并记录证据到 `docs/change-evidence/`。

## 参考（官方与社区）
- OpenAI Prompt Caching: https://platform.openai.com/docs/guides/prompt-caching
- OpenAI Codex agent loop（含 AGENTS 加载与 compaction 细节）: https://openai.com/index/unrolling-the-codex-agent-loop/
- OpenAI GPT-5 guide（reasoning/verbosity）: https://developers.openai.com/api/docs/guides/latest-model
- Anthropic Prompt Caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Anthropic Claude Code Hooks: https://code.claude.com/docs/en/hooks-guide
- tokf: https://github.com/mpecan/tokf
- RTK: https://github.com/rtk-ai/rtk
