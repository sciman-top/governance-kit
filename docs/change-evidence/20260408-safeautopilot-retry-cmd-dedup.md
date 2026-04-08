规则ID=GK-20260408-SAFEAUTOPILOT-RETRY-CMD-DEDUP
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/automation/run-safe-autopilot.ps1
当前落点=retry command 文本构造逻辑
目标归宿=统一为函数 New-SafeAutopilotRetryCommand / New-TargetCycleRetryCommand
迁移批次=20260408-batch-safeautopilot-retry-dedup
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next autopilot failure-context should emit same retry command semantics
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/automation/run-safe-autopilot.ps1

learning_points_3=失败上下文命令模板应集中管理; 文本重复是演进风险源; 等价重构后需验证 failure-context 结构未漂移
reusable_checklist=提取重复命令模板函数; 保持返回文本兼容; 跑完整门禁
open_questions=是否将其它脚本中的 retry command 文本也迁移到统一 helper
