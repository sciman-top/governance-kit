规则ID=external-baseline-enforce-ssdf-slsa-sbom-scorecard
规则版本=9.38/3.85 compatible
兼容窗口(观察期/强制期)=enforce
影响模块=config, source/project/_common/custom, distribution targets, doctor summary
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/* + distributed target repos
迁移批次=2026-04-11 batch-1,batch-2
风险等级=中
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/refresh-targets.ps1 -AsJson; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=verify-kit/test/validate-config/verify/doctor all PASS; targets=223 synced; practice-stack average_score=100; external-baselines pass_count=4(advisory_count=0,warn_count=0,should_fail_gate=false)
供应链安全扫描=enforce phase enabled (all four baselines level=required, policy block_on_warn=true)
发布后验证(指标/阈值/窗口)=doctor summary external_baseline_status/advisory_count/warn_count, weekly recurring review
数据变更治理(迁移/回填/回滚)=N/A(config+docs+workflow+script only)
回滚动作=git restore config/practice-stack-policy.json config/project-custom-files.json config/targets.json scripts/doctor.ps1; remove new sbom/scorecard files in root and source/_common; rerun scripts/install.ps1 -Mode safe
subagent_decision_mode=hard_guard_plus_score
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=0
reason_codes=local_single_agent_execution
hard_guard_hits=none
policy_path=config/subagent-trigger-policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true

learning_points_3=1) observe阶段先补证据文件与工作流可快速提升实践覆盖；2) 分发新增文件必须先更新project-custom-files并refresh-targets；3) doctor趋势字段应做JSON探针避免非AsJson模式丢失数据
reusable_checklist=1) add source files in source/project/_common/custom;2) register in config/project-custom-files;3) refresh-targets+install;4) run hard gates in fixed order;5) snapshot practice/external baseline metrics
open_questions=是否将block_on_advisory也升级为true，以及是否要求slsa-provenance正式证明而非observe占位证明
