# 20260414 Claude 兼容优化（P0-P3）执行证据

- 规则 ID: claude-code-compatibility-20260414
- 风险等级: 中
- 执行模式: direct_fix
- issue_id: claude-compatibility-20260414
- attempt_count: 1
- clarification_mode: direct_fix
- clarification_scenario: N/A
- clarification_questions: []
- clarification_answers: []

## 1) 任务理解快照
- 目标: 在不破坏现有 Codex-first 能力下，完成 Claude Code 兼容优化的可执行闭环。
- 非目标: 不重写全仓治理脚本；不移除现有 `codex-*` 兼容入口。
- 验收标准: `build -> test -> contract/invariant -> hotspot` 全通过，且新增兼容层有测试覆盖。
- 关键假设:
  - 已确认: 三平台规则与分发链路已存在（AGENTS/CLAUDE/GEMINI）。
  - 未确认: 目标仓中的 Claude CLI 版本长期稳定且参数不漂移。

## 2) 依据（Why）
- 计划文档: `docs/governance/claude-code-compatibility-plan-20260414.md`
- 现状证据:
  - 项目级 `AGENTS.md` 与 `CLAUDE.md` 同构，仅 B 段平台差异。
  - `config/targets.json` 已包含 `.claude/CLAUDE.md` 与项目级 `CLAUDE.md` 分发映射。

## 3) 变更清单（What）
- 测试出口修复:
  - `tests/repo-governance-hub.optimization.tests.ps1`
  - 增加自调用 `Invoke-Pester -PassThru` 出口控制，确保失败用例返回非 0。
  - 修复历史失败用例中的空数组 targets 写入方式（明确写入 `[]`）。
- 运行时策略兼容层:
  - 新增 `config/agent-runtime-policy.json`（中性命名）。
  - 新增 `scripts/set-agent-runtime-policy.ps1`（兼容入口，复用现有逻辑）。
  - `scripts/lib/common.ps1` 新增 `Resolve-AgentRuntimePolicyPath`，优先 `agent-runtime-policy.json`，回退 `codex-runtime-policy.json`。
  - `scripts/status.ps1`、`scripts/validate-config.ps1`、`scripts/set-codex-runtime-policy.ps1` 接入上述解析逻辑。
  - `scripts/verify-kit.ps1` 增加新文件存在性检查。
- 测试补充:
  - 增加 `Resolve-AgentRuntimePolicyPath` 优先级测试。
  - 增加 `set-agent-runtime-policy` 行为测试。

## 4) 执行命令与关键输出（Evidence）
- `powershell -File scripts/verify-kit.ps1`
  - 结果: 通过（`repo-governance-hub integrity OK`）
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - 结果: 通过（`Passed: 139 Failed: 0`）
- `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
  - 结果: 通过（`Config validation passed`，`Verify done. ok=311 fail=0`）
- `powershell -File scripts/doctor.ps1`
  - 结果: 通过（`HEALTH=GREEN`）
- `codex --version`
  - 关键输出: `codex-cli 0.120.0`
- `codex --help`
  - 关键输出: 含 `exec/review/mcp/sandbox/cloud/app-server/features`
- `codex status`
  - 结果: 非交互失败 `stdin is not a terminal`
- `claude --version`
  - 关键输出: `2.1.104 (Claude Code)`
- `claude --help`
  - 关键输出: 含 `doctor/mcp/plugin/agents/--permission-mode/--worktree/-p`
- `powershell -File scripts/check-cli-capabilities.ps1 -AsJson`
  - 结果: `status=WARN`（仅 codex status 非交互场景）

## 5) platform_na / gate_na 记录
- platform_na:
  - reason: `codex status failed: Error: stdin is not a terminal`
  - alternative_verification: `codex --version` + `codex --help`
  - evidence_link: `scripts/check-cli-capabilities.ps1 runtime output`
  - expires_at: `N/A`
- gate_na:
  - N/A（本轮执行了完整硬门禁链）

## 6) 可观测信号与排障路径
- 现象: 历史上存在“测试日志失败但进程返回 0”。
- 假设: 测试文件未显式用 `Invoke-Pester -PassThru` 统一退出码。
- 验证命令: 直接运行 `tests/repo-governance-hub.optimization.tests.ps1`。
- 预期结果: 失败时非 0，通过时 0。
- 实际结果: 本轮通过，`Passed: 139 Failed: 0`，退出码 0。

## 7) 兼容窗口与回滚
- 兼容策略: `agent-runtime-policy` 优先，`codex-runtime-policy` 回退（observe 阶段）。
- 回滚动作:
  1. `git restore scripts/lib/common.ps1 scripts/status.ps1 scripts/validate-config.ps1 scripts/set-codex-runtime-policy.ps1 scripts/verify-kit.ps1 tests/repo-governance-hub.optimization.tests.ps1`
  2. 删除新增文件:
     - `config/agent-runtime-policy.json`
     - `scripts/set-agent-runtime-policy.ps1`
     - `docs/change-evidence/20260414-claude-compatibility-phase0-p3.md`
  3. 重跑门禁链确认回滚后健康。

## 8) 术语解释点
- `platform_na`: 平台能力或命令在当前执行上下文不可用，不代表规则失效；需记录替代验证证据。
- `compatibility window (observe -> enforce)`: 先兼容双路径运行并观测，再切到强制单路径，降低迁移风险。

## 9) 未确认假设与纠偏结论
- 未确认: `claude` CLI 参数未来版本稳定性。
- 纠偏: 已通过 `--help` 动态探测能力，不依赖硬编码子命令存在性。

## 10) learning_points_3
- 测试套件必须由统一 runner 控制退出码，否则会出现“假通过”。
- 命名中性化不应破坏现有下游契约，优先“新增+回退”而不是“直接替换”。
- CLI 能力探测要坚持“先探测后调用”，可显著降低跨版本脆弱性。

## 11) reusable_checklist
- 新增策略文件时同步:
  - `common` 路径解析
  - `status/validate/verify-kit` 接线
  - 回归测试补点
  - 证据文档落地

## 12) open_questions
- 是否在下一轮将 `codex_runtime` JSON 输出字段升级为中性字段并保留兼容别名？
- 是否将 `set-codex-runtime-policy.ps1` 标记为 deprecate（保留兼容窗口）？
