# 20260415 Agent Runtime Task7 Pilot Observe Cycles

## Goal
- 定义 pilot 成功阈值并完成 3 轮 observe cycle 执行，输出可审计证据。

## Task Snapshot
- 目标：为 runtime promotion 建立“先观测再提级”的量化门槛。
- 非目标：本轮不执行 enforce promotion。
- 验收：3 轮 cycle 全部通过并形成结构化结果。

## Rule / Risk
- rule_id: `agent-runtime-task7-20260415`
- risk_level: `medium`
- clarification_mode: `direct_fix`

## Changes
- Updated `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`
  - 新增 `Pilot Success Thresholds (Observe Mode)`：
    - `false_positive_rate <= 5%`
    - `gate_latency_delta_ms <= +3000`
    - `policy_drift_count = 0`
    - `runtime_eval_pass_rate >= 95%`
- Updated `docs/governance/agent-runtime-backlog-2026Q2.md`
  - 在 `P2-02 Pilot Observe Cycles` 增加同口径阈值。
- Added `docs/change-evidence/20260415-agent-runtime-pilot-cycles.json`
  - 记录 3 轮 cycle 的每步退出码和耗时（`verify-kit -> tests -> validate-config`）。

## Commands
- 3 轮循环执行：
  - `powershell -File scripts/verify-kit.ps1`
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -File scripts/validate-config.ps1`
- 闭环复验：
  - `powershell -File scripts/verify.ps1`
  - `powershell -File scripts/doctor.ps1`

## Verification
- `20260415-agent-runtime-pilot-cycles.json`：
  - `cycles[1..3].ok = true`
  - `all_ok = true`
  - 三轮 `tests` 均 `exit_code=0`（约 201s / 203s / 201s）
- 最终门禁：
  - `verify`: `ok=324 fail=0`
  - `doctor`: `HEALTH=GREEN`
  - `runtime_readiness_status=GREEN`

## Observability Signals
- 周期证据文件：`docs/change-evidence/20260415-agent-runtime-pilot-cycles.json`
- 当前 runtime readiness：`policy_present=True`, `metrics_present=True`, `checker_status=PASS`

## Rollback
- `git restore docs/governance/agent-runtime-roadmap-2026Q2-Q3.md docs/governance/agent-runtime-backlog-2026Q2.md`
- `git clean -f docs/change-evidence/20260415-agent-runtime-pilot-cycles.json`

## learning_points_3
- 先定义阈值再跑循环，才能避免“结果可解释性不足”。
- 三轮重复执行对稳定性判断比单轮更有价值。
- 结构化 JSON 证据比纯日志更利于后续自动审计与晋升决策。

## reusable_checklist
- 阈值是否写入 roadmap + backlog 双文档
- cycle 是否至少 3 轮且步骤固定
- 每轮是否保存 exit_code 与 duration
- 最终是否补 `verify + doctor` 闭环

## open_questions
- `false_positive_rate` 与 `policy_drift_count` 的自动计算入口是否需要独立脚本
