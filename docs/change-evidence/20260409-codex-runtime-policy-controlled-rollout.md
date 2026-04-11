规则ID=GK-CODEX-RUNTIME-POLICY-002
规则版本=3.83
兼容窗口(观察期/强制期)=observe (policy scaffold, no behavior break)
影响模块=config/codex-runtime-policy.json; source/project/_common/custom/.codex/*; scripts/lib/common.ps1; scripts/validate-config.ps1; scripts/verify-kit.ps1; config/targets.json
当前落点=repo-governance-hub source + target repo mappings
目标归宿=.codex runtime artifacts controlled by policy (default disabled, per-repo enable)
迁移批次=2026-04-09-phase-policy-control
风险等级=medium
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/validate-config.ps1; powershell -File scripts/refresh-targets.ps1 -Mode safe; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=target_change_count=4 (only repo-governance-hub .codex mappings); install copied=4 .codex files to repo-governance-hub; verify ok=98 fail=0; HEALTH=GREEN
供应链安全扫描=N/A (no external dependency change)
发布后验证(指标/阈值/窗口)=No gate regression; per-repo policy kept disabled-by-default to cap rollout blast radius
数据变更治理(迁移/回填/回滚)=mapping/config/data-only change; rollback by disabling repo policy entry + refresh-targets + install
回滚动作=1) set repo-governance-hub enabled=false in config/codex-runtime-policy.json; 2) powershell -File scripts/refresh-targets.ps1 -Mode safe; 3) powershell -File scripts/install.ps1 -Mode safe; 4) optional scripts/restore.ps1 backup restore

learning_points_3=Add policy-controlled optional files through common resolver to reuse existing target refresh pipeline; keep default disabled to avoid accidental cross-repo runtime pollution; maintain verify-kit mustExist for newly introduced policy and template assets
reusable_checklist=policy file + source templates + parser integration + config validation + mapping refresh + install + full gates + evidence
open_questions=Whether to expose codex-runtime-policy toggles via a dedicated CLI helper script (set-codex-runtime-policy.ps1)
