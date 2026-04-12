规则ID=R1,R2,R6,R8
影响模块=source/project/_common/custom/tools/browser-session/*, config/project-custom-files.json, README.md, README.en.md
当前落点=repo-governance-hub 项目级定制文件分发层
目标归宿=任意目标仓一键安装后自动具备可复用浏览器会话启动器
迁移批次=2026-04-04-browser-session-common-custom
风险等级=低
执行命令=
- powershell -File scripts/install-full-stack.ps1 -RepoPath E:/CODE/ClassroomToolkit -Mode plan
- powershell -NoProfile -ExecutionPolicy Bypass -File source/project/_common/custom/tools/browser-session/start-browser-session.ps1 -Name smoke -Port 65511 -AttachOnly
- powershell -File scripts/validate-config.ps1
- powershell -File scripts/add-repo.ps1 -RepoPath E:/CODE/ClassroomToolkit -Mode safe
- powershell -File scripts/add-repo.ps1 -RepoPath E:/CODE/skills-manager -Mode safe
- powershell -File scripts/add-repo.ps1 -RepoPath E:/CODE/repo-governance-hub -Mode safe
- powershell -File scripts/install.ps1 -Mode safe
- powershell -File scripts/install-full-stack.ps1 -RepoPath E:/CODE/ClassroomToolkit -Mode safe -SkipInstallGlobalGit
- powershell -File scripts/install-full-stack.ps1 -RepoPath E:/CODE/skills-manager -Mode safe -SkipInstallGlobalGit
- powershell -File scripts/install-full-stack.ps1 -RepoPath E:/CODE/repo-governance-hub -Mode safe -SkipInstallGlobalGit
- powershell -File tests/repo-governance-hub.optimization.tests.ps1
验证证据=
- project-custom-files 默认清单新增 tools/browser-session 三文件
- _common/custom 已提供 browser-session 脚本与 README，可被 add-repo fallback 命中
- start-browser-session.ps1 在 AttachOnly 模式下可正确输出接管命令
- config/targets.json 已新增 9 条 browser-session 映射（3 repo × 3 files）
- verify/doctor 全绿：targets=44, verify done ok=44 fail=0
- 三个目标仓均存在 tools/browser-session/start-browser-session.ps1
- install-full-stack 在脏工作区可安全完成分发（跳过治理周期并保留告警）
- repo-governance-hub 优化回归测试通过（repo-governance-hub.optimization.tests.ps1 全通过）
修复与优化=
- 修复 scripts/add-repo.ps1 并发写竞争：新增脚本锁（add-repo lock）
- 优化 scripts/install-full-stack.ps1 旧仓可用性：检测脏工作区时默认跳过 run-project-governance-cycle，并提示可用 -ForceGovernanceCycleOnDirty 强制执行
- 二次优化 browser-session：
  - start-browser-session.ps1 新增 `-Action start|status|stop|cleanup`
  - 新增会话元数据 `.meta/<name>.json`（pid/port/profile/browser/started_at）
  - 新增端口占用进程识别 + CDP `/json/version` 握手探测
  - 默认增强隔离参数（禁扩展/禁默认 app/禁同步，可通过 -AllowExtensions 放开）
- 二次优化 autopilot：
  - run-target-autopilot.ps1（_common + ClassroomToolkit custom）在检测到 `tools/browser-session/start-browser-session.ps1` 时输出标准 start/attach 提示
二次验证=
- powershell -File source/project/_common/custom/tools/browser-session/start-browser-session.ps1 -Action start -Name smoke-opt -Port 65529
- powershell -File source/project/_common/custom/tools/browser-session/start-browser-session.ps1 -Action status -Name smoke-opt -Port 65529
- powershell -File source/project/_common/custom/tools/browser-session/start-browser-session.ps1 -Action stop -Name smoke-opt -Port 65529
- powershell -File source/project/_common/custom/tools/browser-session/start-browser-session.ps1 -Action cleanup -Name smoke-opt -Port 65529
- powershell -File scripts/install.ps1 -Mode safe
- powershell -File scripts/doctor.ps1
- powershell -File E:/CODE/skills-manager/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/skills-manager -GovernanceRoot E:/CODE/repo-governance-hub -DryRun
回滚动作=
- 从 config/project-custom-files.json 删除 browser-session 默认分发项
- 删除 source/project/_common/custom/tools/browser-session/*
- 回滚 README 与 README.en 的对应段落
- 回滚 scripts/add-repo.ps1 的脚本锁改动
- 回滚 scripts/install-full-stack.ps1 的脏仓回退逻辑
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
