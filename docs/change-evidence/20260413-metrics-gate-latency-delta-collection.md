规则ID=RGH-20260413-metrics-gate-latency-delta-collection
风险等级=低
影响模块=scripts/collect-governance-metrics.ps1; docs/governance/metrics-template.md; tests/repo-governance-hub.optimization.tests.ps1
当前落点=E:/CODE/repo-governance-hub/scripts/collect-governance-metrics.ps1
目标归宿=E:/CODE/repo-governance-hub/scripts/collect-governance-metrics.ps1
任务理解快照=将周检产生的 gate_latency_delta_ms 注入 metrics-auto，形成指标链路闭环；不改变 gate 顺序与阻断行为。
关键假设=alerts-latest.md 可能缺失或无该字段，需默认 N/A。
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=collect-governance-metrics 在有 alerts-latest 样本时写入 gate_latency_delta_ms=321；模板新增字段；全链路门禁通过
可观测信号=docs/governance/metrics-auto.md 出现 gate_latency_delta_ms 行
回滚动作=git restore scripts/collect-governance-metrics.ps1 docs/governance/metrics-template.md tests/repo-governance-hub.optimization.tests.ps1
未确认假设与纠偏结论=未确认真实环境中 delta 数值波动阈值；先采集再做阈值策略
learning_points_3=1) 指标链路优先从现有快照文件读取；2) 测试夹具需显式创建 docs/governance 目录；3) 默认值设计可避免数据缺失导致误报
reusable_checklist=补字段 -> 补模板 -> 补测试 -> 跑全链路 -> 清理运行态文件 -> 提交
open_questions=是否在 update-trigger-policy 增加 gate_latency_delta_ms 超阈值触发项
