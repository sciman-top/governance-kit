规则ID=rule-layering-phase4-pilot-kickoff
规则版本=9.38/3.85
兼容窗口(观察期/强制期)=observe(2026-04-13~2026-04-27)
影响模块=docs/governance/output-filter-policy.md; skills trial entries
当前落点=Phase3/Phase4 未开始
目标归宿=启动灰度观察并按周记录指标对照
迁移批次=Phase4-pilot
风险等级=中
risk_tier=medium
是否豁免(Waiver)=否
执行命令=powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=verify pass; doctor GREEN; pilot window opened
回滚动作=关闭输出过滤试点并恢复原始输出策略
rollback_trigger=一次通过率下降或返工率上升
policy_path=docs/governance/output-filter-policy.md

任务理解快照=将 Phase4 从未开始推进到已启动观察窗口，并绑定可观测指标。
术语解释点=灰度观察窗口：先在单仓观察1-2周，再决定是否跨仓推广。
可观测信号=first_pass_rate/rework_after_clarification_rate/token_per_effective_conclusion 周度对照。
排障路径=若指标异常，先停过滤试点，再回放原始日志核查误过滤。
未确认假设与纠偏结论=尚未完成一周样本采集，当前仅完成启动与基线锁定。

learning_points_3=1) Phase4 必须先定义窗口与指标；2) 失败信息保真优先于输出压缩；3) 试点仓先行能降低跨仓风险。
reusable_checklist=定义策略->启动窗口->锁定基线->周度对照->达标后推广。
open_questions=是否在 2026-04-20 做第一次周检并决定是否进入跨仓试点。
average_response_token=N/A
single_task_token=6094
