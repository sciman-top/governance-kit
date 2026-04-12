规则ID=rule-layering-phase2-trigger-eval-gate-checkpoint
规则版本=9.38/3.85
兼容窗口(观察期/强制期)=observe
影响模块=scripts/governance/check-skill-trigger-evals.ps1; scripts/governance/promote-skill-candidates.ps1
当前落点=Phase2 试点技能草案已存在
目标归宿=确认是否满足 create/promote 门槛
迁移批次=Phase2-gate-check
风险等级=中
risk_tier=medium
是否豁免(Waiver)=否
执行命令=powershell -File scripts/governance/check-skill-trigger-evals.ps1 -RepoRoot . -AsJson; powershell -File scripts/governance/promote-skill-candidates.ps1 -RepoRoot . -AsJson
验证证据=check-skill-trigger-evals.status=ok; promote.status=ok; created_count=0; trigger_eval_summary_status=no_data(skills-manager)
回滚动作=保持 draft-only，不执行 create/promote
rollback_trigger=当 trigger-eval 结果不稳定或门槛未满足
policy_path=.governance/skill-promotion-policy.json

任务理解快照=在不绕过技能创建门槛的前提下推进 Phase2 到“可观测 gate”状态。
术语解释点=no_data: 触发评估摘要存在但验证样本为空，不满足 create 门槛。
可观测信号=created_count=0、blocked_create_count=0、trigger_eval_pass=false、trigger_eval_blocked_reason=eval_summary_no_data。
排障路径=补齐 skills-manager 侧 trigger-eval 运行数据 -> 重新生成 summary -> 再跑 promote gate。
未确认假设与纠偏结论=repo-governance-hub 本地 summary=ok，但 promote 读取 skills-manager summary=no_data；暂不推进 create。

learning_points_3=1) draft 与 promote 门槛分离是必要控制；2) promote 依赖 skills-manager 侧 summary；3) no_data 应视为阻断而非可忽略。
reusable_checklist=新增草案后必须跑 trigger-eval + promote gate，并记录 blocked reason。
open_questions=是否现在进入 skills-manager 仓补齐 trigger-eval 样本并回灌。
average_response_token=N/A
single_task_token=6094
