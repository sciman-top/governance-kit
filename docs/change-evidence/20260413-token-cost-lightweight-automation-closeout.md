# 20260413 Token Cost Lightweight Automation Closeout

## task_snapshot
- goal: 按“先清单、再编码”完成 token 降本轻量任务并自动连续执行到可验证闭环。
- non_goal: 不引入 RTK/tokf 为硬依赖，不改动硬门禁顺序与阻断语义。

## changes
- docs:
  - `docs/governance/token-cost-lightweight-checklist.md`（状态更新为已完成/进行中）
  - `docs/governance/rule-index.md`（新增清单入口）
- scripts:
  - `scripts/governance/invoke-output-filter-wrapper.ps1`（输出过滤 advisory/raw 包装器）
  - `scripts/governance/check-session-compaction-trigger.ps1`（会话压缩触发判定）
  - `scripts/governance/run-recurring-review.ps1`（接入 compaction 与质量/成本并排摘要）
- policy:
  - `.governance/session-compaction-trigger-policy.json`
- source-of-truth:
  - 对应文件同步落点：`source/project/repo-governance-hub/custom/*`
  - 映射更新：`config/targets.json`、`config/project-custom-files.json`

## verification
- build:
  - `powershell -File scripts/verify-kit.ps1` => pass
- test:
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1` => pass
- contract/invariant:
  - `powershell -File scripts/validate-config.ps1` => pass
  - `powershell -File scripts/verify.ps1` => pass
- hotspot:
  - `powershell -File scripts/doctor.ps1` => `HEALTH=GREEN`
- feature checks:
  - `powershell -File scripts/governance/check-session-compaction-trigger.ps1 -RepoRoot . -AsJson` => `status=ok`
  - `powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -NoNotifyOnAlert` => `result=OK`
  - `powershell -File scripts/governance/invoke-output-filter-wrapper.ps1 -RepoRoot . -ScriptPath scripts/verify-kit.ps1 -Mode advisory` => `exit_code=0` + raw log path generated

## risks_and_followups
- `token_efficiency_trend.status=insufficient_history`（当前样本不足）为观察项，不阻断。
- `上下文缩减（MCP按任务启停）` 与 `成本参数（reasoning/verbosity/max_output_tokens）` 仍属于运行时策略项，需在会话/平台侧持续执行。

## rollback
- 代码回滚：
  - `git restore docs/governance/token-cost-lightweight-checklist.md docs/governance/rule-index.md`
  - `git restore scripts/governance/run-recurring-review.ps1 scripts/governance/check-session-compaction-trigger.ps1 scripts/governance/invoke-output-filter-wrapper.ps1`
  - `git restore .governance/session-compaction-trigger-policy.json config/targets.json config/project-custom-files.json`
- 分发回滚：
  - `powershell -File scripts/restore.ps1`（按快照恢复）

