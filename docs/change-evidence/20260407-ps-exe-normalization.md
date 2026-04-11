规则ID=GK-20260407-PS-EXEC-PATH
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/automation;scripts/governance;source/project/_common/custom/scripts/governance
当前落点=scripts/governance/run-target-autopilot.ps1; scripts/governance/run-project-governance-cycle.ps1; scripts/automation/run-safe-autopilot.ps1
目标归宿=source/project/_common/custom/scripts/governance/* + target sync
迁移批次=20260407-batch-ps-exe-normalization
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=build/test/contract/hotspot all pass on 2026-04-07; verify result ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(本次仅脚本执行路径规范化，未引入新依赖)
发布后验证(指标/阈值/窗口)=gate fail count <=0 over next 1 cycle
数据变更治理(迁移/回填/回滚)=N/A(无数据结构变更)
回滚动作=git checkout -- scripts/automation/run-safe-autopilot.ps1 scripts/governance/run-target-autopilot.ps1 scripts/governance/run-project-governance-cycle.ps1 source/project/_common/custom/scripts/governance/run-target-autopilot.ps1 source/project/_common/custom/scripts/governance/run-project-governance-cycle.ps1

learning_points_3=统一子进程入口减少 pwsh/powershell 差异; 分发脚本改动必须同步 source+target; verify DIFF 是最早阻断信号
reusable_checklist=改脚本后先同步 _common/custom 与外部目标仓; 按 build->test->contract->hotspot 复验; 失败先修 source-of-truth 再重跑
open_questions=是否将 Resolve-KitRoot 进一步抽成可分发共享模块(需先定义 bootstrap 顺序)
