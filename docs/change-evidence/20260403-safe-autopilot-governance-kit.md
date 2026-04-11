# 20260403-safe-autopilot-repo-governance-hub.md
影响模块=scripts/automation/run-safe-autopilot.ps1
当前落点=E:/CODE/repo-governance-hub
目标归宿=E:/CODE/repo-governance-hub/scripts/automation/run-safe-autopilot.ps1
迁移批次=2026-04-03-repo-governance-hub-safe-autopilot

执行命令=1) codex status; 2) codex --version; 3) codex --help; 4) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -DryRun -MaxCycles 1; 5) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -MaxCycles 1; 6) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; 7) powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; 8) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; 9) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; 10) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1; 11) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -DryRun -MaxCycles 1 -RunTargetCycle -TargetRepoPath E:/CODE/ClassroomToolkit; 12) powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -MaxCycles 1 -RunTargetCycle -TargetRepoPath E:/CODE/ClassroomToolkit -MaxTargetFixAttempts 1
验证证据=新增安全自动编排脚本并通过 dry-run；实跑 1 轮自动编排通过（包含 build/test/contract/hotspot 链）；硬门禁单独复验全通过（verify-kit OK，optimization tests 全绿，validate-config+verify OK，doctor HEALTH=GREEN）；跨仓模式实跑 1 轮通过（target cycle=ClassroomToolkit，run-project-governance-cycle 完成）
回滚动作=git checkout -- scripts/automation/run-safe-autopilot.ps1 docs/change-evidence/20260403-safe-autopilot-repo-governance-hub.md

platform_na=reason: codex status 在非交互终端失败（stdin is not a terminal） | alternative_verification: 使用 codex --version 与 codex --help 补充平台能力验证 | evidence_link: docs/change-evidence/20260403-safe-autopilot-repo-governance-hub.md | expires_at: 2026-04-30
