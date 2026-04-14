# 2026-04-14 Phase2 Evidence Standardization Trigger

## task_snapshot
- goal: 将 Phase2 “证据字段标准化”落地为机器可检触发链，并补充周检控制面摘要字段。
- non_goal: 不调整硬门禁顺序，不提升 progressive 控制到 enforce。
- acceptance:
  - `docs/change-evidence/template.md` 包含 Phase2 必填字段。
  - `check-update-triggers` 增加 `evidence_template_fields_missing` 触发。
  - `run-recurring-review` 输出控制面摘要字段（top noisy / bypassed advisories）。
  - 新增测试覆盖对应触发。

## changed_artifacts
- docs:
  - `docs/change-evidence/template.md`
  - `docs/governance/metrics-template.md`
  - `docs/governance/control-plane-inventory-2026Q2.md`
  - `docs/governance/full-control-plane-governance-optimization-plan-2026Q2.md`
- config:
  - `config/update-trigger-policy.json`
  - `config/project-custom-files.json`
  - `config/governance-control-registry.json`
- scripts:
  - `scripts/governance/check-evidence-template-fields.ps1`
  - `scripts/governance/check-update-triggers.ps1`
  - `scripts/governance/run-recurring-review.ps1`
  - mirrored scripts under `source/project/*/custom/scripts/governance/`
- tests:
  - `tests/repo-governance-hub.optimization.tests.ps1`

## commands_and_results
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
  - exit_code: `0` (脚本返回 0，汇总保留既有失败项)
  - key_output: `Passed: 141 Failed: 4`（新增 `evidence template fields missing` 用例通过）
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
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-update-triggers.ps1 -RepoRoot . -AsJson`
  - exit_code: `1`
  - key_output: `evidence_template_missing_field_count=0`, `alert_count=5`, `steps includes evidence-template-fields`

## na_records
- type: `platform_na`
  - reason: 本机缺失 `E:/CODE/ClassroomToolkit`、`E:/CODE/skills-manager`，跨仓校验脚本阻断。
  - alternative_verification: 新增触发器测试通过 + `validate-config` 通过 + 触发链 smoke。
  - evidence_link: `docs/change-evidence/20260414-phase2-evidence-standardization-trigger.md`
  - expires_at: `2026-04-30`

## rollback
- restore_entry: `powershell -File scripts/restore.ps1`
- minimal_rollback:
  - `git restore docs/change-evidence/template.md docs/governance/metrics-template.md`
  - `git restore config/update-trigger-policy.json config/project-custom-files.json config/governance-control-registry.json`
  - `git restore scripts/governance/check-evidence-template-fields.ps1 scripts/governance/check-update-triggers.ps1 scripts/governance/run-recurring-review.ps1`

## notes
- issue_id: phase2-evidence-standardization-trigger
- clarification_mode: direct_fix
