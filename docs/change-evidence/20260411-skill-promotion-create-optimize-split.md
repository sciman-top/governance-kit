# 20260411 skill-promotion create/optimize split hardening

## Goal
- 彻底解决同类技能重复创建风险：同一 signature family 只维护一个 canonical skill。
- 明确执行语义：`create` 需要用户确认；`optimize` 在策略允许时无需确认可自动执行。

## Changes
- Updated `source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1`
  - 增加动作分流：`create` / `optimize`。
  - `require_user_ack=true` 时，仅阻断 `create`；`optimize_existing_without_ack=true` 时允许优化继续执行。
  - 结果结构新增/统一：`created_count`、`optimized_count`、`blocked_create_count`、`apply_without_ack_count`。
  - 统一输出 `[PLAN] action=...` / `[APPLIED] action=...`。
- Updated `scripts/governance/promote-skill-candidates.ps1`（运行态同步）
  - 与 source 脚本保持同构。
- Updated policy defaults
  - `source/project/_common/custom/.governance/skill-promotion-policy.json`
  - `.governance/skill-promotion-policy.json`
  - 默认开启：`require_user_ack=true`、`optimize_existing_without_ack=true`。

## Verification
### Scenario tests (local synthetic)
- Script: `E:/CODE/repo-governance-hub/tmp/run-skill-promo-scenarios.ps1`
- Case A (create only, no ack)
  - `status=awaiting_user_ack`
  - `promoted_count=0`
  - `blocked_create_count=1`
- Case B (create+optimize, no ack)
  - `status=awaiting_user_ack`
  - `promoted_count=1`
  - `created_count=0`
  - `optimized_count=1`
  - `blocked_create_count=1`
  - `apply_without_ack_count=1`
- Case C (create+optimize, ack=YES)
  - `status=ok`
  - `promoted_count=2`
  - `created_count=1`
  - `optimized_count=1`

### Repo gates
- `powershell -File scripts/verify-kit.ps1` => PASS
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1` => PASS
- `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1` => PASS
- `powershell -File scripts/doctor.ps1` => PASS (HEALTH=GREEN)
- `powershell -File scripts/install.ps1 -Mode safe` => 分发成功，`Verify done. ok=187 fail=0`

## Current runtime state
- `E:/CODE/skills-manager/overrides` currently contains:
  - `custom-auto-pwsh-encoding-mojibake-l-a9b049cd`
  - `custom-windows-encoding-guard`
- 未出现同 family 的重复 `custom-auto-*` 目录。

## Rollback
- 恢复入口：`powershell -File scripts/restore.ps1` + `backups/<timestamp>/`
- 可按本次改动文件逐一回退：
  - `source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1`
  - `scripts/governance/promote-skill-candidates.ps1`
  - `source/project/_common/custom/.governance/skill-promotion-policy.json`
  - `.governance/skill-promotion-policy.json`

## Notes
- 该改动将“是否创建新技能”的决策从隐式变为显式动作，且把用户确认边界只绑定到 `create`，避免优化链路被不必要阻断。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
