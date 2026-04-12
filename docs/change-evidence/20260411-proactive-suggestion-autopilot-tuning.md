# 20260411-proactive-suggestion-autopilot-tuning

## task_snapshot
- issue_id: `20260411-proactive-suggestion-autopilot-tuning`
- goal: 在目标仓启用更主动的建议触发，并提高自动连续执行轮次上限，同时保持 token 护栏与风险阻断。
- non_goals: 不改变硬门禁顺序；不关闭风险阻断；不引入 `codex exec` 套娃自动修复。
- acceptance: 分发回灌成功，且 `build -> test -> contract/invariant -> hotspot` 全通过。
- key_assumptions:
  - 已确认: source of truth 为 `source/project/_common/custom/.governance/proactive-suggestion-policy.json`。
  - 已确认: 自动连续执行上限来自 `config/project-rule-policy.json` 的 `max_autonomous_iterations`。

## changes
- rule_id: `A.6/C.12/C.13/C.14`
- risk_level: `medium`
- files:
  - `source/project/_common/custom/.governance/proactive-suggestion-policy.json`
  - `config/project-rule-policy.json`
- change_points:
  - `simple_mechanical_change: false -> true`
  - `bugfix_mechanical: false -> true`
  - `max_total_suggestion_words_per_turn: 80 -> 60`
  - `max_total_suggestion_words_per_issue: 240 -> 200`
  - `defaults.max_autonomous_iterations: 3 -> 6`

## commands_and_evidence
- `powershell -File scripts/install.ps1 -Mode safe`
  - 关键输出: `[OK] ... proactive-suggestion-policy.json == ...`（三仓一致）
  - 关键输出: `HEALTH=GREEN`
- `powershell -File scripts/verify-kit.ps1`
  - 关键输出: `[PASS] rule duplication check passed`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - 关键输出: 全量用例通过（Pester 全绿）
- `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
  - 关键输出: `Config validation passed`，`Verify done. ok=187 fail=0`
- `powershell -File scripts/doctor.ps1`
  - 关键输出: `HEALTH=GREEN`

## observable_signals
- 现象: 非设计类场景（机械变更、机械 bugfix）也允许触发主动建议。
- 验证命令: 查看 `.governance/proactive-suggestion-policy.json` 的 `triggers` 与 `token_guard` 字段。
- 预期结果: 触发覆盖更广，但建议字数预算更紧。

## rollback
- 回滚动作:
  - 将 `source/project/_common/custom/.governance/proactive-suggestion-policy.json` 恢复到变更前版本。
  - 将 `config/project-rule-policy.json` 中 `defaults.max_autonomous_iterations` 恢复为 `3`。
  - 执行 `powershell -File scripts/install.ps1 -Mode safe` 回灌。
  - 重跑硬门禁确认回滚结果。
- 回滚入口: `scripts/restore.ps1` + `backups/<timestamp>/`

## learning_points_3
- 扩大触发覆盖时，优先收紧 token 预算可降低噪音成本。
- 连续执行轮次上调必须保留 no-progress guard 与失败阈值阻断。
- 变更应改 source of truth 后再统一分发，避免目标仓漂移。

## reusable_checklist
- 是否先定位 source of truth。
- 是否同时检查触发范围与 token 护栏。
- 是否完成 `install safe + 四段硬门禁`。

## open_questions
- 是否需要按仓库类型（应用仓/工具仓）进一步差异化 `triggers` 与预算上限。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
