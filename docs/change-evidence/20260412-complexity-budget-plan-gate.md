# 20260412 complexity budget plan gate

## issue_id
- `p1-05-complexity-budget-gate-20260412`

## 目标与非目标
- 目标: 当复杂度预算超限时，要求存在有效 merge/deprecation 计划；无计划则阻断。
- 非目标: 不改变现有 anti-bloat 默认阈值，不放宽默认阻断语义。

## 关键改动
- 新增 anti-bloat 计划门禁能力：
  - `require_merge_or_deprecation_plan_on_violation`
  - `allow_with_active_plan`
  - `plan_path`
- 新增计划校验逻辑（有效类型、状态、到期日）：
  - `merge|deprecation` + `active|approved|in_progress` + `expires_at(yyyy-MM-dd, 未过期)`
- repo 级策略启用（仅 `repo-governance-hub`）：
  - `.governance/anti-bloat-policy.json`
  - `source/project/_common/custom/.governance/anti-bloat-policy.json`
- 新增计划文件：
  - `.governance/complexity-budget-plan.json`

## 变更文件
- `scripts/governance/check-anti-bloat-budgets.ps1`
- `source/project/_common/custom/scripts/governance/check-anti-bloat-budgets.ps1`
- `.governance/anti-bloat-policy.json`
- `source/project/_common/custom/.governance/anti-bloat-policy.json`
- `.governance/complexity-budget-plan.json`
- `tests/repo-governance-hub.optimization.tests.ps1`

## 验证命令与结果
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - 新增回归通过：
    - `anti-bloat blocks when violation exists but merge/deprecation plan is missing`
    - `anti-bloat allows violation when active merge/deprecation plan exists`
- `powershell -File scripts/install.ps1 -Mode safe`
  - 通过；post-gate 全链路通过。
- `powershell -File scripts/verify-kit.ps1`
  - 通过。
- `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
  - 通过。
- `powershell -File scripts/doctor.ps1`
  - 通过，`HEALTH=GREEN`。

## 风险与回滚
- 风险等级: `low`
- 风险点: 计划文件缺失时，超限场景会从“仅超限阻断”变为“明确缺计划阻断”。
- 回滚入口:
  - `scripts/restore.ps1`
  - 或回退上述改动文件到前一版本。

## 可观测信号
- 无计划超限:
  - `missing_merge_or_deprecation_plan`
- 有有效计划且策略允许:
  - `complexity budget exceeded but allowed by active <plan_type> plan`

## 任务理解快照
- goal: 完成 P1-05 的“复杂度预算 + 计划约束”闭环。
- non-goal: 不在本轮实现自动回滚触发器（P1-06）。
- acceptance: 缺计划阻断 + 有计划可放行（受策略控制）+ 全门禁通过。
- assumptions:
  - 已确认: repo 级策略可通过 `repo_overrides.enforce` 精确启用。
  - 未确认: 未来是否要求计划与具体文件路径一一绑定（本轮先做最小可用版本）。

## learning_points_3
- 预算门禁需要“阻断规则 + 例外机制”同时存在，才能实用。
- 例外机制必须带到期字段，否则会退化成永久豁免。
- source 变更后必须执行 `install -Mode safe`，否则 verify 会报 cross-repo diff。

## reusable_checklist
- [x] 脚本能力与策略字段同步
- [x] source/common 与本仓一致
- [x] 缺计划阻断测试
- [x] 有计划放行测试
- [x] `build -> test -> contract/invariant -> hotspot`

## open_questions
- 是否在下一阶段要求 `plan.scope` 与 violation `file/type` 精确匹配。
