规则ID=GK-20260408-ENDSTATE-NAMED-CALLS
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/run-endstate-onboarding.ps1
当前落点=scripts/run-endstate-onboarding.ps1
目标归宿=Invoke-ChildScript 调用命名参数统一
迁移批次=20260408-batch-endstate-named-calls
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next onboarding flow remains green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/run-endstate-onboarding.ps1

learning_points_3=命名参数有助于后续维护和审阅; 等价重构仍需全门禁验证; onboarding 链路与主链路应保持一致调用风格
reusable_checklist=统一 helper 调用风格; 保持步骤顺序不变; 跑 build/test/contract/hotspot
open_questions=是否把 install-full-stack 中所有 Step Action 的调用也统一加显式 ScriptArgs 空数组
