# 20260407-cli-common-load-guard-and-capture-test

## 任务理解快照
- 目标: 提升 CLI 诊断脚本稳健性，并为 `Invoke-CommandCapture` 增加回归测试。
- 非目标: 不改变 CLI 诊断脚本对外参数与报告结构。
- 验收标准: 新增加载保护与测试后，全门禁保持通过。

## 变更内容
- `scripts/check-cli-capabilities.ps1`
  - 增加 `common.ps1` 缺失时的显式报错保护。
- `scripts/check-cli-version-drift.ps1`
  - 增加 `common.ps1` 缺失时的显式报错保护。
- `tests/repo-governance-hub.optimization.tests.ps1`
  - 新增 `common Invoke-CommandCapture returns stable fields for success and failure probes`。
  - 修正失败路径断言为“非 0 即失败”（避免环境差异导致误判）。

## 命令与结果
- `powershell -File scripts/verify-kit.ps1` -> pass
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> pass
- `powershell -File scripts/validate-config.ps1` -> pass
- `powershell -File scripts/verify.ps1` -> pass
- `powershell -File scripts/doctor.ps1` -> pass

## 回滚
- 回滚文件:
  - `scripts/check-cli-capabilities.ps1`
  - `scripts/check-cli-version-drift.ps1`
  - `tests/repo-governance-hub.optimization.tests.ps1`
- 全量回滚入口:
  - `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## learning_points_3
- 公共依赖加载失败应尽早以明确错误暴露，避免后续隐式异常。
- 命令捕获类函数的失败断言需允许跨环境差异（非 0 语义优先于固定数值）。
- 先补测试再演进公共函数，可显著降低回归概率。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
