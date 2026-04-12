规则ID=P1-04-auto-rollback-drill
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=scripts/governance/run-rollback-drill.ps1; scripts/verify.ps1; scripts/governance/run-recurring-review.ps1; docs/governance/rollback-drill-runbook.md
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/scripts/governance/run-rollback-drill.ps1 + source/project/repo-governance-hub/custom/scripts/governance/run-rollback-drill.ps1
迁移批次=20260412-p1-04
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=powershell -File scripts/governance/run-rollback-drill.ps1 -RepoRoot . -Mode safe -AsJson; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=rollback_drill.status=ok; rollback_drill.recovery_ms>0; recurring summary rollback_drill_status=ok; verify 输出 rollback_drill.status=ok; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新增第三方依赖)
发布后验证(指标/阈值/窗口)=rollback_drill_status=ok and rollback_drill_recovery_ms>0 (weekly)
数据变更治理(迁移/回填/回滚)=无生产数据变更；演练在临时沙箱目录执行
回滚动作=git restore scripts/governance/run-rollback-drill.ps1 scripts/governance/run-recurring-review.ps1 scripts/verify.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/rollback-drill-runbook.md
rollback_trigger=rollback_drill_status!=ok or rollback_drill_recovery_ms<=0
subagent_decision_mode=hard_guard_plus_score
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=N/A
reason_codes=N/A
hard_guard_hits=[]
policy_path=N/A
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=1
trigger_eval_validation_false_trigger_rate=0

任务理解快照=目标:验证restore路径具备可执行回滚能力并输出恢复耗时; 非目标:对真实仓执行破坏性回滚; 验收:演练成功且记录recovery_ms
术语解释点=rollback drill:在隔离环境模拟回滚流程的演练; recovery_ms:从演练开始到恢复完成耗时
可观测信号=verify 输出 rollback_drill.*; recurring snapshot 输出 rollback_drill_status/rollback_drill_recovery_ms
排障路径=先单跑run-rollback-drill看restore输出 -> 检查临时kit targets/backups结构 -> 重跑verify
未确认假设与纠偏结论=假设restore在临时沙箱可代表主路径可用性；通过脚本化构造targets+snapshot并校验文件内容增强可信度

learning_points_3=1) 回滚能力应持续演练而非仅文档声明; 2) 恢复时延是可量化健康指标; 3) 通过临时沙箱可避免对真实目标产生风险
reusable_checklist=构建隔离kit->生成target与snapshot->调用restore->校验内容->记录recovery_ms->接入verify/weekly
open_questions=是否在后续将rollback drill拆分为daily quick drill与weekly full drill
