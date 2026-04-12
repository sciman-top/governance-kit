规则ID=P1-02-shadow-to-enforce-rollout-policy
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=config/rule-rollout.json; .governance/rollout-promotion-policy.json; scripts/governance/check-rollout-promotion-readiness.ps1; scripts/verify.ps1; scripts/governance/run-recurring-review.ps1
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/.governance + source/project/_common/custom/scripts/governance + source/project/repo-governance-hub/custom/scripts/governance
迁移批次=20260412-p1-02
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=powershell -File scripts/governance/check-rollout-promotion-readiness.ps1 -RepoRoot . -AsJson; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=check-rollout-promotion-readiness.status=ok; verify 输出 rollout_promotion.status=ok; recurring summary rollout_promotion_status=ok & rollout_observe_window_violation_count=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新增第三方依赖)
发布后验证(指标/阈值/窗口)=minimum_observe_days_before_enforce=14; rollout_observe_window_violation_count=0 (weekly)
数据变更治理(迁移/回填/回滚)=rule-rollout 新增 observe_started_at 字段；可直接回滚配置
回滚动作=git restore config/rule-rollout.json .governance/rollout-promotion-policy.json scripts/governance/check-rollout-promotion-readiness.ps1 scripts/governance/run-recurring-review.ps1 scripts/verify.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/rollout-promotion-policy.md
rollback_trigger=rollout_promotion_status!=ok or rollout_observe_window_violation_count>0
subagent_decision_mode=hard_guard_plus_score
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=N/A
reason_codes=N/A
hard_guard_hits=[]
policy_path=.governance/rollout-promotion-policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=1
trigger_eval_validation_false_trigger_rate=0

任务理解快照=目标:把observe->enforce切换门槛从约定变成可执行门禁; 非目标:直接切换任何仓到enforce; 验收:不足14天观察窗口时阻断
术语解释点=observe_started_at:观察期起始日期; rollout_promotion_status:观察期切换就绪状态
可观测信号=verify 中 rollout_promotion.status=ok; recurring snapshot 包含 rollout_promotion_status 与 rollout_observe_window_violation_count
排障路径=先跑check-rollout-promotion-readiness定位具体repo violation -> 修正rule-rollout日期字段 -> 重跑verify与doctor
未确认假设与纠偏结论=假设 rollout 仅单仓配置可先试点；已通过策略与脚本保证后续扩仓仍可统一阻断

learning_points_3=1) 切换策略需要最小观测窗口阈值; 2) 周检必须输出就绪状态字段以便趋势追踪; 3) 在verify链路加阻断可防止“未观测足够天数”提前切换eusable_checklist=定义阈值策略->实现readiness检查脚本->接入verify与recurring->补通过/阻断测试->跑四门禁
open_questions=是否在月检脚本中增加 rollout promotion 违规趋势统计

