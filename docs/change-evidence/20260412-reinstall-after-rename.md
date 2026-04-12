# 2026-04-12 一键安装重分发（目录重命名后）

- issue_id: reinstall-after-rename-20260412
- current_landing: E:/CODE/repo-governance-hub
- target_destination: 通过 `scripts/install.ps1` 将规则与自定义文件重新安装/分发到已登记目标仓（ClassroomToolkit、skills-manager）
- risk_level: medium
- clarification_mode: direct_fix

## 任务理解快照
- 目标：在仓库改名后，重新完成一键安装分发，并确保目标仓可执行门禁链路无断裂。
- 非目标：不做与本次改名无关的大规模业务重构。
- 验收标准：安装脚本成功、主仓后置门禁通过、目标仓硬门禁通过、发现的可确定错误即时修复并复验。
- 关键假设（已确认）：`scripts/install.ps1` 是本仓“一键安装”入口，默认先刷新 targets 后分发。

## 依据 -> 命令 -> 证据

### 1) 一键安装分发（safe）
- command: `powershell -File scripts/install.ps1 -Mode safe -ShowScope`
- key_output:
  - `targets.count=232`
  - `Verify done. ok=232 fail=0`
  - `[ASSERT] post-gate full chain passed`
  - `HEALTH=GREEN`

### 2) 只读预演统计（plan）
- command: `powershell -File scripts/install.ps1 -Mode plan -AsJson`
- key_output:
  - `copied=0`
  - `skipped=232`
  - `mode=plan`

### 3) 目标仓硬门禁复验（ClassroomToolkit）
- commands:
  - `dotnet build ClassroomToolkit.sln -c Debug`
  - `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug`
  - `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "...Contract..."`
  - `powershell -File scripts/quality/check-hotspot-line-budgets.ps1`
- key_output:
  - build `0 error / 0 warning`
  - test passed `3213`
  - contract/invariant passed `25`
  - hotspot `status=PASS`

### 4) 目标仓硬门禁复验（skills-manager）
- commands:
  - `powershell -File build.ps1`
  - `powershell -File skills.ps1 发现`
  - `powershell -File skills.ps1 doctor --strict --threshold-ms 8000`
  - `powershell -File skills.ps1 构建生效`
- key_output:
  - build success
  - doctor: `Your system is ready for skills-manager.`
  - 构建生效流程完成（含多平台 skills 链接重建）

### 5) 发现并修复的问题（即时）
- finding:
  - `E:/CODE/ClassroomToolkit/scripts/automation/run-safe-autopilot.ps1` 仍硬编码旧路径，重命名后会导致缺脚本报错。
- fix:
  - 默认参数改为 `E:/CODE/repo-governance-hub`
  - 缺失脚本报错改为基于 `$kitPath` 动态拼接
- verification:
  - `powershell -File scripts/automation/run-safe-autopilot.ps1 -DryRun -SkipTaskLoop -SkipQualityGates -SkipGovernanceCycle`
  - 输出 `governance_kit_root: E:\CODE\repo-governance-hub`

### 6) 平台取证（Codex）
- command: `codex --version`
  - exit_code: 0
  - key_output: `codex-cli 0.120.0`
- command: `codex --help`
  - exit_code: 0
- command: `codex status`
  - exit_code: 1
  - na_type: platform_na
  - reason: `stdin is not a terminal`
  - alternative_verification: `codex --version` + `codex --help`
  - evidence_link: 本文件
  - expires_at: 2026-04-30

## 可观测信号与排障路径
- 现象：治理周期脚本在目标仓报 preflight dirty entries。
- 假设：目标仓有既存改动，触发保护阈值。
- 验证：执行 `run-project-governance-cycle.ps1` 得到明确 preflight block。
- 决策：不做破坏性清理，改为直接按目标仓 AGENTS 定义执行硬门禁验证。
- 结果：两目标仓硬门禁均通过；已修复改名导致的已确认断点。

## 回滚动作
- 分发回滚：`powershell -File scripts/restore.ps1 -BackupDir backups/<timestamp>`
- 目标仓脚本修复回滚：恢复 `E:/CODE/ClassroomToolkit/scripts/automation/run-safe-autopilot.ps1` 到修复前版本并重跑 DryRun。

## learning_points_3
- 改名场景除分发映射外，还需扫描目标仓自动化脚本的硬编码根路径。
- 目标仓 preflight 脏工作区保护会阻止周期脚本，需改用非破坏式门禁复验链路兜底。
- `codex status` 在非交互会话触发 `stdin is not a terminal`，应按 `platform_na` 固化替代证据。

## reusable_checklist
- 跑 `install.ps1 -Mode safe` 后补跑 `install.ps1 -Mode plan -AsJson` 取统计。
- 对每个目标仓按其 AGENTS 的 `build -> test -> contract/invariant -> hotspot` 复验。
- 扫描 `scripts/config/src` 中旧仓名硬编码并逐项 DryRun 验证。

## open_questions
- 是否需要将 `ClassroomToolkit/scripts/automation/run-safe-autopilot.ps1` 纳入 repo-governance-hub 的分发清单，避免未来再次漂移。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
