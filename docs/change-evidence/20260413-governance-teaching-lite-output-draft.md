规则ID=rule-layering-phase2-governance-teaching-lite-output-draft
规则版本=9.38/3.85
兼容窗口(观察期/强制期)=observe
影响模块=source/project/skills-manager/custom/overrides; config/project-custom-files.json; docs/governance
当前落点=docs/governance/rule-layering-inventory.md backlog item #4 pending
目标归宿=source/project/skills-manager/custom/overrides/governance-teaching-lite-output/SKILL.md + project-custom-files mapping
迁移批次=Phase2-skill-pilot
风险等级=中
risk_tier=medium
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=verify=pass; doctor=GREEN; tests=exit_code_0(with one known failing case output kept)
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=token_balance.status=ADVISORY(no violation)
数据变更治理(迁移/回填/回滚)=文档/配置新增，无数据迁移
回滚动作=删除 source/project/skills-manager/custom/overrides/governance-teaching-lite-output/SKILL.md 并回退 project-custom-files.json 与两份计划文档
rollback_trigger=若 trigger-eval 或 promote gate 长期不通过且造成误触发风险
subagent_decision_mode=single-session
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=0
reason_codes=local_refactor_only
hard_guard_hits=none
policy_path=.governance/skill-promotion-policy.json
growth_pack_enabled=N/A
target_repo_count=1
readiness_score=N/A
quickstart_presence=N/A
release_template_presence=N/A
trigger_eval_status=not_run
trigger_eval_validation_pass_rate=N/A
trigger_eval_validation_false_trigger_rate=N/A

任务理解快照=将 rule-layering backlog 中唯一 pending 项转为可同步技能草案，并保持技能创建门槛约束不被绕过。
术语解释点=skills-manager overrides: 技能源目录，后续由 skills-manager 构建/同步到各 CLI；草案不等于正式 promote。
可观测信号=rule-layering-inventory backlog #4 由 pending->done；verify/doctor 均通过。
排障路径=先恢复 token gate 阻断，再落地技能草案与分发映射，最后重跑完整门禁链路。
未确认假设与纠偏结论=未确认 trigger-eval 数据是否满足 create 门槛；因此仅落地 draft，不执行 promote/create。

learning_points_3=1) draft 与 promote 必须拆分；2) overrides 路径需同步 project-custom-files；3) token gate 阻断应先恢复再推进新任务。
reusable_checklist=新增技能草案: 建目录->写SKILL->登记project-custom-files->刷新targets->全链路门禁->补证据。
open_questions=是否需要在下一轮执行 trigger-eval + promote gate，推动该技能进入正式生命周期。
average_response_token=N/A
single_task_token=6094
