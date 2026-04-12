# 20260412 trace grading backfill phase2

## 背景与目标
- issue_id: `trace-grading-backfill-phase2-20260412`
- 目标: 修复 `backfill-trace-grading-fields.ps1` 兼容性问题并完成证据字段批量回填，提升 trace grading 覆盖率。

## 任务理解快照
- 目标: 在不破坏现有门禁的前提下，完成 Phase 2 自动回填落地。
- 非目标: 不调整 trace grading 阈值策略；不改变 observe/enforce 策略。
- 验收标准:
  - 新增/更新脚本测试通过。
  - `build -> test -> contract/invariant -> hotspot` 链路通过。
  - backfill safe 执行成功并提升 `trace_grading.overall_coverage_rate`。
- 关键假设:
  - 已确认: 现有 policy 允许回填字段 `decision_score/hard_guard_hits/reason_codes`。
  - 未确认: 覆盖率阈值期望值是否需要在下一阶段下调或分层。

## 变更清单
- 修复 `scripts/governance/backfill-trace-grading-fields.ps1`
  - 去除 `??` 写法，改为兼容版判空。
  - 修复 `changed_file_count` 赋值方式，避免 `Argument types do not match`。
- 同步 source of truth:
  - `source/project/_common/custom/scripts/governance/backfill-trace-grading-fields.ps1`
- 执行 backfill:
  - `plan` 扫描 200，候选 181。
  - `safe` 实际变更 181 个 evidence 文件。

## 执行命令与关键输出
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - 新增两条 backfill 测试通过。
- `powershell -File scripts/install.ps1 -Mode safe`
  - 通过；post-gate assert 通过。
- `powershell -File scripts/verify-kit.ps1`
  - 通过。
- `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
  - 通过；`trace_grading.overall_coverage_rate=0.736264`。
- `powershell -File scripts/doctor.ps1`
  - `HEALTH=GREEN`。

## 第二轮扩量回填（连续自动执行）
- 目的: 覆盖全部历史 evidence，消除 `coverage_below_threshold`。
- 命令:
  - `powershell -File scripts/governance/backfill-trace-grading-fields.ps1 -RepoRoot . -Mode plan -MaxFiles 5000 -AsJson`
  - `powershell -File scripts/governance/backfill-trace-grading-fields.ps1 -RepoRoot . -Mode safe -MaxFiles 5000 -AsJson`
  - `powershell -File scripts/verify.ps1`
- 结果:
  - `scanned_file_count=275`
  - `changed_file_count=74`
  - `trace_grading.status=ok`
  - `trace_grading.overall_coverage_rate=1`

## 风险分级
- 风险等级: `low`
- 影响面: evidence 文档字段补全 + backfill 脚本兼容性修复。
- 兼容性: 未改变既有 contract/invariant 语义。

## 可观测信号
- 修复前: backfill 脚本报错 `Unexpected token '??'` / `Argument types do not match`。
- 修复后: backfill `plan/safe` 均返回 `status=ok`，门禁全绿，coverage 明显提升。

## 回滚方案
- 回滚入口: `powershell -File scripts/restore.ps1` + `backups/<timestamp>/`
- 定向回滚:
  - 回退脚本到上一版本。
  - 对 evidence 回填内容按时间窗口回滚。

## 术语解释点
- `trace grading`: 对变更/执行证据字段完备性与质量进行分级评估的门禁信号。
- `backfill`: 对历史文件补齐缺失字段，不改变业务逻辑。
- 常见误解: 回填提升覆盖率不等于直接放宽阈值；阈值策略仍由 policy 控制。

## learning_points_3
- PowerShell 版本兼容优先，避免引入新语法特性。
- OrderedDictionary 赋值优先使用索引器，降低类型绑定异常风险。
- 先 `plan` 再 `safe` 的批量改动流程能显著降低回填风险。

## reusable_checklist
- [x] 语法兼容检查（Windows PowerShell）
- [x] source/custom 双写一致
- [x] plan/safe 双模式验证
- [x] 完整门禁链复验

## open_questions
- 是否将 `trace_grading` 从 observe 推进到 enforce（需结合未来 2-4 周指标稳定性）。

decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
