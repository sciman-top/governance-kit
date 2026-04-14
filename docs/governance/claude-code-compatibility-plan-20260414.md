# Claude Code 兼容优化计划（2026-04-14）

## 1. 任务理解快照
- 目标：在不破坏现有 Codex-first 能力的前提下，将仓库治理能力优化为稳定兼容 Claude Code。
- 非目标：不重写全部治理脚本；不一次性替换所有 `codex-*` 命名；不改变现有硬门禁顺序与阻断语义。
- 验收标准：
  - 三平台规则（AGENTS/CLAUDE/GEMINI）继续同构，平台差异仅在 B 段。
  - `build -> test -> contract/invariant -> hotspot` 全链通过。
  - 新增 Claude 兼容能力有自动化验证与失败回退证据。
- 关键假设：
  - 已确认：当前 `targets.json` 已具备 CLAUDE 分发链路。
  - 未确认：本地 `claude` CLI 在所有目标环境均可用且参数稳定。

## 2. 影响面清单
- 规则：`AGENTS.md`、`CLAUDE.md`、`source/global/*`、`source/project/*`。
- 配置：`config/project-rule-policy.json`、`config/targets.json`、`config/*runtime-policy*.json`。
- 脚本：`scripts/check-cli-capabilities.ps1`、`scripts/validate-config.ps1`、`scripts/verify-kit.ps1`、`scripts/lib/common.ps1`。
- 测试：`tests/repo-governance-hub.optimization.tests.ps1` 及相关 fixture。
- 文档与证据：`docs/governance/*`、`docs/change-evidence/*`。

## 3. 分阶段任务（P0 -> P3）

### P0 基线冻结（低风险）
- [x] 记录当前基线（规则版本、关键脚本入口、门禁输出摘要）。
- [x] 补一份迁移前证据：为什么改、改动边界、回滚入口。
- [x] 明确 `platform_na` 字段模板在 Claude 场景的落证口径。
- DoD：
  - 产出基线证据文档，包含执行命令与关键输出。

### P1 配置与命名去 Codex 偏置（中风险）
- [x] 新增中性 runtime policy（建议 `agent-runtime-policy`），保留 `codex-runtime-policy` 兼容读取窗口。
- [x] 修改脚本为“优先新配置，回退旧配置”，避免一次性断裂。
- [x] 更新配置校验脚本与 JSON contract 断言。
- DoD：
  - 新旧配置都可通过 `validate-config + verify`。
  - 兼容窗口策略在文档中声明 `observe -> enforce`。

### P2 Claude 能力探测与回退闭环（中风险）
- [x] 在 CLI 能力探测中加入 `claude --version/--help` 与 feature probe（先探测后调用）。
- [x] 统一 `platform_na` 记录输出结构（reason/alternative/evidence/expires_at）。
- [x] 增补 Claude 特有失败回退用例（命令缺失、参数不支持、非交互限制）。
- DoD：
  - 能力探测脚本可输出 Claude 报告且不影响 Codex 结果。
  - 对 `platform_na` 有测试覆盖。

### P3 测试与发布护栏收敛（中高风险）
- [x] 修正测试执行出口：存在失败用例时必须返回非 0（避免“日志失败但进程成功”）。
- [x] 增加兼容迁移回归组（最小 smoke + 高风险路径 full）。
- [x] 先在 `repo-governance-hub` 自仓试点，再扩散到 `ClassroomToolkit`/`skills-manager`。
- DoD：
  - 回归矩阵通过；失败可被 CI 正确阻断。
  - 完成试点证据与回滚演练记录。

## 4. 验收门禁（固定顺序）
- build：`powershell -File scripts/verify-kit.ps1`
- test：`powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- contract/invariant：`powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
- hotspot：`powershell -File scripts/doctor.ps1`

> 顺序不可变：`build -> test -> contract/invariant -> hotspot`

## 5. 风险与回滚
- 风险1：脚本读取新旧 policy 时出现分支漂移。
  - 回滚：切回旧 policy 读取路径，保留新配置但不启用 enforce。
- 风险2：Claude CLI 参数差异导致误报失败。
  - 回滚：能力探测降级为 `--version + --help`，其余标记 `platform_na`。
- 风险3：测试出口收紧后暴露历史“假通过”。
  - 回滚：临时 observe 窗口，允许告警但不阻断；设置过期时间后 enforce。

## 6. 任务清单（执行顺序）
1. P0 基线冻结与迁移证据建立。
2. P1 配置兼容层（先加不删）。
3. P2 Claude 探测与 `platform_na` 标准化。
4. P3 测试出口修复与回归矩阵收敛。
5. 全链路门禁复验并沉淀证据。

## 7. 证据产出要求
- 目录：`docs/change-evidence/`
- 建议命名：`20260414-claude-compatibility-phaseX.md`
- 最低字段：依据、命令、关键输出、回滚动作、未确认假设、纠偏结论、learning_points_3、reusable_checklist。
