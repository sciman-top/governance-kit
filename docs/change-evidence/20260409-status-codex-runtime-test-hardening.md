规则ID=GK-CODEX-RUNTIME-OBS-TEST-005
规则版本=3.83
兼容窗口(观察期/强制期)=observe
影响模块=tests/governance-kit.optimization.tests.ps1
当前落点=governance-kit test suite
目标归宿=Prevent regression of codex_target_mappings counter via explicit test assertion
迁移批次=2026-04-09-phase-observability-test
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/verify-json-contract.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/doctor.ps1
验证证据=Status test now asserts codex_runtime.codex_target_mappings=1 in fixture; full gates pass
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=Test suite retains explicit counter assertion for future changes
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=git revert tests/governance-kit.optimization.tests.ps1

learning_points_3=Counter bug fixes should be followed by explicit assertions; fixture-based tests can validate new status fields without full environment; keep contract + behavior tests aligned
reusable_checklist=test assertion added + regression run + contract run + gates + evidence
open_questions=Should status tests include non-global codex mapping scenarios for multiple target repos
