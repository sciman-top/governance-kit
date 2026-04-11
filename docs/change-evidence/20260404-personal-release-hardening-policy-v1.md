规则ID=R1/R2/R4/R6/R8
影响模块=scripts/verify-release-profile.ps1; scripts/suggest-release-profile.ps1; templates/release-profile.template.json; source/project/ClassroomToolkit/custom/.governance/release-profile.json
当前落点=release-profile 仅声明基础门禁与发布命令，未显式覆盖个人项目零签名、兼容矩阵、反误报与分发策略
目标归宿=release-profile 强制声明并校验：不签名（个人项目）、兼容矩阵、FDD/SCD 双包策略、反误报约束、可追溯产物要求
迁移批次=2026-04-04-personal-release-hardening-v1
风险等级=中（治理策略与校验逻辑增强）
执行命令=codex status; codex --version; codex --help; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
验证证据=install safe copied=1（同步 ClassroomToolkit/.governance/release-profile.json）；verify-kit PASS；optimization tests PASS；validate-config PASS（repositories=3 targets=56）；verify PASS（ok=56 fail=0）；doctor HEALTH=GREEN（release-profile-coverage PASS）
回滚动作=git checkout -- scripts/verify-release-profile.ps1 scripts/suggest-release-profile.ps1 templates/release-profile.template.json source/project/ClassroomToolkit/custom/.governance/release-profile.json docs/change-evidence/20260404-personal-release-hardening-policy-v1.md；然后重跑 verify-kit->tests->validate-config->verify->doctor
platform_na.reason=codex status 在非交互终端返回 stdin is not a terminal
platform_na.alternative_verification=codex --version 返回 codex-cli 0.118.0；codex --help exit_code=0
platform_na.evidence_link=docs/change-evidence/20260404-personal-release-hardening-policy-v1.md
platform_na.expires_at=2026-05-04
gate_na.reason=N/A
gate_na.alternative_verification=N/A
gate_na.evidence_link=docs/change-evidence/20260404-personal-release-hardening-policy-v1.md
gate_na.expires_at=N/A
