规则ID=P2-03-cross-repo-compatibility-gate
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12~2026-04-19; enforce>=2026-04-20
影响模块=.governance/cross-repo-compatibility-policy.json; scripts/governance/check-cross-repo-compatibility.ps1; scripts/verify.ps1; scripts/governance/run-recurring-review.ps1; tests/repo-governance-hub.optimization.tests.ps1; docs/governance/cross-repo-compatibility-gate.md
当前落点=E:/CODE/repo-governance-hub
目标归宿=source/project/_common/custom/.governance/cross-repo-compatibility-policy.json + source/project/_common/custom/scripts/governance/check-cross-repo-compatibility.ps1 + source/project/repo-governance-hub/custom/scripts/governance/check-cross-repo-compatibility.ps1
迁移批次=20260412-p2-03
风险等级=中
risk_tier=medium
是否豁免(Waiver)=no
执行命令=powershell -File scripts/governance/check-cross-repo-compatibility.ps1 -RepoRoot . -AsJson; powershell -File scripts/verify.ps1; powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert -AsJson
验证证据=cross_repo_compatibility.status=ok; repo_failure_count=0; signal file=.governance/cross-repo-compatibility-signal.json
发布后验证(指标/阈值/窗口)=cross_repo_compatibility_repo_failure_count<=0; cross_repo_compatibility_status=ok (weekly)
回滚动作=git restore .governance/cross-repo-compatibility-policy.json scripts/governance/check-cross-repo-compatibility.ps1 scripts/verify.ps1 scripts/governance/run-recurring-review.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/cross-repo-compatibility-gate.md
rollback_trigger=cross_repo_compatibility.status!=ok
decision_score=N/A
hard_guard_hits=[]
policy_path=.governance/cross-repo-compatibility-policy.json

任务理解快照=目标:把“分发前跨仓兼容”从经验判断变为硬信号; 非目标:替代目标仓内部全部质量门禁; 验收:verify 阶段可阻断兼容失败
术语解释点=compatibility signal:分发动作前必须满足的跨仓兼容通过信号
可观测信号=.governance/cross-repo-compatibility-signal.json + recurring summary cross_repo_compatibility_*
排障路径=检查repositories.json->核对required_relative_files存在性->检查verify-release-profile结果
未确认假设与纠偏结论=当前以“必需文件+release-profile”作为最小兼容面，后续可增量加入接口契约比对

learning_points_3=1) 分发门禁需要显式通过信号而不是口头约定; 2) 跨仓问题应在分发前暴露而非上线后回滚; 3) 兼容规则必须可配置可升级
reusable_checklist=定义兼容策略->实现检查脚本->写信号文件->接入verify/recurring->测试失败分支
open_questions=是否在下一阶段加入跨仓 contract 快照差异比对
reason_codes=trace_grading_backfill
