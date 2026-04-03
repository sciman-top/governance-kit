规则ID=GK-INSTALL-FULLCYCLE-20260403
规则版本=project/AGENTS.md v3.81 + GlobalUser/AGENTS.md v9.38
兼容窗口(观察期/强制期)=N/A（一次性修复执行）
影响模块=scripts/install.ps1; scripts/run-project-governance-cycle.ps1; source/project/ClassroomToolkit/custom/scripts/quality/run-local-quality-gates.ps1; config/targets.json 覆盖目标
当前落点=E:/CODE/governance-kit（source + scripts）与既有目标仓（ClassroomToolkit, skills-manager, governance-kit）
目标归宿=E:/CODE/governance-kit/source/project/*（以 source 为唯一事实源）
迁移批次=2026-04-03 一键重装/分发
风险等级=MEDIUM（受控写入，含备份）
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=1) codex --version; codex --help; codex status(失败: stdin is not a terminal, platform_na) 2) powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1 3) powershell -File scripts/install.ps1 -Mode plan -ShowScope -FullCycle 4) powershell -File scripts/install.ps1 -Mode safe -ShowScope -FullCycle 5) source 回灌修复: run-local-quality-gates.ps1 中 -Profile quick -> -Profile $Profile 6) powershell -File scripts/install.ps1 -Mode safe 7) 重新执行硬门禁全序列（同2）
验证证据=install safe 输出 copied=1 backup=1 skipped=30；后续 verify 输出 ok=31 fail=0；最终 doctor 输出 HEALTH=GREEN；最终硬门禁全序列 exit_code=0
供应链安全扫描=沿用仓内 doctor/verify/status/rollout-status 现有链路，本次未新增第三方依赖
发布后验证(指标/阈值/窗口)=立即窗口；阈值为 verify fail=0 + doctor HEALTH=GREEN
数据变更治理(迁移/回填/回滚)=配置结构未变更；仅规则脚本行为对齐（Profile 参数透传）
回滚动作=1) 使用 backups/20260403-222410/ 恢复分发目标文件 2) 或执行 powershell -File scripts/restore.ps1 -Timestamp 20260403-222410

附加N/A记录:
- platform_na: codex status 在非交互终端失败（stdin is not a terminal）；替代证据为 codex --version/codex --help 与脚本执行日志；expires_at=2026-04-10
- gate_na: quick gate 脚本在本仓定义为缺失（N/A）且未改变硬门禁顺序；证据见 analyze/doctor 输出；expires_at=2026-04-10
