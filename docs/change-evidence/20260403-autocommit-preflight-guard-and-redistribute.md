规则 ID=GK-20260403-autocommit-preflight-guard-and-redistribute
风险等级=medium
影响模块=scripts/run-project-governance-cycle.ps1;tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit
目标归宿=E:/CODE/governance-kit/scripts/run-project-governance-cycle.ps1
迁移批次=2026-04-03 一键重装分发前置安全加固

依据=
- 用户要求重新安装/分发既有目标仓，并在关键里程碑可自动中文提交且保持工作区干净。
- 运行事实显示里程碑自动提交路径使用 `git add -A`，若目标仓启动即脏，存在误纳入非本次治理改动风险。
- 项目规则要求先识别并隔离非本次改动，再进行自动提交与清理。

执行命令=
- codex --version
- codex --help
- codex status
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File tests/governance-kit.optimization.tests.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode plan -ShowScope
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe -ShowScope
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/ClassroomToolkit/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/ClassroomToolkit -GovernanceKitRoot E:/CODE/governance-kit -DryRun
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/skills-manager/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/skills-manager -GovernanceKitRoot E:/CODE/governance-kit -DryRun
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/governance-kit/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/governance-kit -GovernanceKitRoot E:/CODE/governance-kit -DryRun

关键变更=
- `run-project-governance-cycle.ps1` 新增 `Assert-PreflightWorkspaceClean`：safe 模式进入循环前强制检查 git 工作区是否干净；若不干净直接阻断并输出清晰错误。
- 复用 `Get-GitStatusLines` 到预检与 checkpoint 清理校验，降低状态判定分叉。
- 新增回归用例：`run-project-governance-cycle blocks early when repo is dirty before safe cycle starts`。

验证证据=
- Pester 全通过（含新增 preflight 用例）。
- 门禁通过：verify-kit=OK；validate-config=OK；verify=ok 35/fail 0；doctor=HEALTH GREEN。
- 一键分发执行完成：plan/safe 均成功，safe 后 post-verify 通过，35 个 target 映射一致。
- 目标仓 autopilot dry-run 可用，且明确 `planned_work_iteration=no-op (handled by outer AI session)`。

N/A=
- type=platform_na
- reason=`codex status` 在当前非交互会话返回 `stdin is not a terminal`
- alternative_verification=`codex --version` + `codex --help` + 运行脚本门禁与分发校验
- evidence_link=docs/change-evidence/20260403-autocommit-preflight-guard-and-redistribute.md
- expires_at=2026-04-10

回滚动作=
- 使用 `powershell -File scripts/restore.ps1` 恢复对应时间戳备份目录。
- 或基于 git 仅回退本次变更文件：scripts/run-project-governance-cycle.ps1、tests/governance-kit.optimization.tests.ps1、docs/change-evidence/20260403-autocommit-preflight-guard-and-redistribute.md。
