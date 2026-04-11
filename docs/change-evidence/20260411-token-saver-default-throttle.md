# 20260411-token-saver-default-throttle

- 规则 ID: GK-TOKEN-SAVER-DEFAULT-THROTTLE-20260411
- 风险等级: medium
- issue_id: 20260411-token-saver-default-throttle
- 当前落点: `E:/CODE/repo-governance-hub/source/project/_common/custom/.governance/*` + `E:/CODE/repo-governance-hub/config/*`
- 目标归宿: 分发后目标仓 `.governance/proactive-suggestion-policy.json`、`.governance/token-saver-policy.json`、`config/clarification-policy.json`

## task_snapshot
- 目标: 在不影响基本目标（可执行建议 + 澄清对齐）的前提下进一步降低 token 消耗
- 非目标: 改写治理脚本执行链路、改动硬门禁顺序
- 验收标准: 四段门禁通过，策略分发一致性通过
- 关键假设:
  - 已确认: 机械类建议触发可降级，不影响主要交付质量
  - 已确认: 澄清上限从 3 降到 2 可减少往返 token

## 变更摘要
- `source/project/_common/custom/.governance/proactive-suggestion-policy.json`
  - `triggers.simple_mechanical_change: true -> false`
  - `triggers.bugfix_mechanical: true -> false`
  - `modes.standard.max_words_per_suggestion: 36 -> 30`
  - `token_guard.max_total_suggestion_words_per_turn: 40 -> 30`
  - `token_guard.max_total_suggestion_words_per_issue: 160 -> 120`
- `source/project/_common/custom/.governance/token-saver-policy.json`
  - `clarification.max_questions: 3 -> 2`
  - `token_guard.max_total_words_per_turn: 90 -> 75`
- `source/project/_common/custom/config/clarification-policy.json`
  - `max_clarifying_questions: 3 -> 2`
- `config/clarification-policy.json`
  - `max_clarifying_questions: 3 -> 2`
- `config/project-rule-policy.json`
  - `defaults.clarification_max_questions: 3 -> 2`
- `.governance/proactive-suggestion-policy.json`、`.governance/token-saver-policy.json`
  - 同步本仓运行时副本，保持 source/runtime 一致

## 执行命令与关键输出
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
   - 关键输出: `repo-governance-hub integrity OK`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
   - 关键输出: 全部测试 `+` 通过
3. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
   - 关键输出: `Config validation passed`
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
   - 首次结果: `fail=5`（策略已改但目标仓未重分发）
5. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe`
   - 关键输出: ClassroomToolkit/skills-manager 的 proactive/token 策略被 `COPIED`
   - 关键输出: `Verify done. ok=226 fail=0`
6. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
   - 关键输出: `HEALTH=GREEN`

## 根因与修复路径
- 现象: `verify.ps1` 首次失败，跨仓策略出现 `DIFF`
- 根因: source 已更新，但目标仓尚未完成重新分发
- 修复: 更新 common source 对应配置并执行 `install -Mode safe` 后复验通过

## 回滚动作
- 入口: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restore.ps1`
- 最小回滚文件:
  - `source/project/_common/custom/.governance/proactive-suggestion-policy.json`
  - `source/project/_common/custom/.governance/token-saver-policy.json`
  - `source/project/_common/custom/config/clarification-policy.json`
  - `config/clarification-policy.json`
  - `config/project-rule-policy.json`
  - `.governance/proactive-suggestion-policy.json`
  - `.governance/token-saver-policy.json`

## Token Saver Required
- proactive_suggestion_mode: lite
- suggestion_count: 1 (policy upper bound)
- topic_signature: token-saver-default-throttle
- dedupe_skipped: false
- user_opt_out: false
- token_guard_applied: true
