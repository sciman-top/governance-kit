# 20260415 Agent Runtime Task5 Doctor Runtime Summary

## Goal
- 为 `scripts/doctor.ps1` 增加 runtime readiness 摘要输出（`-AsJson`），并保持 observe 阶段非阻断。

## Task Snapshot
- 目标：在 doctor 输出中提供 runtime 就绪信号，供自动化消费。
- 非目标：修改既有 gate 阻断语义与阈值策略。
- 验收：测试新增断言通过，`doctor -AsJson` 出现 `runtime_readiness` 且 `health` 语义不变。
- 关键假设（已确认）：runtime readiness 在当前阶段允许 `YELLOW`，不应导致 doctor 直接失败。

## Rule / Risk
- rule_id: `agent-runtime-task5-doctor-summary-20260415`
- risk_level: `medium`
- clarification_mode: `direct_fix`

## Basis
- 计划文件：`docs/superpowers/plans/2026-04-14-agent-runtime-baseline.md`（Task 5）。
- 失败现象：新增测试期望 `runtime_readiness`，旧 doctor JSON 无该字段。

## Changes
- Updated `tests/repo-governance-hub.optimization.tests.ps1`
  - 扩展 `doctor supports AsJson output for machine consumption`：
    - 断言 `runtime_readiness` 存在
    - 断言 `status in {GREEN,YELLOW}`
    - 断言 `policy_present=true`、`metrics_present=false`（该夹具）
  - 修复夹具：补创建 `config` 目录与最小 `agent-runtime-policy.json`。
- Updated `scripts/doctor.ps1`
  - 新增 runtime readiness 探针：
    - `policy_present`: `config/agent-runtime-policy.json` 是否存在
    - `metrics_present`: `docs/governance/metrics-auto.md` 是否存在
    - 读取 `scripts/governance/check-agent-runtime-baseline.ps1 -AsJson`
  - 新增 `runtime_readiness` JSON 字段：
    - `status`、`policy_present`、`metrics_present`、`checker_status`、`checker_warning_count`、`probe_status`
  - 文本模式增加 runtime readiness 摘要行。

## Commands
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/doctor.ps1 -AsJson`

## Verification
- 失败测试阶段：`doctor supports AsJson output for machine consumption` 先失败（缺少 `runtime_readiness`）。
- 修复后：
  - `tests`: `Passed: 149 Failed: 0`
  - `doctor -AsJson`:
    - `health=GREEN`
    - `runtime_readiness.status=GREEN`
    - `runtime_readiness.policy_present=true`
    - `runtime_readiness.metrics_present=true`
    - `runtime_readiness.checker_status=PASS`
    - `runtime_readiness.probe_status=ok`

## Observability Signals
- `doctor -AsJson` 新增 `runtime_readiness` 节点，可直接被外部流水线解析。
- 文本模式新增 `runtime_readiness_status/runtime_policy_present/runtime_metrics_present` 等键值行。

## Troubleshooting Path
- 现象：新增断言失败（字段缺失）。
- 假设：doctor 未输出 runtime readiness。
- 验证：运行全量测试定位到单一用例失败。
- 修复：doctor 加探针 + JSON 字段；再次测试发现夹具路径错误（未建 `config` 目录），修夹具后通过。

## Terminology
- runtime readiness：运行时治理“是否具备最小可观测条件”的汇总状态。
- probe_status：doctor 对 runtime checker 探针执行状态（`ok/parse_failed/probe_failed/checker_missing`）。
- observe phase：只观测不阻断，先收集稳定信号再升级 enforce。

## Unconfirmed Assumptions And Corrections
- 未确认：`checker_warning_count` 是否未来需要进入 `health` 主判定。
- 当前结论：仅暴露，不纳入阻断；后续按 observe 数据决定是否提级。

## Rollback
- `git restore scripts/doctor.ps1 tests/repo-governance-hub.optimization.tests.ps1`
- 或 `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## issue_id / attempts
- issue_id: `agent-runtime-task5-20260415`
- attempt_count: `1`
- clarification_scenario: `bugfix`
- clarification_questions: `[]`
- clarification_answers: `[]`

## learning_points_3
- 先让测试失败再改实现，能确认改动是“需求驱动”而非偶然通过。
- runtime readiness 采用“暴露信号不改阻断”可避免 observe 阶段误杀。
- 测试夹具中路径创建顺序是常见波动源，建议在写文件前显式建目录。

## reusable_checklist
- doctor JSON 新字段是否有明确 schema 和默认值
- 探针失败时是否回退到非阻断状态
- 测试是否覆盖字段存在与布尔语义
- 复验是否包含全量 tests + doctor JSON 实跑

## open_questions
- runtime readiness 何时进入 `doctor health` 主分级
- 是否将 `runtime_readiness` 同步到 `run-recurring-review` 聚合摘要
