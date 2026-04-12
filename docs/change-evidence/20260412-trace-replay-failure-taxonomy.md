规则ID=P1-03-trace-replay-and-failure-taxonomy
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=.governance/failure-replay/*; scripts/governance/check-failure-replay-readiness.ps1; scripts/verify.ps1; scripts/governance/run-recurring-review.ps1
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/.governance/failure-replay/* + source/project/_common/custom/scripts/governance/check-failure-replay-readiness.ps1 + repo-governance-hub custom scripts
迁移批次=20260412-p1-03
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=powershell -File scripts/governance/check-failure-replay-readiness.ps1 -RepoRoot . -AsJson; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=failure_replay.status=ok; failure_replay.top_signature_target=5; failure_replay.top5_coverage_rate=1; failure_replay.missing_top5_count=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(无新增外部依赖)
发布后验证(指标/阈值/窗口)=failure_replay_top5_coverage_rate>=1 and failure_replay_missing_top5_count=0 (weekly)
数据变更治理(迁移/回填/回滚)=新增 failure-replay policy/catalog 文件；可直接回滚
回滚动作=git restore .governance/failure-replay/policy.json .governance/failure-replay/replay-cases.json scripts/governance/check-failure-replay-readiness.ps1 scripts/governance/run-recurring-review.ps1 scripts/verify.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/failure-replay-policy.md
rollback_trigger=failure_replay_status!=ok or failure_replay_missing_top5_count>0
subagent_decision_mode=hard_guard_plus_score
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=N/A
reason_codes=N/A
hard_guard_hits=[]
policy_path=.governance/failure-replay/policy.json
growth_pack_enabled=true
target_repo_count=3
readiness_score=100
quickstart_presence=true
release_template_presence=true
trigger_eval_status=ok
trigger_eval_validation_pass_rate=1
trigger_eval_validation_false_trigger_rate=0

任务理解快照=目标:将Top5常见故障与可回放case建立一一覆盖校验; 非目标:执行真实破坏性回放; 验收:Top5覆盖率=1且缺失数=0
术语解释点=issue_signature:故障签名标识; replay case:用于复现实验和对比的最小命令模板
可观测信号=verify 输出 failure_replay.* 指标; recurring snapshot 含 failure_replay_status/top5_coverage_rate/missing_top5_count
排障路径=先跑check-failure-replay-readiness看missing_top5_signatures -> 补齐replay-cases -> 重跑verify
未确认假设与纠偏结论=当前观测签名不足5时允许catalog兜底；通过策略字段显式控制，避免“无数据即通过”

learning_points_3=1) TopN覆盖需要“观测+目录兜底”双源；2) 仅有签名统计不足以回放，必须校验命令模板字段；3) 周检指标应直接暴露缺失数量
reusable_checklist=定义failure-replay policy->维护replay-cases->实现readiness检查->接入verify/weekly->补pass/fail测试->跑四门禁
open_questions=是否在P1-04把失败回放与restore演练自动串联成单次drill
