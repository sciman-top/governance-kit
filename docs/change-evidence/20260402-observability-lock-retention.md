规则ID=R2/R4/R6/R8 (非精简向：可观测性+并发安全+备份治理)
规则版本=3.79
兼容窗口(观察期/强制期)=observe / planned_enforce_date=2026-04-15
影响模块=
- scripts/status.ps1
- scripts/rollout-status.ps1
- scripts/doctor.ps1
- scripts/lib/common.ps1
- scripts/install.ps1
- scripts/backflow-project-rules.ps1
- scripts/restore.ps1
- scripts/prune-backups.ps1 (new)
- scripts/verify-kit.ps1
- README.md
- tests/repo-governance-hub.optimization.tests.ps1
当前落点=E:/CODE/repo-governance-hub/{scripts,tests,README}
目标归宿=治理脚本可观测性增强、并发写保护、备份生命周期管理
迁移批次=2026-04-02-observability-lock-retention
风险等级=Medium (多脚本联动改动，但已全链路复验)
是否豁免(Waiver)=No
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -File scripts/status.ps1 -AsJson
- powershell -File scripts/rollout-status.ps1 -AsJson
- powershell -File scripts/doctor.ps1 -AsJson
- powershell -File scripts/install.ps1 -Mode plan
- powershell -File scripts/backflow-project-rules.ps1 -RepoPath E:/CODE/ClassroomToolkit -RepoName ClassroomToolkit -Mode plan -SkipCustomFiles
- powershell -File scripts/prune-backups.ps1 -Mode plan -RetainDays 30 -RetainCount 10
- powershell -File tests/repo-governance-hub.optimization.tests.ps1
- powershell -File scripts/verify-kit.ps1
- powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- powershell -File scripts/doctor.ps1
- powershell -File scripts/install.ps1 -Mode safe
验证证据=
- 新增 JSON 输出：status/rollout-status/doctor 支持 -AsJson，结构可直接被 CI/监控消费。
- 并发锁接入：install/backflow-project-rules/restore 统一接入脚本锁（.locks/*.lock），新增 LockTimeoutSeconds 参数。
- 备份保留策略：新增 prune-backups.ps1，支持 plan/safe + RetainDays + RetainCount。
- verify-kit 增补必需脚本：scripts/prune-backups.ps1。
- 回归测试扩展：新增 AsJson、锁冲突、备份保留策略测试。
- 全量优化测试通过（39 条）。
- doctor: HEALTH=GREEN；verify: ok=23 fail=0；install safe: copied=0 backup=0 skipped=23。
供应链安全扫描=N/A (无第三方依赖新增)
发布后验证(指标/阈值/窗口)=observe 期持续至 2026-04-15；目标：
- doctor 维持 GREEN
- verify fail=0
- backups 清理按 RetainDays/RetainCount 可控
数据变更治理(迁移/回填/回滚)=N/A (无数据结构变更)
回滚动作=
- git checkout -- scripts/status.ps1 scripts/rollout-status.ps1 scripts/doctor.ps1 scripts/lib/common.ps1 scripts/install.ps1 scripts/backflow-project-rules.ps1 scripts/restore.ps1 scripts/verify-kit.ps1 tests/repo-governance-hub.optimization.tests.ps1 README.md
- git clean -f scripts/prune-backups.ps1 docs/change-evidence/20260402-observability-lock-retention.md
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
