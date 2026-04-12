规则ID=R1/R2/R4/R6/R8
影响模块=scripts/doctor.ps1; scripts/verify-kit.ps1; scripts/suggest-release-profile.ps1; scripts/verify-release-profile.ps1; scripts/check-release-profile-coverage.ps1; templates/release-profile.template.json; config/project-custom-files.json; config/targets.json; source/project/ClassroomToolkit/custom/.governance/release-profile.json; tests/repo-governance-hub.optimization.tests.ps1
当前落点=repo-governance-hub 缺少跨仓发布声明标准与 doctor 级发布覆盖检查
目标归宿=建立 release-profile v1（自动建议+校验）并接入 doctor；ClassroomToolkit 通过一键安装下发发布声明文件
迁移批次=2026-04-04-release-profile-v1
风险等级=中（治理脚本与门禁扩展）
执行命令=codex status; codex --version; codex --help; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/add-repo.ps1 -RepoPath E:/CODE/ClassroomToolkit -Mode safe; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
验证证据=verify-kit PASS；optimization tests PASS；validate-config PASS（repositories=3 targets=56）；verify PASS（ok=56 fail=0）；doctor HEALTH=GREEN（新增 release-profile-coverage PASS）；install safe 已下发 E:/CODE/ClassroomToolkit/.governance/release-profile.json
回滚动作=git checkout -- scripts/doctor.ps1 scripts/verify-kit.ps1 scripts/suggest-release-profile.ps1 scripts/verify-release-profile.ps1 scripts/check-release-profile-coverage.ps1 templates/release-profile.template.json config/project-custom-files.json config/targets.json source/project/ClassroomToolkit/custom/.governance/release-profile.json tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/20260404-release-profile-v1-and-doctor-coverage.md；随后重跑 verify-kit->tests->validate-config->verify->doctor
platform_na.reason=codex status 在非交互终端返回 stdin is not a terminal
platform_na.alternative_verification=codex --version 返回 codex-cli 0.118.0；codex --help exit_code=0
platform_na.evidence_link=docs/change-evidence/20260404-release-profile-v1-and-doctor-coverage.md
platform_na.expires_at=2026-05-04
gate_na.reason=N/A
gate_na.alternative_verification=N/A
gate_na.evidence_link=docs/change-evidence/20260404-release-profile-v1-and-doctor-coverage.md
gate_na.expires_at=N/A
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
