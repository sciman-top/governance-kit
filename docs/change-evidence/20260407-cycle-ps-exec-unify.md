规则ID=GK-20260407-CYCLE-PS-EXEC-UNIFY
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/run-project-governance-cycle.ps1
当前落点=scripts/run-project-governance-cycle.ps1
目标归宿=统一子进程实际执行入口(Get-CurrentPowerShellPath)
迁移批次=20260407-batch-cycle-ps-exec
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=tests all pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next 1 cycle run-project-governance-cycle related tests stay green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/run-project-governance-cycle.ps1

learning_points_3=统一真实执行入口可降低宿主shell差异; 重试命令字符串可保留为用户可读文本; 先小步替换再全门禁回归最稳妥
reusable_checklist=替换 & powershell 为 $psExe 调用; 保留行为语义不变; 跑全链路门禁确认
open_questions=是否将 retry_command 文本也统一为动态可执行前缀
