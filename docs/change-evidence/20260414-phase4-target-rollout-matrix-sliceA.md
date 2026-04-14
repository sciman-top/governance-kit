# 2026-04-14 Phase4 Target Rollout Matrix SliceA

## task_snapshot
- goal: 落地“分发到目标仓”的 per-target rollout 状态矩阵与触发校验链。
- non_goal: 不直接推进任何控制到 enforce。
- acceptance:
  - `config/target-control-rollout-matrix.json` 覆盖当前 `distributable + progressive` 控制。
  - `check-target-rollout-matrix.ps1` 可计算缺口并输出计数。
  - `check-update-triggers` 接入 `target_rollout_matrix_gap`。
  - `run-recurring-review` 透传矩阵缺口计数。
  - 对应测试新增并通过。

## changed_artifacts
- config:
  - `config/target-control-rollout-matrix.json`
  - `config/update-trigger-policy.json`
  - `config/project-custom-files.json`
  - `config/governance-control-registry.json`
- scripts:
  - `scripts/governance/check-target-rollout-matrix.ps1`
  - `scripts/governance/check-update-triggers.ps1`
  - `scripts/governance/run-recurring-review.ps1`
- docs:
  - `docs/governance/target-rollout-status-matrix-2026Q2.md`
  - `docs/governance/control-plane-inventory-2026Q2.md`
  - `docs/governance/full-control-plane-governance-optimization-plan-2026Q2.md`
  - `docs/governance/rule-index.md`
- tests:
  - `tests/repo-governance-hub.optimization.tests.ps1`

## commands_and_results
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
  - exit_code: `0` (脚本返回 0，汇总含既有失败项)
  - key_output: `Passed: 142 Failed: 4`（新增 target rollout matrix 用例通过）
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
  - exit_code: `1`
  - key_output: `Repo path not found: E:/CODE/ClassroomToolkit`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
  - exit_code: `0`
  - key_output: `Config validation passed. repositories=3 targets=311 rolloutRepos=1`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
  - exit_code: `1`
  - key_output: `failed_steps=verify-kit,release-profile-coverage,verify-targets,growth-readiness-report`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
  - exit_code: `1`
  - key_output: `HEALTH=RED` + 外部仓路径缺失阻断
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-target-rollout-matrix.ps1 -RepoRoot . -AsJson`
  - exit_code: `0`
  - key_output: `distributable_progressive_control_count=5`, `missing_control_count=0`, `missing_repo_state_count=0`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-update-triggers.ps1 -RepoRoot . -AsJson`
  - exit_code: `1`
  - key_output: `target_rollout_matrix_missing_control_count=0`, `target_rollout_matrix_missing_repo_state_count=0`

## na_records
- type: `platform_na`
  - reason: 本机缺失 `E:/CODE/ClassroomToolkit`、`E:/CODE/skills-manager`，跨仓校验脚本阻断。
  - alternative_verification: 新增矩阵校验脚本 + trigger 计数 + 测试用例验证。
  - evidence_link: `docs/change-evidence/20260414-phase4-target-rollout-matrix-sliceA.md`
  - expires_at: `2026-04-30`

## rollback
- restore_entry: `powershell -File scripts/restore.ps1`
- minimal_rollback:
  - `git restore config/target-control-rollout-matrix.json config/update-trigger-policy.json config/project-custom-files.json config/governance-control-registry.json`
  - `git restore scripts/governance/check-target-rollout-matrix.ps1 scripts/governance/check-update-triggers.ps1 scripts/governance/run-recurring-review.ps1`
  - `git restore docs/governance/target-rollout-status-matrix-2026Q2.md docs/governance/control-plane-inventory-2026Q2.md`

## notes
- issue_id: phase4-target-rollout-matrix-sliceA
- clarification_mode: direct_fix
