规则ID=P1-01-risk-tier-approval-matrix
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=.governance; scripts/governance; scripts/verify.ps1; docs/governance
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/* + source/project/repo-governance-hub/custom/*
迁移批次=20260412-p1-01
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=powershell -File scripts/governance/check-risk-tier-approval.ps1 -RepoRoot . -AsJson; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=check-risk-tier-approval.status=ok; verify 输出 risk_tier_approval.status=ok; recurring summary risk_tier_approval_status=ok; doctor HEALTH=GREEN
供应链安全扫描=N/A(本轮仅治理策略与脚本，无新增外部依赖)
发布后验证(指标/阈值/窗口)=high_risk_without_explicit_path_count=0 (weekly)
数据变更治理(迁移/回填/回滚)=无结构化数据迁移；策略文件新增可直接回滚
回滚动作=git restore scripts/governance/check-risk-tier-approval.ps1 scripts/governance/run-recurring-review.ps1 scripts/verify.ps1 .governance/risk-tier-approval-policy.json docs/governance/risk-tier-approval-matrix.md tests/repo-governance-hub.optimization.tests.ps1
rollback_trigger=risk_tier_approval_status!=ok or high_risk_without_explicit_path_count>0
subagent_decision_mode=hard_guard_plus_score
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=N/A
reason_codes=N/A
hard_guard_hits=[]
policy_path=.governance/risk-tier-approval-policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=1
trigger_eval_validation_false_trigger_rate=0

任务理解快照=目标:落地P1-01风险审批矩阵并可执行校验; 非目标:改动业务功能; 验收:高风险操作必须显式审批路径且门禁通过
术语解释点=risk_tier:变更风险等级; explicit_user_approval:会话内用户明确同意后才可执行高风险动作
可观测信号=verify中出现 risk_tier_approval.status=ok; weekly snapshot 含 risk_tier_approval_status/high_risk_without_explicit_path_count
排障路径=先单跑check-risk-tier-approval -> 再看run-recurring-review摘要 -> 最后跑verify与doctor确认全链路
未确认假设与纠偏结论=假设周检JSON可能存在松散解析波动; 已在run-recurring-review增加兜底，避免误报PARSE_ERROR

learning_points_3=1) 高风险审批需要“策略+校验器+周检”三位一体; 2) 仅文档矩阵不可阻断高风险路径; 3) 周检解析要有兜底防止误告警
reusable_checklist=新增策略文件->新增校验脚本->接入verify->接入recurring->补测试->跑四门禁
open_questions=是否在下个迭代把risk-tier策略纳入update-trigger-policy的专门告警项
