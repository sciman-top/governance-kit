规则ID=oneclick-install-crossrepo-autonomous-pass-fix
规则版本=3.83
兼容窗口(观察期/强制期)=observe=2026-04-10,enforce=2026-04-17
影响模块=scripts/install-full-stack.ps1; E:/CODE/skills-manager/src/Core.ps1
当前落点=scripts/install-full-stack.ps1
目标归宿=source/project/repo-governance-hub/custom/scripts/install-full-stack.ps1
迁移批次=2026-04-10
风险等级=中
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/install-full-stack.ps1 -RepoPath <repo> -Mode safe -SkipInstallGlobalGit (3 repos); powershell -File E:/CODE/skills-manager/build.ps1; powershell -File E:/CODE/skills-manager/skills.ps1 发现
验证证据=ClassroomToolkit exit=0 (log: .codex/logs/final-install-classroomtoolkit-rerun.log); skills-manager exit=0 (log: .codex/logs/final-install-skills-manager-rerun3.log); repo-governance-hub exit=0 (log: .codex/logs/final-install-repo-governance-hub.log)
供应链安全扫描=N/A(未新增依赖)
发布后验证(指标/阈值/窗口)=一键安装后目标仓 target-precheck + target-hard-gate 成功率=100%(3/3), 观察窗口7天
数据变更治理(迁移/回填/回滚)=N/A(无数据结构变更)
回滚动作=git checkout -- scripts/install-full-stack.ps1; git -C E:/CODE/skills-manager checkout -- src/Core.ps1 skills.ps1

learning_points_3=并行执行会引发 install.lock 竞争应串行安装; codex status 非交互错误必须 platform_na 容错; 目标仓脚本 strict mode 下读取未定义变量会在自动门禁中放大失败
reusable_checklist=目标仓门禁命令应动态解析; gate执行器应区分 direct ps1 与 external command 的退出码策略; 完整复测需记录每仓日志路径与exit code
open_questions=后续是否将 analyze-repo-governance 的 JSON 输出统一改为 UTF-8 BOM/显式编码, 彻底避免中文命令乱码
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
