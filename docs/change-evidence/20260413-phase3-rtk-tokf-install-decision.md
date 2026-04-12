# 20260413 Phase3 RTK/tokf Install Decision

## task_snapshot
- goal: 回答并收口“是否需要安装 RTK/tokf”在本计划中的落地决策。
- non_goal: 本次不强制引入新的系统依赖。

## runtime_check
- command: `Get-Command rtk -ErrorAction SilentlyContinue`
- command: `Get-Command tokf -ErrorAction SilentlyContinue`
- result:
  - `rtk_installed=False`
  - `tokf_installed=False`

## decision
- 当前阶段结论：**不作为硬依赖强制安装**。
- 原因：
  1. 现有 PowerShell fallback 已可满足 Phase3 试点目标。
  2. 当前门禁与质量指标保持绿色，无证据显示必须立即引入新二进制工具。
- 触发安装条件（任一满足）：
  - fallback 在回放样本中出现关键信息缺失。
  - token 输出成本连续 2 个周检周期不达标。

## rollout_if_triggered
1. 先安装单工具试点（优先 `tokf`）。
2. 仅 advisory 模式运行一个周期。
3. 通过 `first_pass_rate/rework_rate/token_per_effective_conclusion` 对照后再决定 enforce。

## governance_fields
- issue_id: phase3-rtk-tokf-install-decision
- attempt_count: 1
- clarification_mode: direct_fix
- risk_level: low
