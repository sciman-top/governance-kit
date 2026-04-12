规则 ID=GK-20260403-reinstall-bootstrap-self-protect
风险等级=medium
影响模块=scripts/bootstrap-repo.ps1;tests/repo-governance-hub.optimization.tests.ps1;.gitignore;source/project/ClassroomToolkit/{AGENTS,CLAUDE,GEMINI}.md;source/project/skills-manager/{AGENTS,CLAUDE,GEMINI}.md;source/project/repo-governance-hub/{AGENTS,CLAUDE,GEMINI}.md;config/targets.json
当前落点=E:/CODE/repo-governance-hub
目标归宿=E:/CODE/repo-governance-hub/source/project/*; E:/CODE/ClassroomToolkit; E:/CODE/skills-manager; E:/CODE/repo-governance-hub
迁移批次=2026-04-03 重新安装/分发既有目标仓

依据=
- 用户要求重新安装/分发既有目标仓，并强化“外层 AI 代理自主执行”与关键里程碑自动中文 git 提交/清理工作区约束。
- 实跑发现 bootstrap-repo 对 repo-governance-hub 自举时误带 `-NoOverwriteUnderRepo`，会阻断本仓根规则同步。
- 实跑发现 backups 未被整体忽略，存在污染治理仓 git 工作区的风险。

执行命令=
- codex --version
- codex --help
- codex status
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-repo.ps1 -RepoPath E:/CODE/skills-manager -Mode safe
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-repo.ps1 -RepoPath E:/CODE/repo-governance-hub -Mode safe -SkipInstallGlobalGit
- powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/skills-manager/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/skills-manager -GovernanceRoot E:/CODE/repo-governance-hub -DryRun
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/repo-governance-hub/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/repo-governance-hub -GovernanceRoot E:/CODE/repo-governance-hub -DryRun

验证证据=
- `codex status` 在非交互环境报 `stdin is not a terminal`，按 `platform_na` 处理。
- 新增测试 `bootstrap-repo skips no-overwrite self-protection for repo-governance-hub itself` 通过。
- Pester 回归全通过；`verify-kit` 通过；`validate-config` 通过；`verify`=ok 35/fail 0；`doctor`=HEALTH GREEN。
- `E:/CODE/skills-manager/scripts/governance/` 与 `E:/CODE/repo-governance-hub/scripts/governance/` 已落地 `run-project-governance-cycle.ps1`、`run-target-autopilot.ps1`。
- `E:/CODE/ClassroomToolkit/AGENTS.md`、`E:/CODE/skills-manager/AGENTS.md`、`E:/CODE/repo-governance-hub/AGENTS.md` 已包含“外层 AI 代理会话执行”与“里程碑自动提交”条款。

N/A=
- type=platform_na
- reason=`codex status` 需交互终端，当前会话返回 `stdin is not a terminal`
- alternative_verification=`codex --version` + `codex --help` + 仓库根 `AGENTS.md`/目标仓文件落地校验
- evidence_link=docs/change-evidence/20260403-reinstall-bootstrap-and-self-protection-fix.md
- expires_at=2026-04-10

风险与边界=
- `ClassroomToolkit` 当前存在明显业务开发脏改动与未跟踪测试日志；为避免把非本次治理改动纳入里程碑自动提交，本次仅完成安全分发与规则强化，不对该仓执行完整自动提交闭环实跑。
- 并发执行多个 bootstrap 会竞争 `~/.gitconfig` 锁；后续批量安装应串行执行，或统一先跑一次 `install-global-git` 再带 `-SkipInstallGlobalGit`。

回滚动作=
- git checkout -- scripts/bootstrap-repo.ps1 tests/repo-governance-hub.optimization.tests.ps1 .gitignore source/project/ClassroomToolkit/AGENTS.md source/project/ClassroomToolkit/CLAUDE.md source/project/ClassroomToolkit/GEMINI.md source/project/skills-manager/AGENTS.md source/project/skills-manager/CLAUDE.md source/project/skills-manager/GEMINI.md source/project/repo-governance-hub/AGENTS.md source/project/repo-governance-hub/CLAUDE.md source/project/repo-governance-hub/GEMINI.md config/targets.json
- git clean -fd docs/change-evidence/20260403-reinstall-bootstrap-and-self-protection-fix.md
