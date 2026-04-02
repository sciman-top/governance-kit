规则ID=R2/R3/R8 (install skipped 统计一致性修复)
规则版本=3.79
兼容窗口(观察期/强制期)=observe / planned_enforce_date=2026-04-15
影响模块=scripts/install.ps1, tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit/{scripts,tests}
目标归宿=E:/CODE/governance-kit/source/project/governance-kit/* (规则源) + 安装分发目标
迁移批次=2026-04-02-governance-install-summary-fix
风险等级=Low(单点统计修复 + 新增回归测试)
是否豁免(Waiver)=No
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -File scripts/install.ps1 -Mode plan -ShowScope
- powershell -File scripts/install.ps1 -Mode safe
- powershell -File scripts/doctor.ps1
- powershell -File scripts/verify-kit.ps1
- powershell -File tests/governance-kit.optimization.tests.ps1
- powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- powershell -File scripts/doctor.ps1
- powershell -File scripts/install.ps1 -Mode safe
验证证据=
- 修复内容：install 在 [SKIP] unchanged 分支增加 skipped++
- 新增测试："install counts unchanged entries in skipped summary"
- 优化测试集全通过（26 条）
- verify: ok=23 fail=0
- doctor: HEALTH=GREEN
- install 汇总已与日志一致：Done. copied=0 backup=0 skipped=23 mode=safe
供应链安全扫描=N/A (本次为本地脚本与测试修复，未引入第三方依赖)
发布后验证(指标/阈值/窗口)=doctor HEALTH=GREEN；verify ok=23 fail=0；持续观察窗口至 2026-04-15
数据变更治理(迁移/回填/回滚)=N/A (无数据结构变更)
回滚动作=
- git checkout -- scripts/install.ps1 tests/governance-kit.optimization.tests.ps1
- 或使用 backups/backflow-20260402-004916/ClassroomToolkit/ 对规则源回滚
