# 20260404 docs, gitignore and repo hygiene

- 规则 ID: repo-docs-hygiene-20260404
- 风险等级: medium
- 当前落点: `E:/CODE/repo-governance-hub/{README.md,README.en.md,CONTRIBUTING.md,SECURITY.md,.gitignore,docs/change-evidence}`
- 目标归宿: `E:/CODE/repo-governance-hub/{README.md,README.en.md,CONTRIBUTING.md,SECURITY.md,.gitignore,docs/change-evidence/20260404-docs-gitignore-and-repo-hygiene.md}`

## 依据

- 用户要求优化仓库中英文文档，并避免将 IDE / agent 配置、临时文件、日志备份、调试残留推送到远端。
- 本仓库项目规则要求留存 `依据 -> 命令 -> 证据 -> 回滚`。

## 平台 N/A

- `platform_na`
  - reason: `codex status` 在当前非交互执行环境返回 `stdin is not a terminal`
  - alternative_verification: 记录 `codex --version`、`codex --help` 输出，并以仓库根 `AGENTS.md` 作为 `active_rule_path`
  - evidence_link: `docs/change-evidence/20260404-docs-gitignore-and-repo-hygiene.md`
  - expires_at: `2026-04-11`

## 计划中的命令

- `codex --version`
- `codex --help`
- `codex status`
- `git status --short --branch`
- `git remote -v`
- `git ls-files backups`
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1`

## 实际执行与证据

- `codex --version`
  - `exit_code=0`
  - `key_output=codex-cli 0.118.0`
- `codex --help`
  - `exit_code=0`
  - `key_output=Codex CLI help displayed`
- `codex status`
  - `exit_code=1`
  - `key_output=Error: stdin is not a terminal`
- `git remote -v`
  - `exit_code=0`
  - `key_output=origin https://github.com/sciman-top/repo-governance-hub.git`
- `git ls-files backups | Measure-Object`
  - `exit_code=0`
  - `key_output=246 tracked backup files before cleanup`
- `git rm -r --cached -- backups`
  - `exit_code=0`
  - `key_output=tracked backup files removed from Git index and kept locally`
- `powershell -File scripts/verify-kit.ps1`
  - `exit_code=0`
  - `key_output=repo-governance-hub integrity OK`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - `exit_code=0`
  - `key_output=all listed tests passed`
- `powershell -File scripts/validate-config.ps1`
  - `exit_code=0`
  - `key_output=Config validation passed. repositories=3 targets=35 rolloutRepos=1`
- `powershell -File scripts/verify.ps1`
  - `first_run_exit_code=1`
  - `first_run_key_output=skills-manager target drift detected, fail=6`
  - `remediation=powershell -File scripts/install.ps1 -Mode safe`
  - `remediation_key_output=copied=6 backup=6 skipped=29 mode=safe`
  - `second_run_exit_code=0`
  - `second_run_key_output=Verify done. ok=35 fail=0`
- `powershell -File scripts/doctor.ps1`
  - `first_run_exit_code=1`
  - `first_run_key_output=failed_steps=verify-targets HEALTH=RED`
  - `second_run_exit_code=0`
  - `second_run_key_output=HEALTH=GREEN`

## GitHub About 现状与建议

- 当前公开页面事实：`No description, website, or topics provided.`
- 浏览器自动化取证：仓库页显示 `Sign in`，当前会话未登录，无法进入仓库设置或 About 编辑入口。
- 建议 description:
  - `Source-of-truth toolkit for distributing governance rules, templates, hooks, CI, evidence, and rollback workflows across repositories.`
- 建议 topics:
  - `governance`
  - `repository-governance`
  - `powershell`
  - `automation`
  - `policy-as-code`
  - `developer-tooling`
  - `git-hooks`
  - `ci`
- 建议 homepage:
  - `https://github.com/sciman-top/repo-governance-hub#readme`

## 回滚

- `git restore README.md README.en.md CONTRIBUTING.md SECURITY.md .gitignore docs/change-evidence/20260404-docs-gitignore-and-repo-hygiene.md`
- `git rm -r --cached -- backups` 的回滚方式：`git restore --staged backups`
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
