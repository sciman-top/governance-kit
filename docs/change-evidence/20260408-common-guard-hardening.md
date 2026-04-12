规则ID=GK-20260408-COMMON-GUARD-HARDENING
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-08) -> enforce(2026-04-09)
影响模块=scripts/install.ps1; scripts/run-project-governance-cycle.ps1; scripts/run-endstate-onboarding.ps1; scripts/bootstrap-repo.ps1
当前落点=主执行链脚本 common helper 加载前显式存在性校验
目标归宿=缺失 common helper 时快速失败并输出明确错误
迁移批次=20260408-batch-common-guard
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=all gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next cycle script startup failures should be explicit 'Missing common helper' instead of opaque dot-source errors
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git checkout -- scripts/install.ps1 scripts/run-project-governance-cycle.ps1 scripts/run-endstate-onboarding.ps1 scripts/bootstrap-repo.ps1

learning_points_3=主链路脚本应在启动阶段尽早失败并给清晰原因; dot-source 前显式检查能减少排障时间; 防线类改动也必须全门禁回归
reusable_checklist=识别主链路脚本; 添加 Test-Path -LiteralPath -PathType Leaf 校验; 跑 build/test/contract/hotspot
open_questions=是否将同类 guard 扩展到其余工具脚本（collect/merge/remove 等）
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
