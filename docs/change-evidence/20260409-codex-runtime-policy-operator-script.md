规则ID=GK-CODEX-RUNTIME-POLICY-OPS-003
规则版本=3.83
兼容窗口(观察期/强制期)=observe (operator utility addition)
影响模块=scripts/set-codex-runtime-policy.ps1; scripts/verify-kit.ps1; tests/repo-governance-hub.optimization.tests.ps1; README.md
当前落点=repo-governance-hub source
目标归宿=Policy toggle operation for .codex distribution without manual JSON editing
迁移批次=2026-04-09-phase-ops-tooling
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=New tests passed: Get-CodexRuntimeFilesForRepo policy behavior + set-codex-runtime-policy update path; full gates passed; HEALTH=GREEN
供应链安全扫描=N/A (script/test/doc only)
发布后验证(指标/阈值/窗口)=No mapping drift; no gate regression; operator script available for future per-repo policy flips
数据变更治理(迁移/回填/回滚)=No data schema migration; rollback via file revert
回滚动作=git revert scripts/set-codex-runtime-policy.ps1 scripts/verify-kit.ps1 tests/repo-governance-hub.optimization.tests.ps1 README.md

learning_points_3=Expose policy mutations through scripts to reduce manual JSON edits; keep tests close to policy resolver and operator path; add operator script to verify-kit mustExist to avoid silent drift
reusable_checklist=operator script added + documented + verify-kit registered + regression tests + full gate pass + evidence
open_questions=Whether to expose policy status in scripts/status.ps1 summary for quick observability
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
