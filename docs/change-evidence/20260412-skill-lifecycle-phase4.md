issue_id=skill-lifecycle-phase4-20260412
当前落点=E:/CODE/repo-governance-hub/scripts/governance/run-skill-lifecycle-review.ps1
目标归宿=source/project/_common/custom/scripts/governance/run-skill-lifecycle-review.ps1 + 目标仓 scripts/governance/run-skill-lifecycle-review.ps1
风险等级=medium
执行模式=direct_fix

任务理解快照=在已完成 create/optimize 去重与 trigger-eval 闭环后，补齐 merge/retire 生命周期执行器，并将其接入 recurring/monthly 可观测链路。

变更摘要=
1) 新增 run-skill-lifecycle-review.ps1，支持 Mode=plan|safe：
   - merge：按 family_signature token Jaccard 相似度 + 阈值筛选；
   - retire：按 inactive_days + min_invocations 判定；
   - safe 模式回写 registry（deprecated/retired 状态与时间字段）。
2) run-recurring-review 接入 skill lifecycle step，输出：
   - skill_lifecycle_status
   - skill_lifecycle_merge_candidate_count
   - skill_lifecycle_retire_candidate_count
3) run-monthly-policy-review 增加 lifecycle 指标行与 next action 文案。
4) project-custom-files 增加分发条目 scripts/governance/run-skill-lifecycle-review.ps1，并刷新 targets。

执行命令=
1) powershell -File scripts/governance/run-skill-lifecycle-review.ps1 -RepoRoot . -Mode plan -AsJson
2) powershell -File scripts/refresh-targets.ps1 -Mode safe
3) powershell -File tests/repo-governance-hub.optimization.tests.ps1
4) powershell -File scripts/install.ps1 -Mode safe

关键输出=
- 新增测试通过：
  - run-skill-lifecycle-review plan reports merge and retire candidates
  - run-skill-lifecycle-review safe applies merge and retire to registry
- install 后 verify 汇总：ok=241 fail=0
- doctor: HEALTH=GREEN

回滚动作=
1) git checkout -- scripts/governance/run-skill-lifecycle-review.ps1 scripts/governance/run-recurring-review.ps1 scripts/governance/run-monthly-policy-review.ps1
2) git checkout -- source/project/_common/custom/scripts/governance/run-skill-lifecycle-review.ps1 source/project/_common/custom/scripts/governance/run-recurring-review.ps1 source/project/_common/custom/scripts/governance/run-monthly-policy-review.ps1
3) git checkout -- config/project-custom-files.json config/targets.json tests/repo-governance-hub.optimization.tests.ps1
4) git clean -f docs/change-evidence/20260412-skill-lifecycle-phase4.md

learning_points_3=1) lifecycle 执行器默认 plan，再按 evidence 切 safe 更稳健 2) Generic List 在 Windows PowerShell 迭代需要显式 ToArray 3) registry 字段需兼容缺省夹具（先补字段再赋值）
reusable_checklist=lifecycle脚本->source同步->分发映射->刷新targets->测试->install全链路
open_questions=是否在 recurring 周期中引入“仅告警不自动 safe”与“满足阈值后自动 safe”两档策略
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
