issue_id=skill-lifecycle-phase1-3-20260412
规则ID=R1,R2,R3,R6,R8,E6
规则版本=repo-governance-hub AGENTS.md v3.85
当前落点=E:/CODE/repo-governance-hub/scripts/governance/*
目标归宿=source/project/_common/custom/scripts/governance/* + source/project/*/custom/scripts/governance/*
风险等级=medium
执行模式=direct_fix

任务理解快照=目标是在不影响既有分发链路的前提下，完成“不可重复创建技能”硬约束、registry v2 生命周期迁移、trigger-eval 周期闭环；非目标是改变既有门禁顺序与外层 AI 主流程。

变更摘要=
1) promote-skill-candidates：以 knownExistingFamilies(=registry+overrides) 判定是否已存在 family，overrides 命中时禁止 create，仅 optimize/skip，并写入 existing_family_detected_in_overrides。
2) 新增 migrate-skill-registry-v2.ps1：将 promotion-registry.json 从 schema 1.0 升级到 2.0 并补 lifecycle 字段。
3) 新增 .governance/skill-lifecycle-policy.json，并扩展 skill-promotion-policy lifecycle/merge/retire 字段。
4) run-recurring-review / run-monthly-policy-review / check-update-triggers 增加 trigger-eval summary 可观测字段与触发器（默认 enabled=false，避免无样本误报）。

术语解释点=
- family_signature：同类技能问题簇的稳定归一键，用于“同类合并”而非按单次 issue_signature 裂变创建。
- trigger-eval summary：触发评估汇总结果，记录 grouped_query_count、validation_pass_rate、false_trigger_rate 等指标，作为创建/优化决策证据。

可观测信号=
- scripts/governance/promote-skill-candidates.ps1 出现 knownExistingFamilies 与 reason code existing_family_detected_in_overrides。
- scripts/governance/run-recurring-review.ps1 summary 输出 skill_trigger_eval_status / skill_trigger_eval_exit_code。
- scripts/governance/check-update-triggers.ps1 输出 skill_trigger_eval_alert_count，并支持 skill_trigger_eval_summary_stale 触发器。

执行命令=
1) powershell -File scripts/governance/migrate-skill-registry-v2.ps1 -RepoRoot . -AsJson
2) powershell -File scripts/verify-kit.ps1
3) powershell -File tests/repo-governance-hub.optimization.tests.ps1
4) powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
5) powershell -File scripts/doctor.ps1

关键输出=
- migrate: schema_before=1.0 -> schema_after=2.0, count_before=1 -> count_after=1
- test: 新增 3 项用例通过
  - migrate-skill-registry-v2 upgrades schema and lifecycle fields
  - promote-skill-candidates forbids create when family already exists in overrides
  - check-update-triggers reports skill trigger eval summary stale when enabled and required
- verify: ok=238 fail=0
- doctor: HEALTH=GREEN

排障路径=
1) 先补齐 source/_common 与 repo/skills-manager/ClassroomToolkit 分发落点，避免 verify-targets 漂移失败。
2) 对 trigger-eval 告警从激进改为保守（默认关闭、仅在 enabled=true 且 require_trigger_eval_for_create=true 时生效）。
3) 通过新增测试固定行为，再跑全链路门禁确认无回归。

未确认假设与纠偏结论=
- 未确认假设：目标仓 trigger-eval 样本量短期内可能不足。
- 纠偏结论：将 skill_trigger_eval_summary_stale 默认置为 enabled=false；由策略显式开启后再严格门禁。

回滚动作=
1) git checkout -- scripts/governance/promote-skill-candidates.ps1 scripts/governance/check-update-triggers.ps1 scripts/governance/run-recurring-review.ps1 scripts/governance/run-monthly-policy-review.ps1 tests/repo-governance-hub.optimization.tests.ps1
2) git checkout -- .governance/skill-promotion-policy.json config/update-trigger-policy.json config/project-custom-files.json config/targets.json
3) git clean -f scripts/governance/migrate-skill-registry-v2.ps1 .governance/skill-lifecycle-policy.json
4) git checkout -- source/project/_common/custom source/project/repo-governance-hub/custom source/project/skills-manager/custom source/project/ClassroomToolkit/custom

learning_points_3=1) 去重主键必须使用 family 级别而不是 issue 级别 2) create 决策前必须联合 registry+overrides 双源判定 3) 周期告警策略要支持“默认保守、按策略升级”
reusable_checklist=迁移脚本->策略字段->分发映射->测试->build/test/contract/hotspot
open_questions=是否将 skill_trigger_eval_summary_stale 在 observe 窗口结束后默认切换 enabled=true（建议结合近30天样本量阈值）
