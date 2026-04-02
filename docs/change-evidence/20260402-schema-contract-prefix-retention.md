规则ID=R2/R4/R6/R8 (JSON 合同版本 + 备份前缀白名单保留)
规则版本=3.79
兼容窗口(观察期/强制期)=observe / planned_enforce_date=2026-04-15
影响模块=
- scripts/status.ps1
- scripts/rollout-status.ps1
- scripts/doctor.ps1
- scripts/prune-backups.ps1
- tests/governance-kit.optimization.tests.ps1
- README.md
当前落点=E:/CODE/governance-kit/{scripts,tests,README}
目标归宿=稳定 JSON 合同 + 可控备份清理策略
迁移批次=2026-04-02-schema-contract-prefix-retention
风险等级=Low (合同字段增强 + 新参数兼容)
是否豁免(Waiver)=No
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -File tests/governance-kit.optimization.tests.ps1
- powershell -File scripts/verify-kit.ps1
- powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- powershell -File scripts/doctor.ps1
- powershell -File scripts/install.ps1 -Mode safe
验证证据=
- status/rollout-status/doctor 的 -AsJson 输出新增 schema_version=1.0。
- prune-backups 新增 -ProtectPrefixes，支持按目录名前缀保留（即使超出天数/数量）。
- 回归测试新增/更新：
  1) doctor/status/rollout-status AsJson 合同（schema_version）
  2) prune-backups 前缀保留行为
- 优化测试集通过（39 条）
- verify=ok=23 fail=0
- doctor=HEALTH GREEN
- install safe=copied=0 backup=0 skipped=23
供应链安全扫描=N/A (无第三方依赖新增)
发布后验证(指标/阈值/窗口)=observe 期持续到 2026-04-15；JSON schema_version 维持 1.0 稳定输出
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=
- git checkout -- scripts/status.ps1 scripts/rollout-status.ps1 scripts/doctor.ps1 scripts/prune-backups.ps1 tests/governance-kit.optimization.tests.ps1 README.md
- git clean -f docs/change-evidence/20260402-schema-contract-prefix-retention.md
