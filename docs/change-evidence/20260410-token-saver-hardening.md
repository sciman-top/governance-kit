# 20260410-token-saver-hardening

- 规则 ID: token_saver_hardening_v1
- 风险等级: low
- 目标: 在不影响基本目标（主动建议可用）的前提下，尽可能减少 token 消耗。

## 变更摘要
- 强化 `source/project/_common/custom/.governance/proactive-suggestion-policy.json`：
  - `lite` 从 `max_suggestions=2` 收紧为 `1`；`max_words_per_suggestion=20`。
  - `standard` 从 `3` 收紧为 `2`；`max_words_per_suggestion=36`。
  - 新增 `fallback_mode=silent`、`standard_upgrade_guard`、任务级去重状态存储、摘要优先输出、模板化短句。
  - `max_total_suggestion_words_per_turn` 从 `120` 收紧为 `80`。
  - 新增 `max_total_suggestion_words_per_issue=240` 与超限静默降级。
- 通过 `install -Mode safe` 分发到目标仓：
  - `E:/CODE/ClassroomToolkit/.governance/proactive-suggestion-policy.json`
  - `E:/CODE/skills-manager/.governance/proactive-suggestion-policy.json`
  - `E:/CODE/repo-governance-hub/.governance/proactive-suggestion-policy.json`

## 执行命令
1. `powershell -File scripts/install.ps1 -Mode safe`
2. `powershell -File scripts/verify-kit.ps1`
3. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
4. `powershell -File scripts/validate-config.ps1`
5. `powershell -File scripts/verify.ps1`
6. `powershell -File scripts/doctor.ps1`

## 关键输出
- `install`: `copied=3 skipped=109`（仅策略文件增量分发）。
- `verify`: `ok=112 fail=0`。
- `doctor`: `HEALTH=GREEN`，`[ASSERT] post-gate full chain passed`。
- 硬门禁全通过：`build -> test -> contract/invariant -> hotspot`。

## 回滚
- 回滚入口：`powershell -File scripts/restore.ps1`
- 本次快照：`backups/20260410-230956/`
- 快速回退：恢复该策略文件到上一版本并执行 `scripts/install.ps1 -Mode safe`。

## learning_points_3
1. 降低建议条数上限与字数上限是最直接、可控的 token 优化手段。
2. 去重从回合级提升到任务级，可显著减少重复建议消耗。
3. 先分发再 verify，可保证 source/target 一致性并避免误判失败。

## reusable_checklist
- 收紧 `lite/standard` 配额
- 增加升级门槛
- 增加任务级去重与预算上限
- install safe 分发
- 四段硬门禁复验
- 记录证据与回滚点
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
