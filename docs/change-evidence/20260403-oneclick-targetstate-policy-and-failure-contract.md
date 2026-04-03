# 20260403-oneclick-targetstate-policy-and-failure-contract.md
规则ID=GK-ONECLICK-TARGETSTATE-20260403
影响模块=scripts/lib/common.ps1;scripts/run-project-governance-cycle.ps1;scripts/validate-config.ps1;scripts/validate-failure-context.ps1;scripts/verify-kit.ps1;scripts/install-full-stack.ps1;scripts/automation/run-safe-autopilot.ps1;config/project-rule-policy.json;docs/governance/oneclick-target-state-matrix.md;docs/governance/agent-remediation-contract.md;README.md;tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit
目标归宿=E:/CODE/governance-kit（策略分层验收 + 非白名单本地优化边界 + 失败上下文合同校验）
风险等级=Medium(policy schema + orchestration branching)
依据=用户确认进入编码，要求落地四项：目标终态分级验收、非白名单优化策略边界、外层 AI 接管标准入口、硬门禁证据闭环
执行命令=Get-Command powershell;Test-Path scripts/{verify-kit.ps1,validate-config.ps1,verify.ps1,doctor.ps1};powershell -File scripts/verify-kit.ps1;powershell -File tests/governance-kit.optimization.tests.ps1;powershell -File scripts/validate-config.ps1;powershell -File scripts/verify.ps1;powershell -File scripts/install.ps1 -Mode safe;powershell -File scripts/verify.ps1;powershell -File scripts/doctor.ps1
验证证据=verify-kit PASS; optimization tests PASS（新增策略分支与failure-context校验用例通过）；validate-config PASS（repositories=3 targets=31 rolloutRepos=1）；verify PASS(ok=31 fail=0)；doctor HEALTH=GREEN
回滚动作=git checkout -- scripts/lib/common.ps1 scripts/run-project-governance-cycle.ps1 scripts/validate-config.ps1 scripts/verify-kit.ps1 scripts/install-full-stack.ps1 scripts/automation/run-safe-autopilot.ps1 config/project-rule-policy.json README.md tests/governance-kit.optimization.tests.ps1 docs/governance/agent-remediation-contract.md && git clean -fd scripts/validate-failure-context.ps1 docs/governance/oneclick-target-state-matrix.md docs/change-evidence/20260403-oneclick-targetstate-policy-and-failure-contract.md
