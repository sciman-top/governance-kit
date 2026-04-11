规则ID=R2/R5/R8 (参数与脚本调用去摩擦精简)
规则版本=3.79
兼容窗口(观察期/强制期)=observe / planned_enforce_date=2026-04-15
影响模块=scripts/backflow-project-rules.ps1, scripts/verify.ps1, README.md, tests/repo-governance-hub.optimization.tests.ps1
当前落点=E:/CODE/repo-governance-hub/{scripts,tests,README}
目标归宿=治理脚本调用体验与一致性（不改变门禁语义）
迁移批次=2026-04-02-governance-simplify-batch2
风险等级=Low (参数兼容增强 + 测试补齐)
是否豁免(Waiver)=No
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -File tests/repo-governance-hub.optimization.tests.ps1
- powershell -File scripts/verify-kit.ps1
- powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- powershell -File scripts/doctor.ps1
- powershell -File scripts/install.ps1 -Mode safe
验证证据=
- 新增 backflow 参数简化：支持 -SkipCustomFiles，同时保留 -IncludeCustomFiles 兼容路径。
- backflow 参数容错增强：IncludeCustomFiles 接受 true/false/1/0/$true/$false。
- 冲突防御：-SkipCustomFiles 与 -IncludeCustomFiles:true 同时出现时报错。
- verify.ps1 简化：复用 common.ps1 的 Invoke-ChildScript，移除重复调用模板。
- 测试新增2条并通过：
  1) backflow-project-rules supports -SkipCustomFiles to avoid custom copy
  2) backflow-project-rules rejects conflicting custom file switches
- 优化测试集全通过（28 条）
- doctor=HEALTH GREEN；verify=ok=23 fail=0；install safe=skipped=23
供应链安全扫描=N/A (仅本地脚本与文档、测试改动)
发布后验证(指标/阈值/窗口)=保持 observe，观察到 2026-04-15；目标：doctor 持续 GREEN、verify fail=0
数据变更治理(迁移/回填/回滚)=N/A (无数据结构变更)
回滚动作=
- git checkout -- scripts/backflow-project-rules.ps1 scripts/verify.ps1 README.md tests/repo-governance-hub.optimization.tests.ps1
