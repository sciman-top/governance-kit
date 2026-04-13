# 20260413 Phase2 Gate Noise Budget Trigger

- 规则ID=phase2-gate-noise-budget-trigger
- 风险等级=medium
- 当前落点=Phase2 enforce tuning
- 目标归宿=将 gate noise budget 从文档约束升级为可执行触发器
- 任务理解快照=目标:新增 false-positive/latency 超阈值告警触发；非目标:本轮不调整 dependency-review/slsa enforce 模式；验收:check-update-triggers 可输出 gate_noise_budget_breach 且测试覆盖通过
- 术语解释点=gate noise budget: 门禁噪声预算，约束“误报率与新增时延”上限；本仓示例为 update-trigger-policy 中 `max_false_positive_rate` 与 `max_gate_latency_delta_ms`；常见误解是把“告警”当成“立即阻断所有开发”
- 执行命令=更新 config/update-trigger-policy.json; 更新 scripts/governance/check-update-triggers.ps1; 增加 tests/repo-governance-hub.optimization.tests.ps1 回归用例; 运行 install + build/test/contract/hotspot 全链
- 关键输出=新增 trigger `gate_noise_budget_breach` 与脚本检测逻辑；新增 `gate_noise_budget_alert_count` 输出字段；新增对应测试
- 可观测信号=docs/governance/alerts-latest.md 中出现 gate_latency_delta_ms / skill_trigger_eval_validation_false_trigger_rate 超阈值时触发 `gate_noise_budget_breach`
- 排障路径=现象(噪声不可执行治理) -> 假设(缺少自动触发) -> 验证命令(check-update-triggers + 测试桩) -> 结果(超阈值可告警) -> 下一步(观察两周期后再收紧阈值)
- 未确认假设与纠偏结论=未确认阈值 0.05/5000 是否适合所有目标仓；先按 observe 告警运行并在两周期后复核
- learning_points_3=1) 先把“指标可读”升级为“触发可执行”才能形成治理闭环; 2) 用 alerts-latest 快照可避免重复采集链路; 3) 新 trigger 先告警后收紧能降低误报风险
- reusable_checklist=定义阈值 -> 编码触发 -> 增加回归测试 -> 全链门禁 -> 写入证据 -> 进入周检观察
- open_questions=dependency-review enforce 的最终阈值（high/moderate）是否需要按仓分层; slsa provenance 是否在下轮切换到可验证 attestation 工作流
- 回滚动作=git restore config/update-trigger-policy.json scripts/governance/check-update-triggers.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/execution-practice-gap-matrix-2026Q2.md docs/change-evidence/20260413-phase2-gate-noise-budget-trigger.md
