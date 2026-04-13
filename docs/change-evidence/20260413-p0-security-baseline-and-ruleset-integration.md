规则ID=engineering-practice-p0-security-baseline-and-ruleset
规则版本=2026.04.13-p0
兼容窗口(观察期/强制期)=observe(2026-04-13~2026-05-11)/enforce(待评审)
影响模块=config,source/project/_common/custom,scripts/governance,.github/docs/governance
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/*
迁移批次=phase1-batch1
风险等级=medium
risk_tier=medium
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=git add -A && git commit(4次); powershell -File scripts/refresh-targets.ps1 -Mode safe; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=新增并分发 CODEOWNERS/codeql.yml/dependency-review.yml; external-baseline 扩展至 code_scanning/dependency_review/codeowners/repository_rulesets; practice-stack 新增 repository_rulesets; verify/doctor 全链 PASS 且 HEALTH=GREEN
供应链安全扫描=Scorecard/SBOM/SLSA workflow 保持开启，新增 CodeQL 与 Dependency Review
发布后验证(指标/阈值/窗口)=连续4周观察 external_baseline_warn_count=0 且 practice_stack.alert_count 不上升
数据变更治理(迁移/回填/回滚)=配置与脚本变更，无业务数据迁移；通过 install safe 回填目标仓
回滚动作=git revert daf5cbf 519745e 1652f93 b6c537d; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/doctor.ps1
rollback_trigger=external_baseline_warn_count 持续>0 或 doctor 非 GREEN
subagent_decision_mode=single-agent
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=85
reason_codes=p0_baseline_gap_close,high_roi_low_risk,distribution_verified
hard_guard_hits=build,test,contract/invariant,hotspot 全通过
policy_path=.governance/external-baseline-policy.json;.governance/practice-stack-policy.json;.governance/repository-ruleset-policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=92
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=existing
trigger_eval_validation_false_trigger_rate=existing

任务理解快照=目标是把规划转为可执行能力，先补齐高价值缺口（CodeQL/Dependency Review/CODEOWNERS）并纳入门禁与分发，再引入 ruleset 基线资产。
术语解释点=repository_rulesets: 指 GitHub 分支/PR 保护规则集的策略化资产；evidence_any_of: 满足任一证据即判定该基线项存在。
可观测信号=verify ok>=293, fail=0; doctor HEALTH=GREEN; external_baseline_status=OK
排障路径=refresh-targets -> install safe -> verify-kit -> tests -> validate-config -> verify -> doctor
未确认假设与纠偏结论=未确认组织级 rulesets API 自动化是否可直接接入；先落地本地策略资产与检查，后续再扩展到 settings-as-code 自动对齐

learning_points_3=1) 先补分发资产再升级门禁可避免误报;2) external/practice 双维接入比单点校验更稳定;3) 运行态信号文件不应入提交
reusable_checklist=新增基线文件->接入project-custom-files->refresh-targets/install->补verify-kit->补external/practice检查->全链验证->提交
open_questions=1) rulesets 是否升级为 required 以及何时升级;2) 是否增加 .github/rulesets/default.json 模板并自动分发
average_response_token=
single_task_token=

