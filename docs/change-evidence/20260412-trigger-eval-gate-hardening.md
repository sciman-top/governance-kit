规则ID=P0-01-P0-02-trigger-eval-gate-hardening
规则版本=3.85
兼容窗口(观察期/强制期)=observe: 2026-04-12 / enforce: 2026-04-12
影响模块=scripts/governance; tests; .governance/skill-candidates; source/project/_common/custom/scripts/governance
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1
迁移批次=2026-04-12-safe-install
风险等级=medium
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=1) register-skill-trigger-eval-run x60; 2) check-skill-trigger-evals.ps1 -AsJson; 3) verify-kit.ps1; 4) tests/repo-governance-hub.optimization.tests.ps1; 5) validate-config.ps1 + verify.ps1; 6) install.ps1 -Mode safe; 7) doctor.ps1
验证证据=trigger_eval.status=ok,total_runs=60,validation_pass_rate=1,validation_false_trigger_rate=0; 新增回归测试2条通过(no_data/no_validation_split)
供应链安全扫描=沿用doctor中的practice-stack/external-baselines检查，HEALTH=GREEN
发布后验证(指标/阈值/窗口)=trigger_eval summary freshness<=7d; validation_pass_rate>=0.7; validation_false_trigger_rate<=0.2
数据变更治理(迁移/回填/回滚)=新增trigger-eval runs与summary；无结构破坏性变更
回滚动作=1) git checkout回退promote脚本与测试；2) 删除trigger-eval-runs.jsonl并恢复summary快照；3) 执行scripts/restore.ps1 -BackupName <timestamp>
subagent_decision_mode=hard_guard_plus_score (policy)
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=not_applicable
reason_codes=not_applicable
hard_guard_hits=not_applicable
policy_path=E:/CODE/repo-governance-hub/config/subagent-trigger-policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true

任务理解快照=目标:打通trigger-eval数据闭环并加固create阻断; 非目标:本轮不改晋升阈值策略; 验收:硬门禁全绿+新增用例通过; 关键假设:沿用现有promotion policy
术语解释点=trigger eval summary: 技能触发评测汇总文件; no_data: 当前无可评测记录; no_validation_split: 缺少validation数据
可观测信号=trigger_eval_summary_status,trigger_eval_blocked_reason,created_count
排障路径=verify发现跨仓diff -> 回灌source -> safe install分发 -> 重跑verify/doctor
未确认假设与纠偏结论=假设仅repo本地改动可通过verify(未确认); 纠偏:必须同步source并分发到目标仓

learning_points_3=1) trigger-eval门禁需显式状态码防止误判;2) _common脚本改动必须立即回灌+分发;3) no_data阻断应有测试覆盖
reusable_checklist=seed runs->build summary->patch gate reason->add regression tests->run build/test/contract/hotspot->record evidence
open_questions=是否将trigger-eval样本自动按周扩充并去重，以避免长期过拟合样本集合
