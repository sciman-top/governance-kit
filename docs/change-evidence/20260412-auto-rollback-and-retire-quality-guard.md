# 2026-04-12 Auto Rollback + Retire Quality Guard

## task_understanding_snapshot
- goal: 完成 `P1-06 Auto-rollback Trigger Hardening` 与 `P2-05 Candidate Retirement Quality Guard`，实现可自动触发的回滚路径与退役质量守卫。
- non_goal: 不改动 promotion/create 主流程判定，不引入新外部依赖。
- acceptance: 回归测试覆盖新行为；`build -> test -> contract/invariant -> hotspot` 通过。
- key_assumptions:
  - 已确认：`run-recurring-review.ps1` 是 weekly 入口，适合承载自动回滚触发汇总字段。
  - 已确认：`run-skill-lifecycle-review.ps1` 是 retire 执行入口，适合承载 replacement/fallback 守卫。

## change_scope
- rule_ids: `P1-06`, `P2-05`
- risk_tier: medium
- active_rule_path: `E:/CODE/repo-governance-hub/AGENTS.md`
- source_of_truth:
  - `source/project/repo-governance-hub/custom/scripts/governance/run-recurring-review.ps1`
  - `source/project/_common/custom/scripts/governance/run-skill-lifecycle-review.ps1`
  - `source/project/_common/custom/.governance/*.json`

## changes
- P1-06:
  - 新增策略文件：
    - `.governance/auto-rollback-trigger-policy.json`
    - `source/project/_common/custom/.governance/auto-rollback-trigger-policy.json`
  - `run-recurring-review.ps1` 增加：
    - 自动回滚触发策略读取（token balance / trigger eval / high-risk / external baseline）。
    - `auto_rollback_*` summary 字段、snapshot 字段、控制台输出字段。
    - 自动回滚触发告警与动作判定（进入 `run-rollback-drill` 路径）。
- P2-05:
  - `run-skill-lifecycle-review.ps1` 增加 retire 守卫：
    - `require_replacement_coverage`
    - `minimum_active_replacements`
    - `require_rollback_fallback`
  - 新增 `retire_blocked_candidates` 输出，safe retire 回写：
    - `retired_replacement_evidence`
    - `retired_rollback_fallback`
  - 策略增强：
    - `.governance/skill-lifecycle-policy.json`
    - `source/project/_common/custom/.governance/skill-lifecycle-policy.json`
- 稳定性修复：
  - `check-anti-bloat-budgets.ps1` 对非法路径字符增加容错，避免 `Test-Path` 因异常字符中断门禁。

## tests_and_verification
- 命令：
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -File scripts/install.ps1 -Mode safe`
  - `powershell -File scripts/verify-kit.ps1`
  - `powershell -File scripts/validate-config.ps1`
  - `powershell -File scripts/verify.ps1`
  - `powershell -File scripts/doctor.ps1`
- 关键结果：
  - 新增用例通过：
    - `run-recurring-review triggers auto rollback path on token balance regression`
    - `run-skill-lifecycle-review enforces replacement coverage and rollback fallback for retire`
  - `install -Mode safe` post-gate 通过。
  - `doctor` 输出 `HEALTH=GREEN`。
- residual_test_gap:
  - 现有历史测试 `verify can skip validate-config when explicitly requested` 在该仓当前基线上仍显示失败输出，但本次变更未触及该逻辑，且门禁出口状态仍通过。

## observable_signals
- `docs/governance/alerts-latest.md` 新增 `auto_rollback_*` 观测字段。
- lifecycle review JSON 新增：
  - `retire_require_replacement_coverage`
  - `retire_require_rollback_fallback`
  - `retire_blocked_candidate_count`
  - `retire_blocked_candidates`

## rollback
- entrypoint: `scripts/restore.ps1` + `backups/<timestamp>/`
- minimal rollback actions:
  - 回退 `run-recurring-review.ps1`、`run-skill-lifecycle-review.ps1`、新增策略文件与 policy 字段。
  - 重新执行 `scripts/install.ps1 -Mode safe` 同步落点。
  - 重跑 `verify-kit -> tests -> validate-config/verify -> doctor`。

## terminology_explanation
- auto rollback trigger: 当质量/安全 KPI 触发阈值时，系统自动标记进入回滚路径的机制。
- replacement coverage: retire 前需证明有可用替代家族处于 active/approved，避免能力断档。
- rollback fallback: retire 条目必须保留可回退方案描述，保证可恢复。

## learning_points_3
- 在 StrictMode 下访问可选属性必须先判定 `PSObject.Properties`，否则会触发运行时错误。
- 门禁脚本对路径解析要做异常容错，否则会因脏工作区中的异常路径字符中断流程。
- 退役流程质量守卫应同时包含“替代证明”和“回退手段”，仅凭 inactivity 不足以保证安全退役。

## reusable_checklist
- [x] source of truth 与目标落点同步更新
- [x] 新策略文件加入 `config/project-custom-files.json`
- [x] 新字段同步到 summary/snapshot/console 三个观测面
- [x] 正反向回归测试覆盖
- [x] 门禁顺序全链路验证

## open_questions
- 是否需要把 `run-recurring-review` 的 auto rollback action 扩展为真实 `restore` 预演（当前为回滚路径进入信号 + drill）？
