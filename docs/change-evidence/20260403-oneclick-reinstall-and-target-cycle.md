规则ID=GK-ONECLICK-REINSTALL-20260403
规则版本=3.79
兼容窗口(观察期/强制期)=observe -> enforce (unchanged)
影响模块=scripts/install.ps1;scripts/run-project-governance-cycle.ps1;source/project/ClassroomToolkit/custom/scripts/quality/run-local-quality-gates.ps1
当前落点=E:/CODE/repo-governance-hub (one-click reinstall + target governance cycle)
目标归宿=E:/CODE/repo-governance-hub/source/project/* and configured target repositories in config/targets.json
迁移批次=20260403-2
风险等级=MEDIUM
是否豁免(Waiver)=No
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=codex --version; codex --help; codex status; powershell -File scripts/install.ps1 -Mode plan -AsJson; powershell -File scripts/install.ps1 -Mode safe -AsJson; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1; powershell -File scripts/run-project-governance-cycle.ps1 -RepoPath E:/CODE/ClassroomToolkit -RepoName ClassroomToolkit -Mode safe -AutoRemediate -MaxAutoFixAttempts 1; powershell -File scripts/run-project-governance-cycle.ps1 -RepoPath E:/CODE/skills-manager -RepoName skills-manager -Mode safe -AutoRemediate -MaxAutoFixAttempts 1; powershell -File scripts/run-project-governance-cycle.ps1 -RepoPath E:/CODE/repo-governance-hub -RepoName repo-governance-hub -Mode safe -AutoRemediate -MaxAutoFixAttempts 1
验证证据=install safe copied=0 backup=0 skipped=31 and post-verify passed; verify-kit PASS; pester tests PASS(45); validate-config PASS; verify PASS(ok=31 fail=0); doctor HEALTH=GREEN; all three run-project-governance-cycle runs completed successfully
供应链安全扫描=N/A (no dedicated supply-chain scanner in this repo hard-gate command set)
发布后验证(指标/阈值/窗口)=verify targets fail=0; doctor HEALTH=GREEN
数据变更治理(迁移/回填/回滚)=backflow snapshots generated at backups/backflow-20260403-030014, backups/backflow-20260403-030032, backups/backflow-20260403-030046
回滚动作=powershell -File scripts/restore.ps1 and select corresponding backups/backflow-* snapshot

platform_na:
- reason: codex status failed in non-interactive context with "stdin is not a terminal"
- alternative_verification: codex --version and codex --help succeeded, plus full governance hard-gate chain succeeded
- evidence_link: this file + current terminal session outputs
- expires_at: 2026-06-30

gate_na:
- reason: quick gate script is not defined for repo-governance-hub itself (project contract C.2 marks quick gate as gate_na)
- alternative_verification: executed full mandatory gate chain in fixed order (build -> test -> contract/invariant -> hotspot)
- evidence_link: this file + scripts/doctor.ps1 HEALTH=GREEN in current session
- expires_at: 2026-06-30
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
