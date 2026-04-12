# 2026-04-13 Skill Naming Canonicalization + UTF-8 Guard Check

## task_snapshot
- goal: 确认本仓是否已有 PowerShell UTF-8 中文编码强化，并修复 `custom-auto-*` 命名可读性（去除 `...-l-<hash>` 半截词问题）。
- non_goal: 不改变 skill promotion 的触发阈值、门禁顺序、外部行为契约。
- acceptance:
  - 命名从 token 边界生成，避免半截词。
  - 旧命名目录可自动迁移到新 canonical 命名，不被直接清理。
  - 硬门禁 `build -> test -> contract/invariant -> hotspot` 通过。

## basis
- user_report: `custom-auto-pwsh-encoding-mojibake-l-a9b049cd` 后缀可读性差。
- root_cause: `ConvertTo-Slug` 固定 24 字符硬截断，导致 `pwsh-encoding-mojibake-loop` 被截成 `pwsh-encoding-mojibake-l`。

## changes
- scripts:
  - `source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1`
  - `scripts/governance/promote-skill-candidates.ps1`
  - `source/project/_common/custom/scripts/governance/migrate-skill-registry-v2.ps1`
  - `scripts/governance/migrate-skill-registry-v2.ps1`
- behavior:
  - slug 生成改为 token 边界截断（默认长度上限 32）。
  - canonical slug 种子先去除尾部日期段（`-\d{8}`），hash 仍基于 family signature，保证稳定性。
  - cleanup 阶段新增“重命名优先”迁移逻辑；仅在 canonical 目录已存在冲突时删除旧目录。
  - 新增诊断输出字段：`cleanup_renamed_count`、`cleanup_renamed`。
- tests:
  - `tests/repo-governance-hub.optimization.tests.ps1`
  - 新增用例：`promote-skill-candidates renames legacy truncated custom-auto directory to canonical name`。

## utf8_guard_check
- confirmed_files:
  - `scripts/collect-governance-metrics.ps1`（UTF-8 no BOM/CJK 解析与 fallback 已在位）
  - `scripts/lib/common.ps1`（UTF-8 JSON/Text helper）
  - `source/project/skills-manager/custom/overrides/custom-windows-encoding-guard/scripts/bootstrap.ps1`
- conclusion: 本仓与联动仓已存在 PowerShell UTF-8 中文编码强化能力，本次未新增该类逻辑。

## verification
- build:
  - `powershell -File scripts/verify-kit.ps1` -> pass
- test:
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> pass (包含新增回归用例)
- contract/invariant:
  - `powershell -File scripts/validate-config.ps1` -> pass
  - `powershell -File scripts/verify.ps1` -> pass
- hotspot:
  - `powershell -File scripts/doctor.ps1` -> pass (`HEALTH=GREEN`)

## risks_and_rollback
- risk:
  - 分发后会同步更新外部仓中的同名脚本，属于受控中风险写入。
- rollback:
  - `powershell -File scripts/restore.ps1`
  - 或从 `backups/<timestamp>/` 回退对应脚本文件。

## trace
- issue_id: `skill-name-readability-pwsh-encoding-20260413`
- attempt_count: 1
- clarification_mode: `direct_fix`
- learning_points_3:
  - token 边界截断优于字符硬截断，能显著提升命名可读性。
  - canonical 变更必须配套迁移策略，否则 cleanup 会误删历史目录。
  - hash 维持 family 口径可保证命名稳定并避免跨日漂移。
