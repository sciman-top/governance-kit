# 20260414 Agent Runtime Task1-3 And Backflow

## Goal
- 执行 `agent runtime` 实施计划的 Task 1-3：
  - runtime policy skeleton 落地
  - validate-config 接入 runtime 必填段校验
  - runtime baseline checker 落地并接入 verify-kit
- 修复 `verify-targets` 阻断：回灌 `skills-manager/scripts/prebuild-check.ps1` 的漂移改动到本仓 source。

## Non-goal
- 本轮不推进 Task 4+（metrics-template、recurring review、doctor runtime summary 的结构化扩展）。
- 本轮不处理工作区中与本任务无关的既有变更。

## Basis
- 实施计划：`docs/superpowers/plans/2026-04-14-agent-runtime-baseline.md`
- 阻断现象：`scripts/verify.ps1` 报 `source/project/skills-manager/custom/scripts/prebuild-check.ps1` 与目标仓同路径文件不一致。

## Changes
- Updated `config/agent-runtime-policy.json`
  - 保留兼容字段：`enabled_by_default/default_files/repos`
  - 新增 runtime 段：`mode`、`prompt_registry`、`tool_contracts`、`context_management`、`memory_policy`、`agent_evals`、`agent_observability`、`cost_controls`、`observe_to_enforce`
- Updated `scripts/validate-config.ps1`
  - 在 `agent-runtime-policy.json` 路径下新增必填段与 `mode` 值校验
- Added `scripts/governance/check-agent-runtime-baseline.ps1`
  - 输出 `PASS/WARN` 的 runtime 基线检查结果（支持 `-AsJson`）
- Updated `scripts/verify-kit.ps1`
  - 接入 runtime baseline checker 并输出摘要字段（advisory，不阻断）
- Updated `tests/repo-governance-hub.optimization.tests.ps1`
  - 新增 `validate-config fails when agent runtime policy is missing required sections`
  - 新增 `check-agent-runtime-baseline reports WARN for missing sections and PASS when complete`
- Updated `source/project/skills-manager/custom/scripts/prebuild-check.ps1`
  - 回灌目标仓已存在改动：进程占用检测排除当前会话自身进程链路

## Commands
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/governance/check-agent-runtime-baseline.ps1 -RepoRoot . -AsJson`
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1`

## Verification
- `validate-config`: PASS
- `check-agent-runtime-baseline -AsJson`: `status=PASS`, `warning_count=0`
- `verify-kit`: PASS（包含 `agent_runtime_baseline.status=PASS` 输出）
- `tests`: `Passed: 148 Failed: 0`
- `verify`: `Verify done. ok=324 fail=0`
- `doctor`: `HEALTH=GREEN`

## Observability Notes
- `verify-kit` 仍会输出 `_common` baseline 非阻断告警（`actionable_violation_count=0`）。
- `verify/doctor` 仍会输出既有 advisory：`metrics-auto.md` 缺失、`token_efficiency_trend.status=missing_metric`。

## Risks
- 当前 runtime policy 采用“兼容旧字段 + 新字段”双轨，后续需要决定是否收敛为单轨结构。
- runtime checker 目前仅做基线存在性检查，后续需与 recurring review/doctor 更深集成以避免指标口径漂移。

## Rollback
- 回滚入口：
  - `git restore config/agent-runtime-policy.json scripts/validate-config.ps1 scripts/verify-kit.ps1 tests/repo-governance-hub.optimization.tests.ps1 scripts/governance/check-agent-runtime-baseline.ps1 source/project/skills-manager/custom/scripts/prebuild-check.ps1`
  - 或使用 `scripts/restore.ps1 + backups/<timestamp>/`

## issue_id / clarification_mode
- `issue_id`: `agent-runtime-task1-3-20260414`
- `attempt_count`: `1`
- `clarification_mode`: `direct_fix`
- `clarification_scenario`: `bugfix`
- `clarification_questions`: `[]`
- `clarification_answers`: `[]`

## learning_points_3
- 在本仓新增运行时治理能力时，优先兼容 `Resolve-AgentRuntimePolicyPath` 现有链路可以降低回归风险。
- `verify-targets` 的跨仓漂移应优先回灌 source-of-truth，再重跑整链路，避免临时绕过。
- 将 runtime checker 先以 advisory 接入 `verify-kit`，能在不改变阻断语义下快速建立可观测性。

## reusable_checklist
- runtime policy 是否兼容现有路径解析
- validate-config 是否区分 agent/legacy runtime policy 语义
- verify-kit 新增检查是否保持 advisory
- tests 是否覆盖 WARN/PASS 两类 runtime checker 输出
- verify/doctor 是否在最终状态恢复为绿色

## open_questions
- 后续是否弃用 `codex-runtime-policy` 命名并收敛到统一 runtime schema
- runtime checker 输出是否应进入 `doctor -AsJson` 的固定结构字段
