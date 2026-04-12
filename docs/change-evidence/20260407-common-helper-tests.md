# 20260407-common-helper-tests

## 任务理解快照
- 目标: 为新抽取的公共函数补回归测试，提升长期维护稳健性。
- 非目标: 不调整业务流程，不引入新门禁语义。
- 验收标准: 新测试通过且全门禁保持全绿。

## 变更内容
- 在 `tests/repo-governance-hub.optimization.tests.ps1` 新增:
  - `common Assert-Command and Invoke-LoggedCommand provide shared command guards`
- 覆盖点:
  - `Assert-Command` 的存在/缺失命令判定。
  - `Invoke-LoggedCommand` 的日志写入与退出码返回。

## 执行命令与证据
- 执行:
  - `powershell -File scripts/verify-kit.ps1`
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -File scripts/validate-config.ps1`
  - `powershell -File scripts/verify.ps1`
  - `powershell -File scripts/doctor.ps1`
- 关键输出:
  - 新增测试通过（测试输出可见 `hello-log`）。
  - `build -> test -> contract/invariant -> hotspot` 全部通过。

## 回滚
- 回滚文件:
  - `tests/repo-governance-hub.optimization.tests.ps1`
- 全量回滚入口:
  - `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## learning_points_3
- 公共函数抽取后，应同步补最小行为测试以防回归。
- 日志执行器类函数可通过“文件存在 + 内容匹配”进行稳定验证。
- 先补测试再继续下一批重构，能降低后续改造风险。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
