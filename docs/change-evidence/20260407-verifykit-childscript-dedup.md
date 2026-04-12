规则ID=GK-20260407-VERIFYKIT-CHILDSCRIPT-DEDUP
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/verify-kit.ps1
当前落点=scripts/verify-kit.ps1
目标归宿=scripts/lib/common.ps1 共享子进程调用语义
迁移批次=20260407-batch-verifykit-childscript
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=verify-kit pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next 1 cycle verify-kit must stay green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/verify-kit.ps1

learning_points_3=复用 common 子进程 helper 可减少重复错误处理; verify-kit 内部命令应统一失败语义; 小改动可用 build+contract+hotspot 快速复验
reusable_checklist=替换 shell 调用后检查 exit-code 传播; 跑 verify-kit+verify+doctor; 确认 source-target 一致性
open_questions=是否把 install.ps1 内部同类调用也逐步迁移到 helper
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
