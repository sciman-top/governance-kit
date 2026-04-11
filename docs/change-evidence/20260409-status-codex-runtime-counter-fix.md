规则ID=GK-CODEX-RUNTIME-OBS-004-FIX
规则版本=3.83
兼容窗口(观察期/强制期)=observe
影响模块=scripts/status.ps1
当前落点=repo-governance-hub source
目标归宿=Correct codex runtime mapping counter in status output
迁移批次=2026-04-09-phase-observability-fix
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/status.ps1; powershell -File scripts/verify-json-contract.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/doctor.ps1
验证证据=status now reports codex_runtime.target_mappings=5 (previously 0); json-contract pass; verify-kit/validate-config/doctor pass
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=Counter value aligns with targets.json entries containing /.codex/
数据变更治理(迁移/回填/回滚)=No data migration
回滚动作=git revert scripts/status.ps1

learning_points_3=Avoid regex over-escaping in PowerShell string patterns; validate counters with direct spot-check commands; keep lightweight post-fix verification path
reusable_checklist=bugfix + command verification + contract verification + gates + evidence
open_questions=Need dedicated status test for codex_target_mappings non-zero scenario
