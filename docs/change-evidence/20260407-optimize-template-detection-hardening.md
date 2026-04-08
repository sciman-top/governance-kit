# 20260407-optimize-template-detection-hardening

## 任务理解快照
- 目标: 修复 `optimize-project-rules.ps1` 将模板文档误判为 custom 文档并跳过更新的问题。
- 非目标: 不修改 C2/C3/C7/C8 语义内容，仅增强匹配鲁棒性。
- 验收标准: `optimize-project-rules` 相关测试恢复通过，且全门禁链路保持通过。

## 变更内容
- `scripts/optimize-project-rules.ps1`
  - 放宽模板识别正则:
    - 允许可变空白
    - 允许 `N/A` 与 `NA` 写法
    - 启用大小写不敏感匹配
  - 同步放宽 C2/C3/A3 替换段正则，避免因为轻微格式差异跳过替换。
- `tests/governance-kit.optimization.tests.ps1`
  - `optimize-project-rules` 用例改为同进程直接调用脚本，减少子进程 `LASTEXITCODE` 不确定性。

## 关键现象与修复
- 现象:
  - 测试中出现 `[SKIP] custom-optimized doc preserved ...`，导致断言失败。
- 根因:
  - 模板识别条件对标题格式过于严格，误将模板文件判定为 custom。
- 修复:
  - 正则放宽到“语义匹配而非字面匹配”。

## 命令与结果
- `powershell -File tests/governance-kit.optimization.tests.ps1` -> pass（目标用例恢复通过）
- 全门禁:
  - `powershell -File scripts/verify-kit.ps1` -> pass
  - `powershell -File tests/governance-kit.optimization.tests.ps1` -> pass
  - `powershell -File scripts/validate-config.ps1` -> pass
  - `powershell -File scripts/verify.ps1` -> pass
  - `powershell -File scripts/doctor.ps1` -> pass

## 回滚
- 回滚文件:
  - `scripts/optimize-project-rules.ps1`
  - `tests/governance-kit.optimization.tests.ps1`
- 全量回滚入口:
  - `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## learning_points_3
- 模板识别规则应优先“容忍格式差异”，避免误跳过核心治理更新。
- 子进程退出码在测试里可能掩盖真实执行态，关键路径更适合同进程调用。
- 发现潜在失败被掩盖时，应先让失败可见，再做根因修复。
