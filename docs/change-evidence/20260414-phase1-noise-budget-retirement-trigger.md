# 2026-04-14 Phase1 Noise Budget + Retirement Trigger

## task_snapshot
- goal: 完成全控制面治理计划 Phase1 缺口，新增噪音预算基线与退役候选可观测触发链。
- non_goal: 不改变硬门禁顺序，不将新增 progressive 控制直接升级为 enforce。
- acceptance:
  - 新增 `governance-noise-budget.md` 与首版退役候选清单。
  - `check-update-triggers` 增加 `control_retirement_backlog` 触发。
  - `run-recurring-review` / `alerts-latest` 可透传退役候选计数。
  - 对应测试新增并通过。

## changed_artifacts
- docs:
  - `docs/governance/governance-noise-budget.md`
  - `docs/governance/control-retirement-candidates-2026Q2.md`
  - `docs/governance/full-control-plane-governance-optimization-plan-2026Q2.md`
  - `docs/governance/control-plane-inventory-2026Q2.md`
  - `docs/governance/rule-index.md`
- config:
  - `config/control-retirement-candidates.json`
  - `config/update-trigger-policy.json`
  - `config/governance-control-registry.json`
- scripts:
  - `scripts/governance/check-control-retirement-candidates.ps1`
  - `scripts/governance/check-update-triggers.ps1`
  - `scripts/governance/run-recurring-review.ps1`
  - mirrored scripts under `source/project/*/custom/scripts/governance/`
- tests:
  - `tests/repo-governance-hub.optimization.tests.ps1`

## commands_and_results
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
  - exit_code: `0` (脚本返回 0，测试汇总含既有失败)
  - key_output: `Passed: 140 Failed: 4`（新增 `check-update-triggers reports control retirement backlog` 通过）
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
  - key_output: `HEALTH=RED` + 外部仓路径缺失导致阻断
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-update-triggers.ps1 -RepoRoot . -AsJson`
  - exit_code: `1`
  - key_output: `control_retirement_active_candidate_count=2`, `control_retirement_overdue_candidate_count=0`, `alert_count=5`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson`
  - exit_code: `1`
  - key_output: `update_trigger_alert_count=5`, `cross_repo_compatibility_repo_failure_count=2`

## na_records
- type: `platform_na`
  - reason: 本机缺失 `E:/CODE/ClassroomToolkit` 与 `E:/CODE/skills-manager`，跨仓校验脚本出现路径缺失阻断。
  - alternative_verification: 新增触发器测试通过 + `validate-config` 通过 + `check-update-triggers` 退役候选告警路径 smoke。
  - evidence_link: `docs/change-evidence/20260414-phase1-noise-budget-retirement-trigger.md`
  - expires_at: `2026-04-30`

## rollback
- restore_entry: `powershell -File scripts/restore.ps1`
- minimal_rollback:
  - `git restore config/control-retirement-candidates.json config/update-trigger-policy.json config/governance-control-registry.json`
  - `git restore scripts/governance/check-control-retirement-candidates.ps1 scripts/governance/check-update-triggers.ps1 scripts/governance/run-recurring-review.ps1`
  - `git restore docs/governance/governance-noise-budget.md docs/governance/control-retirement-candidates-2026Q2.md`

## notes
- issue_id: phase1-noise-budget-retirement-trigger
- clarification_mode: direct_fix
