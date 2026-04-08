规则ID=GK-20260407-VERIFY-TRACKED-CALL-UNIFY
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/verify.ps1
当前落点=scripts/verify.ps1
目标归宿=tracked-files 校验调用统一为 Invoke-ChildScript
迁移批次=20260407-batch-verify-tracked-call
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=verify ok=73 fail=0; tracked files policy pass; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next verify run keeps tracked-files semantics unchanged
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/verify.ps1

learning_points_3=verify 内部子调用统一后异常语义更一致; try/catch 保留原 fail-counter 行为; 不改输出口径可降低测试波动
reusable_checklist=替换调用后保留计数逻辑; 跑全链路; 重点看 verify/doctor 输出
open_questions=是否将 verify-kit 内 remaining external command probes 全部迁移到 common helper
