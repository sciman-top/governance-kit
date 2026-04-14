# 2026-04-14 Phase4 SliceD - Monthly Feedback Trend Delta

rule_id=phase4.cross_repo_feedback_monthly_trend_delta
risk_level=low
issue_id=phase4-cross-repo-feedback-sliceD
attempt_count=1
clarification_mode=direct_fix
clarification_scenario=N/A
clarification_questions=[]
clarification_answers=[]

## Task Snapshot
- 目标：完成计划剩余项，新增 cross-repo feedback 月趋势字段（MoM + instability）。
- 非目标：不调整硬门禁顺序，不提升 `cross_repo_feedback_snapshot_stale` 为高风险阻断。
- 验收标准：
  - 月检脚本输出 `cross_repo_feedback_mom_delta` 与 `cross_repo_feedback_instability_score`。
  - 指标模板补齐对应字段。
  - 计划进度将 slice D 标记为 completed。

## Changes
- 更新：`scripts/governance/run-monthly-policy-review.ps1`
  - 新增上月 period 解析与 key/value 读取。
  - 新增 `cross_repo_feedback_mom_delta`。
  - 新增 `cross_repo_feedback_instability_score`。
- 更新：`docs/governance/metrics-template.md`
  - 新增 `cross_repo_feedback_mom_delta=`
  - 新增 `cross_repo_feedback_instability_score=`
- 更新：`docs/governance/full-control-plane-governance-optimization-plan-2026Q2.md`
  - `Phase 4 slice D` 标记完成，`next` 收口为“再积累一个月样本后复评阈值”。
- 回灌：
  - `source/project/_common/custom/scripts/governance/run-monthly-policy-review.ps1`
  - `source/project/repo-governance-hub/custom/scripts/governance/run-monthly-policy-review.ps1`
  - `source/project/ClassroomToolkit/custom/scripts/governance/run-monthly-policy-review.ps1`

## Commands
- `powershell -File scripts/governance/run-monthly-policy-review.ps1 -RepoRoot . -Period 2026-04 -AsJson`

## Key Output
- monthly review result:
  - `status=ALERT`
  - `cross_repo_feedback_mom_delta=N/A`
  - `cross_repo_feedback_instability_score=N/A`
- 说明：当前仓仅存在单月样本，MoM 与 instability 未形成可比基线。

## N/A / Platform
- platform_na.reason=外部目标仓路径缺失导致 recurring review 仍为 ALERT（非本切片引入）。
- platform_na.alternative_verification=月检 JSON 已稳定返回新增趋势字段。
- platform_na.evidence_link=docs/change-evidence/20260414-phase4-cross-repo-feedback-sliceD.md
- platform_na.expires_at=2026-04-21

## Rollback
- 回滚入口：`scripts/restore.ps1` + `backups/<timestamp>/`
- 最小回滚动作：
  - 还原 `run-monthly-policy-review.ps1` 与 3 份 source 回灌副本。
  - 还原 `metrics-template.md` 与计划文档变更。

learning_points_3:
- 月趋势字段应在脚本层计算，避免人工维护偏差。
- 单月样本场景必须显式输出 `N/A`，禁止伪造趋势。
- 风险等级提升应以样本充分性为前置条件。

reusable_checklist:
- 新增趋势指标必须同步模板字段与月检输出。
- 计划状态变更要与代码落地同步提交。
- 提交前清理运行时信号文件的纯时间戳噪音。

open_questions:
- 是否在 `2026-05` 月报产生后自动触发“阈值上调复评”检查？
