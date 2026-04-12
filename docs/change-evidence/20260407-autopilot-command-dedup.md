# 20260407-autopilot-command-dedup

## 任务理解快照
- 目标: 去重 autopilot 脚本中的命令断言与日志执行器，实现公共复用。
- 非目标: 不改变 autopilot 的门禁顺序与策略语义。
- 验收标准: 两个 autopilot 入口可正常 dry-run；全门禁链路通过。
- 关键假设: `scripts/lib/common.ps1` 可作为跨脚本共享函数归宿（已确认）。

## 规则与风险
- rule_id: R1/R2/R6/R8
- risk_level: medium
- 变更类型: 重构去重 + source/target 一致性回灌

## 变更摘要
- 新增共享函数到 `scripts/lib/common.ps1`:
  - `Assert-Command`
  - `Invoke-LoggedCommand`
- 删除重复实现并改为复用:
  - `scripts/automation/run-safe-autopilot.ps1`
  - `scripts/governance/run-target-autopilot.ps1`
- 同步 source of truth 与目标仓:
  - `source/project/_common/custom/scripts/governance/run-target-autopilot.ps1`
  - `E:/CODE/skills-manager/scripts/governance/run-target-autopilot.ps1`

## 依据 -> 命令 -> 证据 -> 回滚
- 依据:
  - 两个 autopilot 脚本中 `Assert-Command`/`Invoke-LoggedCommand` 重复，存在维护漂移风险。
- 命令:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/automation/run-safe-autopilot.ps1 -RepoRoot . -DryRun -MaxCycles 1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-target-autopilot.ps1 -RepoRoot . -GovernanceRoot . -DryRun -MaxCycles 1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
- 关键输出:
  - 两条 dry-run 均成功。
  - 门禁最终全通过: `build/test/contract/hotspot` 全 `exit_code=0`。
  - 中途一次失败: `verify` 报告 source/target 分发不一致（`run-target-autopilot.ps1`），修复后复验通过。
- 回滚动作:
  - 回退文件:
    - `scripts/lib/common.ps1`
    - `scripts/automation/run-safe-autopilot.ps1`
    - `scripts/governance/run-target-autopilot.ps1`
    - `source/project/_common/custom/scripts/governance/run-target-autopilot.ps1`
  - 如需目录级回滚: `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`。

## 可观测性排障链
- 现象: `verify` 报 `[DIFF] source/project/_common/.../run-target-autopilot.ps1 != target`。
- 假设: 代码已改但未完成 source 与目标仓同步（已确认）。
- 验证命令: `powershell -File scripts/verify.ps1`。
- 预期结果: source 与目标一致后 `verify` 归零失败。
- 下一步: 修改涉及分发文件时，先同步 source，再一次性分发目标，减少中间态失败。

## learning_points_3
- 去重后若涉及分发链，必须同步 source 和所有受管目标仓。
- 将“执行器能力函数”放入公共库可显著降低脚本漂移。
- 先 dry-run 再全门禁可更快定位重构装配问题。

## reusable_checklist
- 去重前先识别是否为跨脚本公共能力。
- 抽取公共函数后，逐个脚本做 dry-run。
- 发现 verify diff 时优先判断是否 source/target 未同步。
- 修复后必须重跑完整门禁顺序。

## open_questions
- 是否继续第三批，将 `Resolve-KitRoot` 相关重复解析逻辑下沉到公共库。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
