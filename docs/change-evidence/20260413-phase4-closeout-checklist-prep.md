# 20260413 Phase4 Closeout Checklist Preparation

## task_snapshot
- goal: 在观察窗口结束前，预先固化 Phase4 收口标准与执行步骤，避免到期临时决策。
- non_goal: 本次不提前做推广/回滚最终判定。
- acceptance: 存在可执行的 closeout checklist，覆盖门禁命令、指标口径、决策矩阵与证据模板。

## changes
- 新增：`docs/governance/rule-layering-pilot-closeout-checklist.md`
  - 固化窗口边界：`2026-04-13 ~ 2026-04-27`
  - 固化 closeout 前置条件（hard gate + recurring review）
  - 固化三路决策矩阵：`promote / continue_observe / rollback`
  - 固化 closeout 命令链与证据模板
- 更新：`docs/governance/rule-layering-migration-plan.md`
  - 在 Phase4 状态下挂接 closeout checklist

## verification
- `powershell -File scripts/verify-kit.ps1` -> pass
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> pass
- `powershell -File scripts/validate-config.ps1` -> pass
- `powershell -File scripts/verify.ps1` -> pass
- `powershell -File scripts/doctor.ps1` -> pass

## risk_and_rollback
- risk_level: low
- risk: 文档阈值与后续策略更新可能产生偏差。
- rollback: `git restore docs/governance/rule-layering-pilot-closeout-checklist.md docs/governance/rule-layering-migration-plan.md`

## governance_fields
- issue_id: phase4-closeout-checklist-prep
- attempt_count: 1
- clarification_mode: direct_fix
- learning_points_3:
  1. 时间窗口型任务应先固化收口标准，再等待窗口结束。
  2. 决策矩阵能减少“到期临时拍板”的主观波动。
  3. closeout 证据模板可提升跨轮次可比性。
