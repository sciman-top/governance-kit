规则ID=P2-04-token-efficiency-trend-loop
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-05-10; enforce>=2026-05-11
影响模块=.governance/token-efficiency-trend-policy.json; scripts/governance/check-token-efficiency-trend.ps1; scripts/verify.ps1; scripts/governance/run-recurring-review.ps1; tests/repo-governance-hub.optimization.tests.ps1; docs/governance/token-efficiency-trend-loop.md
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/.governance/token-efficiency-trend-policy.json + source/project/_common/custom/scripts/governance/check-token-efficiency-trend.ps1 + source/project/repo-governance-hub/custom/scripts/governance/check-token-efficiency-trend.ps1
迁移批次=20260412-p2-04
风险等级=低
risk_tier=low
是否豁免(Waiver)=no
执行命令=powershell -File scripts/governance/check-token-efficiency-trend.ps1 -RepoRoot . -AsJson; powershell -File scripts/verify.ps1; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson
验证证据=history file=.governance/token-efficiency-history.jsonl 生成; recurring summary 输出 token_efficiency_trend_*; verify 输出 token_efficiency_trend.status
发布后验证(指标/阈值/窗口)=token_efficiency_trend_status + token_efficiency_trend_history_count + token_efficiency_trend_latest_value (weekly, 连续4周)
回滚动作=git restore .governance/token-efficiency-trend-policy.json scripts/governance/check-token-efficiency-trend.ps1 scripts/verify.ps1 scripts/governance/run-recurring-review.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/token-efficiency-trend-loop.md
rollback_trigger=token_efficiency_trend.status=regressing and block_on_regression=true
decision_score=N/A
hard_guard_hits=[]
policy_path=.governance/token-efficiency-trend-policy.json

任务理解快照=目标:把token效率从单点观测升级为趋势闭环; 非目标:一次性追求极限压缩并牺牲质量; 验收:趋势采样、状态判定、门禁接入均可用
术语解释点=token_per_effective_conclusion:每个有效结论平均token成本；trend loop:按周连续追踪并据状态触发动作
可观测信号=.governance/token-efficiency-history.jsonl + recurring token_efficiency_trend_* 字段
排障路径=检查metrics-auto.md是否包含token_per_effective_conclusion->核对history追加->校验policy阈值
未确认假设与纠偏结论=当前历史点不足会返回insufficient_history/missing_metric，不阻断门禁；待采样满4周后再启用严格趋势约束

learning_points_3=1) 效率优化必须趋势化而非单次快照; 2) 缺指标时先保留观测而非误阻断; 3) 策略阈值应与质量指标联动调整
reusable_checklist=定义趋势策略->实现采样与判定->接入verify/recurring->落历史文件->周检复核
open_questions=何时将 block_on_insufficient_history 从 false 切换到 true
reason_codes=trace_grading_backfill
