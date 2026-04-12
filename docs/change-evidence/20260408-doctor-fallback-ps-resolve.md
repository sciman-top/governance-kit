规则ID=GK-20260408-DOCTOR-FALLBACK-PS-RESOLVE
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/doctor.ps1
当前落点=scripts/doctor.ps1 fallback branch
目标归宿=fallback 子进程执行器改为动态解析当前 PowerShell 路径
迁移批次=20260408-batch-doctor-fallback
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next 1 cycle doctor tests and gate chain remain green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/doctor.ps1

learning_points_3=即使 fallback 分支也应避免硬编码 powershell; helper 缺失场景仍需保持执行兼容; 小步改动后跑全链路能最快发现行为漂移
reusable_checklist=修改 fallback 分支时验证 common 存在/缺失两路径语义; 跑 build/test/contract/hotspot; 补变更证据
open_questions=是否为 fallback 场景新增专门测试用例覆盖 Get-Process 解析失败分支
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
