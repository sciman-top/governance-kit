规则ID=GK-CODEX-RUNTIME-ASSETS-001
规则版本=3.83
兼容窗口(观察期/强制期)=observe -> enforce (no policy flip in this change)
影响模块=source/project/_common/custom; config/project-custom-files.json; config/targets.json; scripts/validate-config.ps1; docs/PLANS.md
当前落点=repo-governance-hub source + configured target repos (ClassroomToolkit, skills-manager, repo-governance-hub)
目标归宿=Codex-first reusable runtime assets distributed by repo-governance-hub mapping pipeline
迁移批次=2026-04-09-phase-bootstrap
风险等级=medium
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=codex --version; codex --help; codex status; powershell -File scripts/refresh-targets.ps1 -Mode safe; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=targets_count=94; install copied=21 (+1 repo-governance-hub specific PLANS override); verify ok=94 fail=0; doctor HEALTH=GREEN; full gate chain passed
供应链安全扫描=N/A (no new package/dependency introduced)
发布后验证(指标/阈值/窗口)=Gate pass rate 100% in this run; recurring review follows existing weekly/monthly cadence
数据变更治理(迁移/回填/回滚)=config mapping expansion only; rollback via source revert + install safe + scripts/restore.ps1 backup snapshot
回滚动作=1) git revert changed source/config/docs; 2) powershell -File scripts/install.ps1 -Mode safe; 3) if needed powershell -File scripts/restore.ps1 -BackupPath backups/20260409-202252

learning_points_3=Distribute repo-scope .agents and plugin skeleton first; keep .codex optional to avoid tracked-files-policy conflict; preserve repo-specific override path for live PLANS.md
reusable_checklist=Added assets in _common/custom + registered in project-custom-files + refreshed targets + install safe + full gates + evidence
open_questions=When to enable .codex artifact distribution by policy profile rather than manual opt-in
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
