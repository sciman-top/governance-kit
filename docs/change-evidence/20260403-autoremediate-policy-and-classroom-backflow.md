规则ID=GK-AUTOREMEDIATE-20260403
规则版本=3.79
兼容窗口(观察期/强制期)=observe -> enforce (unchanged)
影响模块=scripts/lib/common.ps1;scripts/run-project-governance-cycle.ps1;scripts/install-full-stack.ps1;scripts/automation/run-safe-autopilot.ps1;config/project-rule-policy.json;source/project/ClassroomToolkit/custom/scripts/quality/run-local-quality-gates.ps1
当前落点=target repo direct edit had diverged from governance-kit source
目标归宿=E:/CODE/governance-kit/source/project/ClassroomToolkit/*
迁移批次=20260403-1
风险等级=MEDIUM
是否豁免(Waiver)=No
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=codex --version; codex --help; codex status; powershell -File scripts/backflow-project-rules.ps1 -RepoPath E:/CODE/ClassroomToolkit -RepoName ClassroomToolkit -Mode safe -ShowScope; powershell -File scripts/run-project-governance-cycle.ps1 -RepoPath E:/CODE/ClassroomToolkit -RepoName ClassroomToolkit -Mode safe -ShowScope -AutoRemediate -MaxAutoFixAttempts 1; powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=build/test/contract/hotspot all PASS after backflow and policy updates; verify done ok=31 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A (no supply-chain scanner command defined in current hard-gate chain)
发布后验证(指标/阈值/窗口)=doctor HEALTH=GREEN; verify-targets fail=0
数据变更治理(迁移/回填/回滚)=project-rule-policy.json schema extended with defaults/repos; backward-compatible defaults applied in scripts/lib/common.ps1
回滚动作=scripts/restore.ps1 + backups/backflow-20260403-025512/ClassroomToolkit or backups/backflow-20260403-025530/ClassroomToolkit; revert modified files if needed

platform_na:
- reason: codex status requires interactive TTY and failed with "stdin is not a terminal"
- alternative_verification: codex --version and codex --help succeeded; governance script behavior verified by hard gates
- evidence_link: this file + terminal logs in current session
- expires_at: 2026-06-30
