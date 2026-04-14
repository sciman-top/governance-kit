# 20260415 Agent Runtime Task4 Recurring Metrics

## Goal
- 完成 Task 4：将 runtime 指标纳入 recurring review 与 metrics 模板，并确保 source/target 一致后通过全链路门禁。

## Non-goal
- 不处理与 Task 4 无关的历史脏变更。
- 不调整 `run-recurring-review` 告警判定语义（仅扩展可观测字段）。

## Task Snapshot
- 目标：补齐 runtime 指标可观测性字段并进入周期巡检摘要。
- 非目标：改动跨仓告警阈值与升级策略。
- 验收标准：`build -> test -> contract/invariant -> hotspot` 全绿，且 `run-recurring-review -AsJson` 输出 runtime 字段。
- 关键假设（已确认）：runtime 字段缺失时允许输出 `N/A`，不改变阻断语义。

## Rule / Risk
- rule_id: `agent-runtime-task4-recurring-review-20260415`
- risk_level: `medium`
- 执行模式：`direct_fix`

## Basis
- 计划来源：`docs/superpowers/plans/2026-04-14-agent-runtime-baseline.md`
- 阻断根因：`scripts/governance/run-recurring-review.ps1` 已改但 `source/project/repo-governance-hub/custom/scripts/governance/run-recurring-review.ps1` 未同步，触发 `verify-targets` 漂移失败。

## Changes
- Updated `docs/governance/metrics-template.md`
  - 增加 runtime 指标项：`agent_task_success_rate`、`runtime_eval_pass_rate`、`cache_hit_rate`、`cost_per_successful_run`、`tool_error_rate`、`compaction_count` 等。
- Updated `scripts/governance/run-recurring-review.ps1`
  - 从 `metrics-auto.md` 读取 runtime 指标（缺失回退 `N/A`）。
  - 将 runtime 指标写入 `summary`、`alerts-latest.md` 与控制台输出。
- Updated `source/project/repo-governance-hub/custom/scripts/governance/run-recurring-review.ps1`
  - 回灌上述同源变更，恢复 source/target 一致性。
- Updated `tests/repo-governance-hub.optimization.tests.ps1`
  - 新增 runtime 指标读取用例。
  - 扩展 alert snapshot 用例，校验 runtime 字段默认 `N/A`。

## Commands
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1`
- `powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson`

## Verification
- `verify-kit`: PASS
- `tests`: `Passed: 149 Failed: 0`
- `validate-config`: PASS
- `verify`: `Verify done. ok=324 fail=0`
- `doctor`: `HEALTH=GREEN`
- `run-recurring-review -AsJson`: `summary` 已包含
  - `runtime_agent_task_success_rate`
  - `runtime_eval_pass_rate`
  - `runtime_cache_hit_rate`
  - `runtime_cost_per_successful_run`
  - `runtime_tool_error_rate`
  - `runtime_compaction_count`

## Observability Signals
- 告警快照：`docs/governance/alerts-latest.md` 已带 runtime 字段。
- 当前值：若 `metrics-auto.md` 未提供 runtime 键，则统一显示 `N/A`（行为符合预期）。

## Troubleshooting Path
- 现象：`verify` 报 `run-recurring-review.ps1` source/target mismatch。
- 假设：仅目标脚本改动，source of truth 未回灌。
- 验证：`git diff --no-index scripts/governance/run-recurring-review.ps1 source/project/repo-governance-hub/custom/scripts/governance/run-recurring-review.ps1`
- 纠偏：回灌同样变更到 `source/.../run-recurring-review.ps1` 后重跑门禁恢复全绿。

## Terminology
- runtime metric：运行时健康/成本指标，不等同于治理脚本 exit code。
- source/target drift：分发源文件与目标文件内容不一致，`verify-targets` 会阻断。
- recurring review：周期巡检入口，用于聚合质量与治理状态。

## Unconfirmed Assumptions And Corrections
- 未确认假设：runtime 指标值是否必须在所有仓都实时可得。
- 当前策略：不可得时回退 `N/A` 并保持 gate 语义不变，后续可按策略逐步从 observe 转 enforce。

## Rollback
- `git restore docs/governance/metrics-template.md scripts/governance/run-recurring-review.ps1 source/project/repo-governance-hub/custom/scripts/governance/run-recurring-review.ps1 tests/repo-governance-hub.optimization.tests.ps1`
- 或 `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## issue_id / clarification
- issue_id: `agent-runtime-task4-20260415`
- attempt_count: `1`
- clarification_mode: `direct_fix`
- clarification_scenario: `bugfix`
- clarification_questions: `[]`
- clarification_answers: `[]`

## learning_points_3
- runtime 指标扩展属于“可观测增强”，应先保持 `N/A` 回退，避免改变阻断语义。
- 本仓 custom 脚本变更必须同步 source，避免 `verify-targets` 漂移阻断。
- 长耗时脚本（tests/recurring-review）需显式提升超时阈值，避免误判为失败。

## reusable_checklist
- 目标脚本修改后是否已回灌 `source/project/.../custom/`
- `summary`、快照、控制台输出三处是否一致新增字段
- 用例是否覆盖“有值”和“无值回退 N/A”
- 四道门禁是否按顺序重跑并留证据

## open_questions
- runtime 指标何时从 `N/A tolerated` 进入强约束阈值校验
- 是否需要把 runtime 指标同步进入 `doctor -AsJson` 的固定结构
