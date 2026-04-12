# 20260413 Phase3 Growth Readiness Output Noise Fix

## task_snapshot
- goal: 减少自动化运行产生的工作区噪声，不影响门禁与可观测性。
- non_goal: 不改动 growth readiness 校验语义，不调整 hard gate 顺序。
- acceptance: `report-growth-readiness` 默认输出不再写入 `docs/change-evidence/`；`build -> test -> contract/invariant -> hotspot` 全通过。
- key_assumptions: `docs/governance/reviews/` 属于运行态快照目录并已被 `.gitignore` 覆盖（已确认）。

## changes
- 修改默认输出路径：
  - `scripts/governance/report-growth-readiness.ps1`
  - `source/project/_common/custom/scripts/governance/report-growth-readiness.ps1`
- 新默认路径：`docs/governance/reviews/growth-readiness-latest.md`
- 清理本轮遗留噪声文件：`docs/change-evidence/growth-readiness-20260413-*.md`（未纳入版本管理）

## commands_and_evidence
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/report-growth-readiness.ps1 -EmitJson`
- key_output: `growth_readiness_report=E:/CODE/repo-governance-hub/docs/governance/reviews/growth-readiness-latest.md`
- key_output: `status=PASS`, `failed_count=0`

2. `powershell -File scripts/verify-kit.ps1`
- key_output: `repo-governance-hub integrity OK`

3. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- key_output: 全部用例通过（含 token baseline 回归用例）

4. `powershell -File scripts/validate-config.ps1`
- key_output: `Config validation passed. repositories=3 targets=270 rolloutRepos=1`

5. `powershell -File scripts/verify.ps1`
- key_output: `Verify done. ok=270 fail=0`
- key_output: `token_balance.status=OK`

6. `powershell -File scripts/doctor.ps1`
- key_output: `HEALTH=GREEN`

## risk_and_rollback
- risk_level: low
- risk: 外部工具若依赖旧默认落盘位置，可能找不到最新报告。
- rollback: 将上述两个脚本默认路径改回 `docs/change-evidence/growth-readiness-<timestamp>.md` 并重跑门禁。

## governance_fields
- rule_id: C.2/C.5/C.13/C.15
- issue_id: phase3-growth-readiness-output-noise
- attempt_count: 1
- clarification_mode: direct_fix
- proactive_suggestion_mode: lite
- suggestion_count: 1
- suggestion_topics: output-noise-control
- dedupe_skipped: false
- user_opt_out: false
- learning_points_3:
  1. 运行态周期报告应优先落到 ignore 区，避免污染提交范围。
  2. 同源脚本（runtime + source of truth）必须同步改动，避免 verify 回归失败。
  3. 噪声治理改动也必须走完整 hard gate 复验。
- reusable_checklist:
  - 检查默认输出目录是否为运行态目录
  - 检查 `.gitignore` / tracked-files policy 是否一致
  - 执行完整 hard gate 并留存关键输出
- open_questions:
  - 是否将 `growth-readiness-latest.md` 增加轮转机制（保留最近 N 份）
