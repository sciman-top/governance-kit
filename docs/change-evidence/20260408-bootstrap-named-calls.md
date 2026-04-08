规则ID=GK-20260408-BOOTSTRAP-NAMED-CALLS
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/bootstrap-repo.ps1
当前落点=scripts/bootstrap-repo.ps1
目标归宿=Invoke-ChildScript 调用命名参数统一
迁移批次=20260408-batch-bootstrap-named-calls
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next bootstrap flow remains green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/bootstrap-repo.ps1

learning_points_3=命名参数统一降低误读和误传参风险; bootstrap 与主链路应保持一致调用风格; 小步语义等价改动可快速累计收益
reusable_checklist=统一 helper 调用风格; 不改步骤顺序; 运行 build/test/contract/hotspot
open_questions=是否增加脚本风格检查防止新增位置参数调用
