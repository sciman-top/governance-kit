# 2026-04-14 Rollout Metadata Coverage Trigger Phase0

## task_snapshot
- goal: 在本仓与分发脚本链路中新增 `rollout_metadata_coverage_gap` 触发器，覆盖 `repositories.json` 与 `rule-rollout.json` 的元数据缺口告警。
- non_goal: 不修改 rollout 策略业务语义，不调整硬门禁顺序。
- acceptance:
  - `check-update-triggers.ps1` 可产出 `rollout_metadata_coverage_gap_count` 与 `rollout_metadata_orphan_count`。
  - `run-recurring-review.ps1` summary 与 alerts snapshot 透传上述字段。
  - 对应脚本分发镜像与测试用例同步更新。
- assumptions:
  - 已确认：当前仓允许先在 source of truth 修复后再分发镜像。
  - 未确认：外部路径仓（ClassroomToolkit/skills-manager）在本机是否完整可访问。

## rule_binding
- global_rule_refs: `R1,R2,R6,R8,E2,E4`
- repo_landing:
  - `config/update-trigger-policy.json`
  - `scripts/governance/check-update-triggers.ps1`
  - `scripts/governance/run-recurring-review.ps1`
  - `scripts/governance/check-rollout-coverage.ps1`
  - mirrors under `source/project/*/custom/scripts/governance/`
  - `tests/repo-governance-hub.optimization.tests.ps1`

## commands_and_results
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
  - exit_code: `1` (脚本链路阻断)
  - key_output: `Repo path not found: E:/CODE/ClassroomToolkit`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
  - exit_code: `0` (测试脚本返回 0，但测试汇总存在失败)
  - key_output: `Passed: 139 Failed: 4`（包含既有基线失败项，不由本次改动引入）
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
  - exit_code: `0`
  - key_output: `Config validation passed. repositories=3 targets=311 rolloutRepos=1`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
  - exit_code: `1` (门禁红灯)
  - key_output: `failed_steps=verify-kit,release-profile-coverage,verify-targets,growth-readiness-report`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
  - exit_code: `1` (门禁红灯)
  - key_output: `HEALTH=RED` + 外部仓路径缺失阻断

## targeted_smoke
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-update-triggers.ps1 -RepoRoot <tmp> -AsJson`
  - observed: `rollout_metadata_coverage_gap_count=2`、`rollout_metadata_orphan_count=0`、`alerts contains rollout_metadata_coverage_gap`
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-recurring-review.ps1 -RepoRoot <tmp> -AsJson`
  - observed: summary 包含 `rollout_metadata_coverage_gap_count` 与 `rollout_metadata_orphan_count`

## na_records
- type: `platform_na`
  - reason: 本机缺失目标仓路径 `E:/CODE/ClassroomToolkit`、`E:/CODE/skills-manager`，导致 verify-kit/verify/doctor 跨仓校验阻断。
  - alternative_verification: 执行 `validate-config`、新增触发器单元测试、tmp 场景 smoke。
  - evidence_link: `docs/change-evidence/20260414-rollout-metadata-coverage-trigger-phase0.md`
  - expires_at: `2026-04-30`

## tracked_files_policy
- cmd: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-tracked-files.ps1 -Scope pending -AsJson`
- result: `blocked=false`、`review_required_hits=[]`、`test_file_suggestions.total=0`

## rollback
- restore_entry: `powershell -File scripts/restore.ps1`
- scope:
  - remove `check-rollout-coverage.ps1` from root + mirror paths
  - revert trigger additions in update policy / trigger runner / recurring review / tests

## notes
- clarification_mode: direct_fix
- issue_id: rollout-metadata-coverage-trigger-phase0
- commit_scope: 仅纳入“rollout 元数据覆盖缺口触发链”相关文件，不纳入历史在制改动。
