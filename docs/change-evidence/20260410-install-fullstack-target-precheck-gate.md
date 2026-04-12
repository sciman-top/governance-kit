规则ID=oneclick-install-target-precheck-gate
规则版本=3.83
兼容窗口(观察期/强制期)=observe=2026-04-10,enforce=2026-04-17
影响模块=scripts/install-full-stack.ps1
当前落点=scripts/install-full-stack.ps1
目标归宿=source/project/repo-governance-hub/custom/scripts/install-full-stack.ps1
迁移批次=2026-04-10
风险等级=中
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-full-stack.ps1 -RepoPath E:\CODE\repo-governance-hub -Mode plan -SkipAutopilotSmoke -SkipTargetPrecheck -SkipTargetGate; PowerShell Parser::ParseFile(scripts/install-full-stack.ps1)
验证证据=命令返回exit_code=0；install-full-stack plan链路执行完成；脚本语法解析无错误
供应链安全扫描=N/A(本次仅脚本编排改动, 未引入新依赖)
发布后验证(指标/阈值/窗口)=目标仓一键安装后可连续完成precheck+hard-gate, 窗口7天
数据变更治理(迁移/回填/回滚)=N/A(无数据结构变更)
回滚动作=git checkout -- scripts/install-full-stack.ps1; 或执行 scripts/restore.ps1 + backups/<timestamp>/

learning_points_3=将目标仓预检与硬门禁并入一键安装可降低人工断点; codex status 非交互失败需按 platform_na 记录并继续; test脚本缺失时按 gate_na 回退但保持门禁顺序
reusable_checklist=安装前刷新目标映射; 安装后运行目标仓precheck; 固定顺序执行build->test->contract/invariant->hotspot
open_questions=是否需要将 target-precheck/target-hard-gate 下沉到独立脚本供其他入口复用
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
