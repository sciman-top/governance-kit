# 20260411-token-guard-balance-rollback

- 规则 ID: GK-TOKEN-GUARD-BALANCE-ROLLBACK-20260411
- 风险等级: medium
- issue_id: 20260411-token-guard-balance-rollback
- 当前落点: `E:/CODE/governance-kit/source/project/_common/custom/*` + `config/*`
- 目标归宿: 目标仓分发后的 `.governance/*` 与 `config/clarification-policy.json`

## task_snapshot
- 目标: 避免 token 节流参数持续收紧导致编码效果下降，在节流与可交付之间恢复平衡。
- 非目标: 放开所有节流护栏、改变硬门禁顺序。
- 验收标准: 参数回调完成且 `build -> test -> contract/invariant -> hotspot` 全通过。
- 关键假设:
  - 已确认: 过紧阈值主要风险来自 anti-bloat 与澄清上限，而非建议文案长度。
  - 已确认: 目标仓需重新分发后才能消除 verify 差异。

## 变更摘要
- `source/project/_common/custom/.governance/anti-bloat-policy.json`
  - `scope.include_untracked: true -> false`
- `.governance/anti-bloat-policy.json`
  - `scope.include_untracked: true -> false`
- `config/project-rule-policy.json`
  - `defaults.token_budget_mode: lite -> standard`
  - `defaults.clarification_max_questions: 2 -> 3`
- `config/clarification-policy.json`
  - `max_clarifying_questions: 2 -> 3`
- `source/project/_common/custom/config/clarification-policy.json`
  - `max_clarifying_questions: 2 -> 3`
- `source/project/_common/custom/.governance/token-saver-policy.json`
  - `clarification.max_questions: 2 -> 3`
- `.governance/token-saver-policy.json`
  - `clarification.max_questions: 2 -> 3`

## 执行命令与关键输出
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
   - 关键输出: `governance-kit integrity OK`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File tests/governance-kit.optimization.tests.ps1`
   - 关键输出: 全部测试通过
3. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
   - 关键输出: `Config validation passed`
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
   - 首次结果: `fail=6`（跨仓策略差异）
5. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe`
   - 关键输出: 同步 `token-saver-policy / anti-bloat-policy / clarification-policy` 到目标仓
   - 关键输出: `Verify done. ok=226 fail=0`
6. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
   - 关键输出: `HEALTH=GREEN`

## 根因与修复路径
- 现象: 连续收紧策略后，编码效果风险上升且 verify 出现跨仓差异。
- 根因: 关键阈值被调得过紧（尤其 anti-bloat 未跟踪文件纳入、默认 lite 模式、澄清问题上限过低）。
- 修复: 回调到平衡档，并通过 safe install 完成 source->target 对齐。

## 回滚动作
- 入口: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restore.ps1`
- 最小回滚文件:
  - `source/project/_common/custom/.governance/anti-bloat-policy.json`
  - `.governance/anti-bloat-policy.json`
  - `config/project-rule-policy.json`
  - `config/clarification-policy.json`
  - `source/project/_common/custom/config/clarification-policy.json`
  - `source/project/_common/custom/.governance/token-saver-policy.json`
  - `.governance/token-saver-policy.json`

## Token Saver Required
- proactive_suggestion_mode: lite
- suggestion_count: 1
- topic_signature: token-guard-balance-rollback
- dedupe_skipped: false
- user_opt_out: false
- token_guard_applied: true
