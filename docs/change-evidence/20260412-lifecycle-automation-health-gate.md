规则ID=P2-02-lifecycle-automation-health-gate
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=.governance/skill-lifecycle-health-policy.json; scripts/governance/check-skill-lifecycle-health.ps1; scripts/verify.ps1; scripts/governance/run-recurring-review.ps1; tests/repo-governance-hub.optimization.tests.ps1; docs/governance/skill-lifecycle-health-policy.md
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/.governance/skill-lifecycle-health-policy.json + source/project/_common/custom/scripts/governance/check-skill-lifecycle-health.ps1 + source/project/repo-governance-hub/custom/scripts/governance/check-skill-lifecycle-health.ps1
迁移批次=20260412-p2-02
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
执行命令=powershell -File scripts/governance/check-skill-lifecycle-health.ps1 -RepoRoot . -AsJson; powershell -File scripts/verify.ps1; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson
验证证据=skill_lifecycle_health.status=ok; verify 输出 skill_lifecycle_health.*; recurring summary 输出 skill_lifecycle_health_*
发布后验证(指标/阈值/窗口)=skill_lifecycle_retire_candidate_count; skill_lifecycle_retired_avg_latency_days; skill_lifecycle_quality_impact_delta (weekly)
回滚动作=git restore .governance/skill-lifecycle-health-policy.json scripts/governance/check-skill-lifecycle-health.ps1 scripts/verify.ps1 scripts/governance/run-recurring-review.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/skill-lifecycle-health-policy.md
rollback_trigger=skill_lifecycle_health.status!=ok
decision_score=N/A
hard_guard_hits=[]
policy_path=.governance/skill-lifecycle-health-policy.json

任务理解快照=目标:把生命周期自动化从“可运行”升级到“可度量可阻断”; 非目标:直接大规模退休现有技能; 验收:verify/recurring 均可产出生命周期健康信号
术语解释点=retire_candidate_count:满足退休条件但尚未执行的候选数；quality_impact_delta:活跃技能均值与退休技能均值差值
可观测信号=verify 输出 skill_lifecycle_health.*；alerts-latest.md 出现 lifecycle 字段
排障路径=单跑check脚本->核对registry字段->检查lifecycle policy阈值->重跑verify
未确认假设与纠偏结论=退休延迟与质量差值阈值先按保守值配置，后续按月报趋势调优

learning_points_3=1) 生命周期闭环必须有健康分层而非只做动作脚本; 2) 退休延迟是质量与成本共同约束; 3) verify+recurring 双接入可避免漏检
reusable_checklist=定义阈值->实现检查->接入门禁->接入周检->回归测试->证据留痕
open_questions=是否将 lifecycle health 指标纳入 monthly review 的固定图表
