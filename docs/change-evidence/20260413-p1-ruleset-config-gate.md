规则ID=repository-ruleset-config-gate
规则版本=2026.04.13-p1
兼容窗口(观察期/强制期)=observe(2026-04-13~2026-05-11)/enforce(待评审)
影响模块=scripts/governance,config/source/.governance,.github/rulesets
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/*
迁移批次=phase1-batch2
风险等级=medium
risk_tier=medium
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/refresh-targets.ps1 -Mode safe; powershell -File scripts/install.ps1 -Mode safe; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=新增 check-repository-ruleset-config.ps1 并接入 verify(contract/invariant); 新增 .governance/repository-ruleset-config.json 与 .github/rulesets/default.json 模板并完成三仓分发; ruleset_config.status=ok; HEALTH=GREEN
供应链安全扫描=保留 CodeQL/Dependency Review/SBOM/Scorecard/SLSA
发布后验证(指标/阈值/窗口)=4周观察 ruleset_config.status=ok 且 external_baseline_warn_count=0
数据变更治理(迁移/回填/回滚)=无业务数据；仅规则配置和脚本分发
回滚动作=git revert 692bbad; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/doctor.ps1
rollback_trigger=ruleset_config.status=error 或 verify/doctor 连续失败
subagent_decision_mode=single-agent
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=88
reason_codes=ruleset_template_added,contract_gate_added,cross_repo_distributed
hard_guard_hits=build,test,contract/invariant,hotspot 全通过
policy_path=.governance/repository-ruleset-policy.json;.governance/repository-ruleset-config.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=93
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=existing
trigger_eval_validation_false_trigger_rate=existing

任务理解快照=将 ruleset 能力从“策略描述”升级为“模板 + 脚本校验 + 分发”的可执行闭环，并且不破坏现有测试兼容性。
术语解释点=ruleset config artifact: 可被脚本校验的规则集配置资产，默认位于 .governance/repository-ruleset-config.json。
可观测信号=verify 输出包含 ruleset_config.status=ok; doctor 输出 HEALTH=GREEN
排障路径=发现测试回归 -> 调整 verify 缺脚本时为 skip -> 重跑 tests/verify/doctor
未确认假设与纠偏结论=组织级 rulesets API 自动写入未接入；当前先确保仓内模板与校验稳定

learning_points_3=1) 新增 contract 检查要兼容现有测试夹具;2) 模板+校验要同批分发避免空窗;3) 运行态 signal 文件保持不提交
reusable_checklist=新增模板->新增检查脚本->接入verify->接入project-custom-files->refresh/install->tests->verify/doctor->提交
open_questions=1) 何时将 repository_rulesets 从 recommended 升级为 required;2) 是否引入 GitHub API 自动对齐 rulesets
average_response_token=
single_task_token=

