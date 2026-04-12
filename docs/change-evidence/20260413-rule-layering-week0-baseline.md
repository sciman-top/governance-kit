规则ID=rule-layering-phase4-week0-baseline
规则版本=9.38
兼容窗口(观察期/强制期)=observe
影响模块=docs/governance/metrics-auto.md; docs/governance/rule-layering-migration-plan.md; docs/governance/output-filter-policy.md
当前落点=rule-layering pilot window week0 baseline
目标归宿=docs/change-evidence week-by-week comparison chain
迁移批次=2026-04-13
风险等级=low
risk_tier=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=门禁链均通过; HEALTH=GREEN; trigger-eval cross-repo summary status=ok
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=观察窗口 W0 基线: first_pass_rate=85.71%; rework_after_clarification_rate=14.29%; token_per_effective_conclusion=7110
数据变更治理(迁移/回填/回滚)=无结构变更，本轮为观测基线沉淀
回滚动作=删除本证据文件并回退计划状态描述
rollback_trigger=若后续指标回退且无法归因，回退到 phase1 稳态规则并暂停输出过滤扩展
subagent_decision_mode=none
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=0
reason_codes=manual-single-agent
hard_guard_hits=none
policy_path=.governance/token-saver-policy.json

任务理解快照=目标:让 Phase4 从“已启动”进入“可持续对照”; 非目标:本轮不做跨仓全面推广决策; 验收:形成 week0 基线记录且门禁全绿
术语解释点=week0 baseline: 观察窗口的首个对照点，用于后续周度趋势比较而非一次性结论
可观测信号=first_pass_rate/rework_after_clarification_rate/token_per_effective_conclusion/update_trigger_alert_count
排障路径=先确认门禁链通过 -> 读取 metrics-auto 与 promote checkpoint -> 记录 week0 基线
未确认假设与纠偏结论=average_response_token 仍为 N/A，后续需补齐采样链路；但不影响本轮门禁通过与基线建立

learning_points_3=1) 观察窗口应先有 week0 再谈趋势; 2) no_data 阻断解除后需保留持续采样动作; 3) 指标缺口应与门禁结果分层处理
reusable_checklist=跑完整门禁 -> 核对核心指标 -> 记录 week baseline -> 更新计划状态
open_questions=是否将 week baseline 写入自动周检脚本，避免手工漏记
average_response_token=N/A
single_task_token=6094
