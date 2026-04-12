规则ID=GK-20260408-CYCLE-NAMED-CHILDSCRIPT-CALLS
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/run-project-governance-cycle.ps1
当前落点=scripts/run-project-governance-cycle.ps1
目标归宿=Invoke-ChildScript 调用统一命名参数写法
迁移批次=20260408-batch-cycle-named-calls
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next 1 cycle run-project-governance-cycle tests remain green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/run-project-governance-cycle.ps1

learning_points_3=命名参数可降低脚本参数顺序误用风险; 语义等价重构也需要全门禁回归; Step-OrFail 路径保持不变可降低行为漂移
reusable_checklist=统一 helper 调用写法; 保持 retry 文本不变; 运行 build/test/contract/hotspot
open_questions=是否将所有 helper 调用统一到命名参数风格并加静态检查
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
