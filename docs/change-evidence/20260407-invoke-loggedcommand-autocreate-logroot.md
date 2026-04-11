# 20260407-invoke-loggedcommand-autocreate-logroot

## 任务理解快照
- 目标: 增强 `Invoke-LoggedCommand` 健壮性，避免日志目录不存在导致调用失败。
- 非目标: 不改变日志格式、不改变退出码语义。
- 验收标准: 新增自动建目录能力后测试通过且全门禁通过。

## 变更内容
- `scripts/lib/common.ps1`
  - 在 `Invoke-LoggedCommand` 中新增 `LogRoot` 目录存在性检查与自动创建。
- `tests/repo-governance-hub.optimization.tests.ps1`
  - 新增测试: `common Invoke-LoggedCommand creates missing log directory automatically`。

## 命令与结果
- `powershell -File scripts/verify-kit.ps1` -> pass
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> pass
- `powershell -File scripts/validate-config.ps1` -> pass
- `powershell -File scripts/verify.ps1` -> pass
- `powershell -File scripts/doctor.ps1` -> pass

## 回滚
- 回滚文件:
  - `scripts/lib/common.ps1`
  - `tests/repo-governance-hub.optimization.tests.ps1`
- 全量回滚入口:
  - `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## learning_points_3
- 公共执行器应默认容错目录准备，减少调用方负担。
- 增强公共函数后应立即补“负路径/边界”测试。
- 每批改动后全门禁复验可以及时发现分发链或契约回归。
