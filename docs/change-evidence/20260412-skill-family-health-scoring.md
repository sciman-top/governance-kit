规则ID=P2-01-skill-family-health-scoring
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=.governance/skill-family-health-policy.json; scripts/governance/check-skill-family-health.ps1; scripts/governance/run-recurring-review.ps1; scripts/verify.ps1; tests/repo-governance-hub.optimization.tests.ps1; docs/governance/skill-family-health-policy.md
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/.governance/skill-family-health-policy.json + source/project/_common/custom/scripts/governance/check-skill-family-health.ps1 + source/project/repo-governance-hub/custom/scripts/governance/check-skill-family-health.ps1
迁移批次=20260412-p2-01
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-skill-family-health.ps1 -RepoRoot . -AsJson; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=skill_family_health.status=ok; active_family_duplicate_count=0; low_health_target_state_count=0; verify 输出 skill_family_health.status=ok; recurring summary 包含 skill_family_health_* 字段
供应链安全扫描=N/A(无新增第三方依赖)
发布后验证(指标/阈值/窗口)=skill_family_active_family_duplicate_count<=0; skill_family_low_health_target_state_count<=0 (weekly)
数据变更治理(迁移/回填/回滚)=无生产数据结构变更；仅新增策略/检查脚本与周检摘要字段
回滚动作=git restore .governance/skill-family-health-policy.json scripts/governance/check-skill-family-health.ps1 scripts/governance/run-recurring-review.ps1 scripts/verify.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/skill-family-health-policy.md docs/governance/ai-self-evolution-task-backlog-2026Q2.md
rollback_trigger=skill_family_health.status!=ok or active_family_duplicate_count>0
subagent_decision_mode=hard_guard_plus_score
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=N/A
reason_codes=N/A
hard_guard_hits=[]
policy_path=.governance/skill-family-health-policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=1
trigger_eval_validation_false_trigger_rate=0

任务理解快照=目标:建立技能家族去重与健康度评分闭环并接入硬门禁/周检; 非目标:直接修改现有技能注册表生命周期状态; 验收:重复家族与低健康目标态可被自动检测并阻断
术语解释点=family_signature:同类技能聚合键；health_score:技能家族健康度评分（用于目标态准入）
可观测信号=verify 输出 skill_family_health.*; recurring snapshot 输出 skill_family_health_status/duplicate_count/low_health_count/avg_health
排障路径=先单跑check-skill-family-health定位状态 -> 校验policy阈值 -> 检查promotion-registry字段完整性 -> 重跑verify与recurring
未确认假设与纠偏结论=假设现有 promoted 数据量可代表目标态质量；通过新增重复家族失败用例确保检测能力在样例外仍可复现

learning_points_3=1) 家族级聚合比单技能视角更能发现重复推广问题; 2) 健康度阈值应与生命周期状态联动而非静态检查; 3) 周检摘要与硬门禁同时接入可减少“脚本存在但不生效”风险
reusable_checklist=定义阈值策略->实现检查脚本->接入verify阻断->接入recurring指标->补回归测试->补证据与回滚
open_questions=skill_family_active_family_avg_health_score 在 recurring 输出为0时需继续做解析稳定性增强
