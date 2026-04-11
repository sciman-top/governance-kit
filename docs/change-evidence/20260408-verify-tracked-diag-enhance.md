规则ID=GK-20260408-VERIFY-TRACKED-DIAG-ENHANCE
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/verify.ps1
当前落点=scripts/verify.ps1
目标归宿=tracked-files 失败诊断增强 + helper 调用命名参数统一
迁移批次=20260408-batch-verify-tracked-diag
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=tracked-files policy failure should emit actionable message in next failure case
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/verify.ps1

learning_points_3=失败计数应配套最小可操作日志; helper 调用统一风格可降低维护歧义; 诊断增强同样需要全门禁验证
reusable_checklist=改异常处理时保留退出语义; 增加失败日志不改门禁判定; 跑完整 build/test/contract/hotspot
open_questions=是否把 tracked-files 失败信息同时写入结构化 failure context JSON
