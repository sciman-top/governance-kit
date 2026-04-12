规则ID=rule-layering-phase3-output-filter-week0-report
规则版本=9.38
兼容窗口(观察期/强制期)=observe
影响模块=docs/governance/output-filter-policy.md; docs/governance/metrics-auto.md
当前落点=Phase3 pilot weekly comparison (W0)
目标归宿=Phase3 advisory->enforce 决策输入
迁移批次=2026-04-13
风险等级=low
risk_tier=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=W0 期间门禁链通过且 HEALTH=GREEN；未出现过滤导致的失败信号丢失
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=W0 baseline: first_pass_rate=85.71%; rework_after_clarification_rate=14.29%; token_per_effective_conclusion=7110
数据变更治理(迁移/回填/回滚)=无结构变更；本轮仅新增周报证据
回滚动作=删除本证据文件
rollback_trigger=若后续抽样出现“失败信号被过滤”则立即回滚到 raw 输出模式

任务理解快照=目标:让 Phase3 进入“按周可对照”状态; 非目标:本轮不切 enforce; 验收:形成 W0 报告并保留失败信号完整性
术语解释点=advisory: 只观测不强制；enforce: 通过规则强制执行
可观测信号=first_pass_rate/rework_after_clarification_rate/token_per_effective_conclusion/HEALTH
排障路径=先跑完整门禁确认无回退 -> 读取 metrics-auto -> 记录 W0 周报
未确认假设与纠偏结论=average_response_token 仍缺口，暂不作为 Phase3 进度阻断项

learning_points_3=1) Phase3 先建立周对照再谈 enforce 更稳妥; 2) 失败信号完整性是过滤策略的硬约束; 3) token 指标应与质量指标联动看趋势
reusable_checklist=门禁复验 -> 读取指标 -> 出周报 -> 标记下一周观察点
open_questions=何时满足从 advisory 切到 enforce 的最小周数与波动阈值
average_response_token=N/A
single_task_token=6094
