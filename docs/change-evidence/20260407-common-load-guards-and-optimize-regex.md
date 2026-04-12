# 20260407-common-load-guards-and-optimize-regex

## 任务理解快照
- 目标: 提升门禁关键脚本对 `common.ps1` 依赖的显式保护，并修复 `optimize-project-rules` 模板识别过严问题。
- 非目标: 不改门禁顺序与规则语义。
- 验收标准: 测试与全门禁恢复并保持全绿。

## 变更内容
- 增强 common 依赖加载保护（缺失即明确报错）:
  - `scripts/verify-kit.ps1`
  - `scripts/validate-config.ps1`
  - `scripts/verify.ps1`
  - `scripts/status.ps1`
  - `scripts/rollout-status.ps1`
  - `scripts/check-waivers.ps1`
  - `scripts/check-release-profile-coverage.ps1`
  - `scripts/optimize-project-rules.ps1`
- 修复模板识别/替换正则鲁棒性:
  - `scripts/optimize-project-rules.ps1`
  - 放宽空白与 `N/A` 写法匹配, 避免模板文档误判为 custom 并跳过。
- 测试用例调用稳定性微调:
  - `tests/repo-governance-hub.optimization.tests.ps1` 中 `optimize-project-rules` 用例改为同进程脚本调用。

## 命令与结果
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> pass
- `powershell -File scripts/verify-kit.ps1` -> pass
- `powershell -File scripts/validate-config.ps1` -> pass
- `powershell -File scripts/verify.ps1` -> pass
- `powershell -File scripts/doctor.ps1` -> pass
- 全门禁最终: `build -> test -> contract/invariant -> hotspot` 全 `exit_code=0`

## 问题与修复闭环
- 问题: `optimize-project-rules updates C2/C3/C7/C8 blocks in target docs` 间歇失败。
- 根因: 模板识别正则过严导致误跳过。
- 修复: 放宽识别与替换正则，复验通过。

## 回滚
- 回滚文件:
  - `scripts/verify-kit.ps1`
  - `scripts/validate-config.ps1`
  - `scripts/verify.ps1`
  - `scripts/status.ps1`
  - `scripts/rollout-status.ps1`
  - `scripts/check-waivers.ps1`
  - `scripts/check-release-profile-coverage.ps1`
  - `scripts/optimize-project-rules.ps1`
  - `tests/repo-governance-hub.optimization.tests.ps1`
- 全量回滚入口:
  - `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`

## learning_points_3
- 关键入口脚本应对共享依赖做显式前置校验，故障更可诊断。
- 模板识别应偏向语义鲁棒，避免“格式差异=逻辑跳过”。
- 发现隐藏失败后，先让失败稳定复现，再做最小修复闭环。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
