规则ID=GK-OUTER-AI-CLEAN-CHECKPOINT-20260403
规则版本=project/AGENTS.md v3.81 + GlobalUser/AGENTS.md v9.38
兼容窗口(观察期/强制期)=observe(2026-04-03) -> enforce(2026-04-03)
影响模块=scripts/run-project-governance-cycle.ps1; tests/governance-kit.optimization.tests.ps1; source/project/ClassroomToolkit/{AGENTS,CLAUDE,GEMINI}.md; source/project/skills-manager/{AGENTS,CLAUDE,GEMINI}.md
当前落点=E:/CODE/governance-kit/source/project/* + scripts/*
目标归宿=E:/CODE/governance-kit/source/project/*（规则）；E:/CODE/governance-kit/scripts/*（执行器）
迁移批次=2026-04-03 强化执行边界与里程碑收敛
风险等级=MEDIUM（行为更严格，dirty 工作区将阻断）
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=1) powershell -File tests/governance-kit.optimization.tests.ps1 2) powershell -File scripts/install.ps1 -Mode safe 3) powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=新增测试“run-project-governance-cycle blocks when cycle_complete clean-checkpoint is dirty”通过；install safe copied=6；verify ok=31 fail=0；doctor HEALTH=GREEN；目标仓 AGENTS 命中“外层 AI 代理会话执行”条款
供应链安全扫描=无新增第三方依赖；沿用现有 doctor/verify/status/rollout-status
发布后验证(指标/阈值/窗口)=立即窗口；阈值 verify fail=0 + doctor HEALTH=GREEN
数据变更治理(迁移/回填/回滚)=无配置结构变更；仅行为约束增强（最终 clean-checkpoint）
回滚动作=1) git revert 本次提交 2) 或使用 backups/20260403-224210/ 恢复目标仓规则文件
