# 20260413 Phase2 Dependency-Review Enforce Drift Check

- 规则ID=phase2-dependency-review-enforce-drift-check
- 风险等级=medium
- 当前落点=Phase2 enforce tuning
- 目标归宿=将 dependency-review enforce 要求转为可执行漂移检查并纳入 update triggers
- 任务理解快照=目标:检测 dependency-review workflow 是否回退为非 enforce 配置；非目标:本轮不调整 SLSA pipeline；验收:check-update-triggers 能报告 dependency_review_policy_drift 且测试通过
- 术语解释点=dependency-review enforce drift: 依赖审查工作流与既定强制策略不一致（如 action 版本回退、severity 变宽）；本仓示例为 `actions/dependency-review-action@v4 + fail-on-severity: high`；常见误解是把“漂移告警”当成“误报”
- 执行命令=更新 config/update-trigger-policy.json; 更新 source/project/*/custom/scripts/governance/check-update-triggers.ps1 与 scripts/governance/check-update-triggers.ps1; 新增回归测试; install safe 分发并重跑门禁
- 关键输出=新增 trigger `dependency_review_policy_drift`，新增结果字段 `dependency_review_policy_drift_count`，新增测试用例 `check-update-triggers reports dependency-review policy drift`
- 可观测信号=当 `.github/workflows/dependency-review.yml` 不满足 required action/severity 时，update-triggers 输出 high 告警
- 排障路径=现象(依赖审查策略可能回退) -> 假设(缺少自动漂移检测) -> 验证命令(check-update-triggers + 测试桩) -> 结果(漂移可检出) -> 下一步(观察两周期后再收紧策略)
- 未确认假设与纠偏结论=未确认不同仓是否需要分层 severity；先固定 high 作为基线，后续按误报率和阻断成本调优
- learning_points_3=1) enforce 状态必须由脚本持续验证而非仅文档声明; 2) 版本漂移与阈值漂移都应纳入同一告警面; 3) 先告警再收紧可降低一次性切换风险
- reusable_checklist=定义 enforce 口径 -> 加入 trigger 策略 -> 脚本检测 -> 增加回归测试 -> 分发同步 -> 全门禁验证 -> 写证据
- open_questions=是否将 dependency-review drift 升级为 doctor 硬阻断; 是否在月检中加入 drift trend 字段
- 回滚动作=git restore config/update-trigger-policy.json scripts/governance/check-update-triggers.ps1 source/project/_common/custom/scripts/governance/check-update-triggers.ps1 source/project/repo-governance-hub/custom/scripts/governance/check-update-triggers.ps1 source/project/ClassroomToolkit/custom/scripts/governance/check-update-triggers.ps1 source/project/skills-manager/custom/scripts/governance/check-update-triggers.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/execution-practice-gap-matrix-2026Q2.md docs/change-evidence/20260413-phase2-dependency-review-enforce-drift-check.md
