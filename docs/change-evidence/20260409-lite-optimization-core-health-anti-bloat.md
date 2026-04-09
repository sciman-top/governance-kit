规则ID=GK-LITE-OPTIMIZATION-20260409-001
规则版本=3.83
兼容窗口(观察期/强制期)=observe
影响模块=scripts/status.ps1; scripts/verify-json-contract.ps1; scripts/governance/check-update-triggers.ps1; scripts/governance/run-recurring-review.ps1; scripts/governance/run-monthly-policy-review.ps1; config/update-trigger-policy.json; tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit
目标归宿=提升治理可观测性与反臃肿自动检查能力，且不增加默认阻断压力
迁移批次=2026-04-09-lite-optimization
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
任务理解快照=目标: 小步优化稳定性/可观测性/反臃肿；非目标: 扩大分发面与重构框架；验收标准: 全链路门禁通过且新增测试通过；关键假设: 当前仓存在持续演进需求但需避免过度设计
术语解释点=core_health: status 的核心健康聚合分(0-100)+级别，便于快速判断仓健康；常见误解是把它当硬阻断，本次仅用于可观测性
可观测信号=新增 status.core_health(score/level/reasons); recurring/monthly review 新增 orphan_custom_source_count
排障路径=测试首次失败->定位 verify 与 target source 差异->回灌 governance-kit custom source 脚本->重跑门禁
未确认假设与纠偏结论=未确认: orphan custom source 检查默认启用会否造成噪音阻断; 纠偏: 默认策略改为 disabled，仅在 policy 显式开启时触发
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1; powershell -File scripts/verify-json-contract.ps1
验证证据=tests 全通过(含新增 check-update-triggers reports low-value orphan custom sources); verify done ok=106 fail=0; doctor HEALTH=GREEN; verify-json-contract PASS
供应链安全扫描=N/A (script/config/test changes)
发布后验证(指标/阈值/窗口)=core_health.level 持续 GREEN/YELLOW 可解释; orphan_custom_source_count 在启用策略时可观测
数据变更治理(迁移/回填/回滚)=无结构化迁移；回滚为脚本与配置文件级别
回滚动作=git revert 本批变更文件；若需关闭新触发器保持 config/update-trigger-policy.json 中 low_value_orphan_custom_sources.enabled=false

learning_points_3=可观测增强应优先聚合而非堆叠字段; 反臃肿检查应默认非阻断并可策略启用; source 与目标脚本变更要同步回灌避免 verify 差异
reusable_checklist=补可观测字段->更新 JSON 合约->补回归测试->同步 source/custom 回灌->全链路门禁
open_questions=是否在 status 增加 trend(近N次 core_health)用于演进判断
