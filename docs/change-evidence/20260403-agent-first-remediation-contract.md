# 2026-04-03 agent-first-remediation-contract

## Goal
- 禁止脚本内模型 CLI 自动修复，统一改为外层 AI 会话代理接管修复闭环。

## Basis
- 用户确认目标：自动连续执行由会话代理完成，不使用 `codex exec` 套娃调用。
- 项目级规则约束：门禁顺序固定，脚本需可追溯并输出证据。

## Changes
- 脚本改造：
- `scripts/run-project-governance-cycle.ps1`
- `scripts/automation/run-safe-autopilot.ps1`
- `scripts/install.ps1`
- `scripts/install-full-stack.ps1`
- 规则与模板补强：
- `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`
- `source/template/project/AGENTS.md`
- `source/template/project/CLAUDE.md`
- `source/template/project/GEMINI.md`
- 文档：
- `README.md`
- `CHANGELOG.md`
- `docs/governance/agent-remediation-contract.md`

## Commands
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tests/governance-kit.optimization.tests.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bump-rule-version.ps1 -Scope project -Version 3.80 -Date 2026-04-03 -Mode safe`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-project-governance-cycle.ps1 -RepoPath E:\CODE\governance-kit -RepoName governance-kit -Mode plan -SkipInstall -SkipOptimize -SkipBackflow`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -RepoRoot E:\CODE\governance-kit -DryRun`

## Key Output
- build/test 通过。
- `verify`/`doctor` 失败项为跨仓分发差异（`ClassroomToolkit`、`skills-manager` 与当前 source 不一致），非脚本语法错误。
- 新脚本在失败时输出 `[FAILURE_CONTEXT_JSON]`，并明确 `remediation_owner=outer-ai-session`。

## Risk
- 中风险：版本元数据统一到 `3.80/2026-04-03` 后，会引入目标仓待同步差异。
- 影响面：`targets.json` 覆盖的仓库规则文件与个别 custom 文件。

## Rollback
- 脚本/文档回滚：`git checkout -- <changed-files>`（按需逐文件）。
- 目标仓回滚：`powershell -File scripts/restore.ps1 -BackupName <timestamp>`。

