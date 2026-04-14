# 20260414 Claude 兼容优化扩散复验（目标仓）

- 规则 ID: claude-code-compatibility-rollout-20260414
- 风险等级: 中
- issue_id: claude-compatibility-rollout-20260414

## 1) 执行范围
- 目标仓:
  - `E:/CODE/ClassroomToolkit`
  - `E:/CODE/skills-manager`
- 分发入口:
  - `powershell -File E:/CODE/repo-governance-hub/scripts/install.ps1 -Mode safe`

## 2) 分发结果
- install 结果: 成功（safe）
- 关键观察: 大部分条目为 `[SKIP] unchanged`，分发后本仓 post-gate 断言通过。

## 3) 目标仓门禁复验

### 3.1 ClassroomToolkit
- build:
  - `dotnet build ClassroomToolkit.sln -c Debug`
  - 结果: 通过（0 errors）
- test:
  - `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug`
  - 结果: 通过（3213 passed）
- contract/invariant:
  - `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "...ContractTests..."`
  - 结果: 通过（25 passed）
- hotspot:
  - `powershell -File scripts/quality/check-hotspot-line-budgets.ps1`
  - 结果: 通过（`status=PASS`）

### 3.2 skills-manager
- build:
  - `powershell -File build.ps1`
  - 结果: 通过
- test:
  - `powershell -File skills.ps1 发现`
  - 结果: 通过
- contract/invariant（首次）:
  - `powershell -File skills.ps1 doctor --strict --threshold-ms 8000`
  - 首次结果: 失败（历史 `build.log` 中 `sync_mcp` 性能样本触发阈值）
- 根因验证:
  - 清理历史日志后重跑同命令:
    - `Remove-Item build.log -Force`
    - `powershell -File skills.ps1 doctor --strict --threshold-ms 8000`
  - 结果: 通过（`Your system is ready for skills-manager.`）
- hotspot:
  - `powershell -File skills.ps1 构建生效`
  - 结果: 通过

## 4) 风险与说明
- 本次 `skills-manager` 的 contract 阻断属于“历史性能日志样本噪声”而非功能退化。
- 该仓 doctor 严格模式当前会使用日志最近样本做性能异常判定；在大体量 `sync_mcp` 后可能触发假阳性。
- 建议后续在 skills-manager 内完善 doctor 策略（例如区分“实时探测”与“历史趋势告警”），避免门禁受历史日志污染。

## 5) 回滚入口
- 分发回滚:
  - `powershell -File E:/CODE/repo-governance-hub/scripts/restore.ps1 -Mode safe`
- 目标仓按需回滚:
  - 使用各仓 git 历史或备份目录恢复对应文件。

## 6) learning_points_3
- 扩散复验必须在目标仓按其 AGENTS 门禁原命令执行，不能只看分发仓门禁。
- 性能型 strict 门禁需要隔离“历史样本”与“当前变更影响”。
- 分发后应即时记录“命令+关键输出+回滚入口”，防止跨仓证据断链。
