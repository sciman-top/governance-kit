# 20260412 rule-layering-phase1-closeout

- 规则 ID=rule-layering-phase1-closeout
- 风险等级=low
- 目标归宿=`docs/governance/*` + `docs/change-evidence/*`
- 任务理解快照=目标:补齐 Phase1 文档分流缺口并明确计划完成状态；非目标:启动 Phase2 技能创建；验收:索引不再含 to-be-created 占位，清单状态可读
- 执行改动=
  - 新增 `docs/governance/evidence-and-rollback-runbook.md`
  - 新增 `docs/governance/backflow-runbook.md`
  - 新增 `docs/governance/git-scope-and-tracked-files.md`
  - 更新 `docs/governance/rule-index.md` 去除上述条目的 “to be created”
  - 更新 `docs/governance/rule-layering-inventory.md` 首波任务与验收勾选状态
  - 更新 `docs/governance/rule-layering-migration-plan.md` 增加当前执行状态（Phase0-4）
- 关键输出=Phase1 文档分流项可读可导航；Phase2/3/4 保持 pending 且原因明确
- 验证命令=`powershell -File scripts/verify-kit.ps1`; `powershell -File tests/repo-governance-hub.optimization.tests.ps1`; `powershell -File scripts/validate-config.ps1`; `powershell -File scripts/verify.ps1`; `powershell -File scripts/doctor.ps1`
- 回滚动作=`git restore docs/governance/rule-index.md docs/governance/rule-layering-inventory.md docs/governance/rule-layering-migration-plan.md docs/governance/evidence-and-rollback-runbook.md docs/governance/backflow-runbook.md docs/governance/git-scope-and-tracked-files.md docs/change-evidence/20260412-rule-layering-phase1-closeout.md`
- learning_points_3=1) 计划完成度要落在文档状态字段而非口头描述 2) 索引占位需尽快替换为真实入口避免误判完成 3) Phase2 技能项必须与技能门槛绑定推进
