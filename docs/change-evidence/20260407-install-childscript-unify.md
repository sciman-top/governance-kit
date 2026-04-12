规则ID=GK-20260407-INSTALL-CHILDSCRIPT-UNIFY
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/install.ps1
当前落点=scripts/install.ps1
目标归宿=统一子脚本调用为 Invoke-ChildScript
迁移批次=20260407-batch-install-childscript
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=tests all pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next 1 cycle install-related tests remain green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/install.ps1

learning_points_3=复用子脚本 helper 可减少重复 exit-code 分支; post-gate 链路应保持统一失败语义; full-cycle 子调用应与普通调用一致
reusable_checklist=替换 powershell -File 为 Invoke-ChildScript; 保留步骤顺序; 执行完整门禁链复验
open_questions=是否将 install-full-stack.ps1 采用同一风格统一
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
