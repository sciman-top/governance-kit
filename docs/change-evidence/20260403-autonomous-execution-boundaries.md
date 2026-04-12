# 20260403-autonomous-execution-boundaries.md
规则ID=GK-AUTONOMY-BOUNDARY-20260403
影响模块=scripts/lib/common.ps1;scripts/automation/run-safe-autopilot.ps1;scripts/run-project-governance-cycle.ps1;scripts/install-full-stack.ps1;scripts/validate-config.ps1;config/project-rule-policy.json;README.md;docs/governance/oneclick-target-state-matrix.md;tests/repo-governance-hub.optimization.tests.ps1
当前落点=E:/CODE/repo-governance-hub
目标归宿=E:/CODE/repo-governance-hub（自动连续执行策略边界：最大自治轮次/重复失败上限/不可逆风险停机）
风险等级=Medium(policy schema + orchestrator behavior)
依据=用户明确要求“自动连续执行”并要求编码停机边界与最大自治轮次
执行命令=powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=新增策略字段生效：max_autonomous_iterations/max_repeated_failure_per_step/stop_on_irreversible_risk；新增 autopilot 回归测试3条与配置校验测试1条均通过；最终 hard gates 全绿（verify-kit PASS, tests PASS, validate-config PASS, verify ok=31 fail=0, doctor HEALTH=GREEN）
回滚动作=git checkout -- scripts/lib/common.ps1 scripts/automation/run-safe-autopilot.ps1 scripts/run-project-governance-cycle.ps1 scripts/install-full-stack.ps1 scripts/validate-config.ps1 config/project-rule-policy.json README.md docs/governance/oneclick-target-state-matrix.md tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/20260403-autonomous-execution-boundaries.md
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
