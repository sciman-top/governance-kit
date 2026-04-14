# 2026-04-14 Phase4 SliceC - Feedback Snapshot Trigger + Monthly Ingestion

rule_id=phase4.cross_repo_feedback_snapshot_trigger
risk_level=medium
issue_id=phase4-cross-repo-feedback-sliceC
attempt_count=1
clarification_mode=direct_fix
clarification_scenario=N/A
clarification_questions=[]
clarification_answers=[]

## Task Snapshot
- 目标：把 cross-repo feedback 从“周检摘要”进一步接入“更新触发器 + 月检报告”。
- 非目标：不改变硬门禁链路，不变更跨仓兼容判定阈值。
- 验收标准：
  - `config/update-trigger-policy.json` 增加 `cross_repo_feedback_snapshot_stale`。
  - `check-update-triggers.ps1` 增加报告时效与摄取计数检查。
  - `run-monthly-policy-review.ps1` 输出 `cross_repo_feedback_*` 字段。

## Changes
- 配置：`config/update-trigger-policy.json`
- 脚本：
  - `scripts/governance/check-update-triggers.ps1`
  - `scripts/governance/run-monthly-policy-review.ps1`
- 分发回灌：
  - `source/project/_common/custom/scripts/governance/check-update-triggers.ps1`
  - `source/project/repo-governance-hub/custom/scripts/governance/check-update-triggers.ps1`
  - `source/project/ClassroomToolkit/custom/scripts/governance/check-update-triggers.ps1`
  - `source/project/_common/custom/scripts/governance/run-monthly-policy-review.ps1`
  - `source/project/repo-governance-hub/custom/scripts/governance/run-monthly-policy-review.ps1`
  - `source/project/ClassroomToolkit/custom/scripts/governance/run-monthly-policy-review.ps1`
- 文档：`docs/governance/full-control-plane-governance-optimization-plan-2026Q2.md`

## Commands
- `powershell -File scripts/governance/check-update-triggers.ps1 -RepoRoot . -AsJson`
- `powershell -File scripts/governance/run-monthly-policy-review.ps1 -RepoRoot . -Period 2026-04 -AsJson`

## Key Output
- update trigger:
  - `cross_repo_feedback_snapshot_stale_count=0`
  - 新 step：`cross-repo-feedback-snapshot-stale`
- monthly review:
  - `status=ALERT`（继承周检当前告警状态）
  - 输出文件：`docs/governance/reviews/2026-04-monthly-review.md`
  - 已写入 `cross_repo_feedback_*` 字段用于月度追踪。

## N/A / Platform
- platform_na.reason=外部目标仓路径缺失导致周检与兼容项持续告警；本切片只增强触发器与报告口径。
- platform_na.alternative_verification=通过 `check-update-triggers` 与 `run-monthly-policy-review` 的 JSON 输出验证字段落地。
- platform_na.evidence_link=docs/change-evidence/20260414-phase4-cross-repo-feedback-sliceC.md
- platform_na.expires_at=2026-04-21

## Rollback
- 回滚入口：`scripts/restore.ps1` + `backups/<timestamp>/`
- 最小回滚动作：还原上述 8 个脚本/配置回灌文件与计划文档变更。

## Observable Signals
- `check-update-triggers` 返回 `cross_repo_feedback_snapshot_stale_count`。
- 月检文件出现 `cross_repo_feedback_status/ingested_count/repo_failure_count` 等字段。

learning_points_3:
- 报告时效触发器应同时检查“时间”和“最小摄取规模”。
- 月检入口复用周检 summary 字段可最小化脚本分叉。
- 跨仓反馈闭环需区分“信号缺失”与“信号告警”两类状态。

reusable_checklist:
- 新触发器落地必须同时更新：policy + check script + evidence。
- 月检字段扩展必须与周检 summary 字段名保持一致。
- 分发回灌文件需同步更新 3 个 source/project 目标。

open_questions:
- 是否将 `cross_repo_feedback_snapshot_stale` 纳入自动回滚触发策略？
