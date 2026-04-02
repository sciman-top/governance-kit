规则ID=R2/R6/R8 (rollout 日期解析一致性与可观测性增强)
规则版本=3.79
兼容窗口(观察期/强制期)=observe / planned_enforce_date=2026-04-15
影响模块=scripts/status.ps1, scripts/rollout-status.ps1, tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit/scripts + tests
目标归宿=rollout 状态计算与校验口径一致（严格 yyyy-MM-dd）
迁移批次=2026-04-02-rollout-date-consistency
风险等级=Low (解析口径统一 + 回归测试)
是否豁免(Waiver)=No
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -File tests/governance-kit.optimization.tests.ps1
- powershell -File scripts/verify-kit.ps1
- powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- powershell -File scripts/doctor.ps1
验证证据=
- status.ps1 与 rollout-status.ps1 不再使用宽松 Get-Date 解析 planned_enforce_date，统一改用 Parse-IsoDate。
- invalid 日期输出补充 expected yyyy-MM-dd，降低运维误读。
- 新增2条回归测试并通过：
  1) status uses strict ISO date parsing for rollout planned_enforce_date
  2) rollout-status uses strict ISO date parsing for planned_enforce_date
- 优化测试集全通过（30 条）
- doctor=HEALTH GREEN；verify=ok=23 fail=0
供应链安全扫描=N/A (仅本地脚本与测试变更)
发布后验证(指标/阈值/窗口)=持续观察至 2026-04-15；目标：rollout.observe_overdue 仅由合法 ISO 日期计算
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=
- git checkout -- scripts/status.ps1 scripts/rollout-status.ps1 tests/governance-kit.optimization.tests.ps1
