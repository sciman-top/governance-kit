# 2026-04-14 Phase4 SliceB - Cross Repo Feedback Ingestion

rule_id=phase4.cross_repo_feedback_ingestion
risk_level=medium
issue_id=phase4-cross-repo-feedback-sliceB
attempt_count=1
clarification_mode=direct_fix
clarification_scenario=N/A
clarification_questions=[]
clarification_answers=[]

## Task Snapshot
- 目标：打通“跨仓反馈报告 + 周检计数摄取”，覆盖本仓与目标仓治理演进闭环。
- 非目标：不改变硬门禁顺序；不提升任何新阻断阈值。
- 验收标准：
  - 新增 cross-repo feedback checker。
  - `run-recurring-review` 输出 `cross_repo_feedback_*` 关键字段。
  - 生成最新反馈报告与 machine-readable signal。
- 关键假设：
  - `E:/CODE/ClassroomToolkit`、`E:/CODE/skills-manager` 在当前环境可能缺失（未确认）。

## Changes
- 新增：`scripts/governance/check-cross-repo-feedback.ps1`
- 更新：`scripts/governance/run-recurring-review.ps1`
- 更新：`config/project-custom-files.json`（repo-governance-hub files 增加 `check-cross-repo-feedback.ps1`）
- 回灌：
  - `source/project/repo-governance-hub/custom/scripts/governance/check-cross-repo-feedback.ps1`
  - `source/project/_common/custom/scripts/governance/run-recurring-review.ps1`
  - `source/project/repo-governance-hub/custom/scripts/governance/run-recurring-review.ps1`
  - `source/project/ClassroomToolkit/custom/scripts/governance/run-recurring-review.ps1`
- 文档：
  - `docs/governance/cross-repo-feedback-report-latest.md`
  - `docs/governance/rule-index.md`
  - `docs/governance/full-control-plane-governance-optimization-plan-2026Q2.md`

## Commands
- `powershell -File scripts/governance/check-cross-repo-feedback.ps1 -RepoRoot . -AsJson`
- `powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson`
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1`
- `powershell -File scripts/governance/check-tracked-files.ps1 -Scope pending -AsJson`

## Key Output
- cross_repo_feedback:
  - `status=alert`
  - `feedback_ingested_count=3`
  - `repo_failure_count=2`
  - `rollout_matrix_missing_control_count=0`
  - `rollout_matrix_missing_repo_state_count=0`
- recurring review 新摘要字段：
  - `cross_repo_feedback_status=alert`
  - `cross_repo_feedback_ingested_count=3`
  - `cross_repo_feedback_repo_failure_count=2`
  - `cross_repo_feedback_rollout_matrix_gap_count=0`
  - `cross_repo_feedback_report_path=E:/CODE/repo-governance-hub/docs/governance/cross-repo-feedback-report-latest.md`
- 门禁结果：
  - `build(verify-kit)=FAIL`（外部目标仓路径缺失触发）
  - `test=142 passed / 4 failed`（与既有基线一致，非本次改动引入）
  - `contract/invariant: validate-config=PASS, verify=FAIL`（目标仓缺失）
  - `hotspot(doctor)=RED`（依赖 verify-kit/verify 失败）

## N/A / Platform
- platform_na.reason=目标仓路径缺失（`E:/CODE/ClassroomToolkit`、`E:/CODE/skills-manager`）导致 cross-repo 校验与 verify-kit/verify/doctor 失败。
- platform_na.alternative_verification=本仓脚本级验证通过（新增脚本单跑 + recurring review 字段回填 + config 校验通过）。
- platform_na.evidence_link=docs/change-evidence/20260414-phase4-cross-repo-feedback-sliceB.md
- platform_na.expires_at=2026-04-21

## Observable Signals
- `docs/governance/cross-repo-feedback-report-latest.md` 实时刷新。
- `.governance/cross-repo-feedback-signal.json` 实时刷新。
- `docs/governance/alerts-latest.md` 包含 `cross_repo_feedback_*` 字段。

## Troubleshooting Path
1. 先验证 `check-cross-repo-feedback` 单跑输出。
2. 再验证 `run-recurring-review -AsJson` 是否包含新增字段。
3. 最后按固定门禁顺序执行并记录外部依赖失败分流。

## Rollback
- 回滚入口：`scripts/restore.ps1` + `backups/<timestamp>/`
- 最小回滚动作：
  - 还原新增脚本 `check-cross-repo-feedback.ps1`
  - 还原 `run-recurring-review.ps1` 与对应 `source/project/*/custom` 回灌副本
  - 还原 `config/project-custom-files.json` 中新增路径

## Terminology
- `cross_repo_feedback_ingested_count`：已摄取到反馈汇总流程的目标仓数量（本仓示例=3）。
- 常见误解：它不是“全部通过数量”，通过数量由 `compatible_repo_count`/`repo_failure_count` 共同表达。

## Assumptions And Corrections
- 未确认假设：外部仓缺失是否为长期状态。
- 纠偏结论：在外部仓不可用时保持 `alert + platform_na` 留痕，不下调硬门禁语义。

learning_points_3:
- 反馈计数应独立字段化，避免只看兼容状态字符串。
- 周检摘要与报告路径联动，降低跨文件追溯成本。
- 失败场景必须提供可复跑的最小验证命令。

reusable_checklist:
- 新增控制必须同步：执行脚本 + 周检摘要 + 证据模板 + 分发映射。
- `source/project/*/custom` 回灌与根脚本保持同版本。
- 提交前固定执行 tracked-files policy 检查。

open_questions:
- 是否在 `check-update-triggers` 增加 `cross_repo_feedback_snapshot_stale` 触发器？
- 是否需要把 `cross_repo_feedback` 纳入月检趋势图字段？
