# 20260410-token-saver-execution-templates

- 规则 ID: token_saver_execution_templates_v1
- 风险等级: low
- issue_id: token-saver-templates-20260410

## 任务理解快照
- 目标: 在目标仓分发/安装后，提供“最小快照 + lite 输出 + 澄清触发 + 证据最小字段”模板与策略，减少 AI 协作 token 消耗。
- 非目标: 修改门禁顺序、改变既有硬阻断语义、引入额外自动化执行器。
- 验收标准:
  - 新模板与策略文件可通过 install/sync 分发到三目标仓。
  - 全链路门禁 `build -> test -> contract/invariant -> hotspot` 通过。
- 关键假设(已确认/未确认):
  - 已确认: 分发源应落在 `source/project/_common/custom/.governance/*`。
  - 已确认: 目标仓落点为 `.governance/token-saver-policy.json` 与 `.governance/templates/*`。

## 变更清单
- 新增模板（仓内模板库）:
  - `templates/token-saver-task-snapshot.template.md`
  - `templates/token-saver-lite-response.template.md`
  - `templates/token-saver-clarification-trigger.template.md`
  - `templates/token-saver-evidence-minimal.template.md`
  - `templates/token-saver-policy.template.json`
- 新增分发源:
  - `source/project/_common/custom/.governance/token-saver-policy.json`
  - `source/project/_common/custom/.governance/templates/task-snapshot-minimal.md`
  - `source/project/_common/custom/.governance/templates/lite-response.md`
  - `source/project/_common/custom/.governance/templates/clarification-trigger.md`
  - `source/project/_common/custom/.governance/templates/evidence-minimal.md`
- 分发表接入:
  - 更新 `config/project-custom-files.json` default 列表，纳入上述 5 个新分发文件。

## 执行命令与证据
- `codex --version`
  - 证据: `codex-cli 0.118.0`
- `codex --help`
  - 证据: 输出包含 `exec/review/mcp/sandbox/cloud/app-server/features` 能力入口
- `codex status`
  - 证据: `Error: stdin is not a terminal`
  - 归类: `platform_na`
  - alternative_verification: 使用 `codex --version` + `codex --help` + 本次门禁日志补齐平台可用性证据
- `powershell -File scripts/refresh-targets.ps1`
  - 证据: `refresh_targets.target_change_count=15`
- `powershell -File scripts/install.ps1 -Mode safe`
  - 证据: 新文件已复制到三仓 `.governance/`（含 `token-saver-policy.json` 与 `templates/*`）
- `powershell -File scripts/verify-kit.ps1`
  - 证据: `[PASS] rule duplication check passed`
- `powershell -File tests/governance-kit.optimization.tests.ps1`
  - 证据: 全部测试通过
- `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
  - 证据: `Verify done. ok=127 fail=0`
- `powershell -File scripts/doctor.ps1`
  - 证据: `HEALTH=GREEN`

## 回滚动作
- 代码回滚: `git restore --source=HEAD -- <changed files>`（按需选择本次新增/修改文件）。
- 分发回滚: `powershell -File scripts/restore.ps1` 并使用对应 `backups/<timestamp>/` 快照。

## Token Saver Required (最小留痕)
- proactive_suggestion_mode: lite
- suggestion_count: 0
- topic_signature: token-saver-execution-templates
- dedupe_skipped: false
- user_opt_out: false
- token_guard_applied: true
