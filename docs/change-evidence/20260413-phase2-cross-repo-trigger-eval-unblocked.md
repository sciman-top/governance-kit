规则ID=rule-layering-phase2-cross-repo-trigger-eval-unblocked
规则版本=9.38
兼容窗口(观察期/强制期)=observe->enforce
影响模块=E:/CODE/skills-manager/.governance/skill-candidates/trigger-eval-runs.jsonl; E:/CODE/skills-manager/.governance/skill-candidates/trigger-eval-summary.json; scripts/governance/promote-skill-candidates.ps1
当前落点=skills-manager trigger-eval data + repo-governance-hub promote gate evidence
目标归宿=docs/change-evidence + docs/governance/rule-layering-migration-plan.md
迁移批次=2026-04-13
风险等级=low
risk_tier=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=1) powershell -File E:/CODE/skills-manager/scripts/governance/register-skill-trigger-eval-run.ps1 (x4); 2) powershell -File E:/CODE/skills-manager/scripts/governance/check-skill-trigger-evals.ps1 -RepoRoot . -AsJson; 3) powershell -File scripts/governance/promote-skill-candidates.ps1 -RepoRoot . -AsJson
验证证据=skills-manager trigger_eval_summary_status: no_data -> ok; repo-governance-hub promote.trigger_eval_summary_found=true; trigger_eval_pass=true; trigger_eval_blocked_reason=""
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=Phase2 gate 不再因 skills-manager summary=no_data 阻断
数据变更治理(迁移/回填/回滚)=新增最小 trigger-eval 样本4条并生成 summary
回滚动作=删除 E:/CODE/skills-manager/.governance/skill-candidates/trigger-eval-runs.jsonl 后重建 summary，或恢复该目录快照
rollback_trigger=若 trigger-eval 样本污染导致误判升高或 promote gate 出现异常波动
subagent_decision_mode=none
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=0
reason_codes=manual-single-agent
hard_guard_hits=none
policy_path=.governance/skill-promotion-policy.json

任务理解快照=目标:解除 Phase2 跨仓 trigger-eval no_data 阻断并保持门禁语义不变; 非目标:本轮不强制 create/promote 新技能; 验收:promote 报告 trigger_eval_pass=true 且 blocked_reason 为空
术语解释点=trigger-eval summary: 技能触发评估汇总文件，create gate 依赖其验证通过；no_data: 没有评估样本导致门禁无法判定
可观测信号=E:/CODE/skills-manager/.governance/skill-candidates/trigger-eval-summary.json.status; docs/change-evidence phase2 checkpoint; promote decision_audit
排障路径=确认 runs 文件缺失 -> 注册最小 train/validation 样本 -> 重建 summary -> 在本仓重跑 promote gate
未确认假设与纠偏结论=未确认后续样本是否长期稳定；当前先完成最小可观测闭环，后续在观察窗口持续补样本

learning_points_3=1) Phase2 阻断点在跨仓数据面而非本仓脚本逻辑; 2) 先补 summary 再跑 promote 可以缩短排障链路; 3) no_data 与 no_material_delta 是不同层级信号，需分别处理
reusable_checklist=skills-manager runs存在性检查 -> summary重建 -> repo-governance-hub promote验证 -> 记录blocked_reason变化
open_questions=是否把 trigger-eval 样本扩充纳入周检自动任务，避免再次回到 no_data
average_response_token=N/A
single_task_token=6094
