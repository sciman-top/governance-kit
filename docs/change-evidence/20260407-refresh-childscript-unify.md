规则ID=GK-20260407-REFRESH-CHILDSCRIPT-UNIFY
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/refresh-targets.ps1
当前落点=scripts/refresh-targets.ps1
目标归宿=统一 add-repo 子调用为 Invoke-ChildScriptCapture
迁移批次=20260407-batch-refresh-childscript
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=tests all pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next 1 cycle refresh-targets related flows stay green
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/refresh-targets.ps1

learning_points_3=用 capture helper 可统一非零退出处理; refresh 流程可减少手工 LASTEXITCODE 分支; 小步改造后全链路复验能快速确认安全
reusable_checklist=替换 direct powershell 调用; 观察输出解析是否受影响; 跑 build/test/contract/hotspot
open_questions=是否将 backflow-project-rules 中建议命令字符串也统一到 helper 生成
