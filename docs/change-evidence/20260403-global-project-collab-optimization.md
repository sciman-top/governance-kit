规则ID=UAP-9.38-COLLAB-OPT
规则版本=Global 9.38 / Project 3.81
兼容窗口(观察期/强制期)=observe:2026-04-03~2026-04-10 / enforce:2026-04-11起
影响模块=source/global/*; source/project/{governance-kit,skills-manager,ClassroomToolkit}/*
当前落点=source/global + source/project/*
目标归宿=~/.codex ~/.claude ~/.gemini + E:/CODE/{governance-kit,skills-manager,ClassroomToolkit}
迁移批次=20260403-batch-1
风险等级=中
是否豁免(Waiver)=否
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=codex --version; codex --help; codex status; powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1; powershell -File scripts/install.ps1 -Mode safe
验证证据=verify-kit=PASS; optimization.tests=PASS; validate-config=PASS; verify=PASS(31/31); doctor=HEALTH=GREEN; install safe copied=13 backup=13 skipped=18
供应链安全扫描=沿用现有门禁链，未引入新依赖
发布后验证(指标/阈值/窗口)=规则同步一致性: targets 31/31 全绿；窗口: 24h 与 7d 复检
数据变更治理(迁移/回填/回滚)=文档规则变更，无数据迁移；必要时回滚到 backups/20260403-220028
回滚动作=powershell -File scripts/restore.ps1 -Timestamp 20260403-220028

N/A记录:
- type=platform_na
- reason=codex status 在非交互终端失败: stdin is not a terminal
- alternative_verification=codex --version + codex --help + scripts/verify.ps1 + scripts/doctor.ps1
- evidence_link=docs/change-evidence/20260403-global-project-collab-optimization.md
- expires_at=2026-04-10
