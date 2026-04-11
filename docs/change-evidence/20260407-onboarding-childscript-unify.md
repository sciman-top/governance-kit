规则ID=GK-20260407-ONBOARDING-CHILDSCRIPT-UNIFY
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/install-full-stack.ps1; scripts/run-endstate-onboarding.ps1
当前落点=scripts/install-full-stack.ps1; scripts/run-endstate-onboarding.ps1
目标归宿=统一子脚本调用为 Invoke-ChildScript
迁移批次=20260407-batch-onboarding-childscript
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=tests all pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next onboarding/full-stack cycle remains green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/install-full-stack.ps1 scripts/run-endstate-onboarding.ps1

learning_points_3=onboarding 链路统一子脚本调用可减少重复异常分支; evidence/backfill/endstate-loop 可保持同一执行语义; full-stack 脚本无需重复手写 exit code 检查
reusable_checklist=替换 & powershell 为 Invoke-ChildScript; 保持参数顺序; 全门禁复验
open_questions=是否将 register-review-task 的 powershell 启动参数也抽成通用生成函数
