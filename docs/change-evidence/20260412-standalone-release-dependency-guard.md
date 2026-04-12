# 20260412 standalone-release-dependency-guard

- 规则 ID=repo-governance-hub-C18-standalone-release-dependency
- 风险等级=medium
- 目标归宿=`scripts/verify-release-profile.ps1` + `scripts/check-release-profile-coverage.ps1` + `config/standalone-release-policy.json` + `docs/governance/standalone-release-dependency-contract.md` + `AGENTS/CLAUDE/GEMINI + source/project/repo-governance-hub/*`
- 任务理解快照=目标:解决“skills-manager/overrides 作为协作依赖时，本项目单仓发布可移植性风险”；非目标:修改技能晋升阈值本身；验收:release profile 能区分阻断/告警并通过硬门禁
- 术语解释点=standalone release dependency: 发布产物运行时必须具备的依赖；collaboration dependency: 多仓协作流程依赖
- 可观测信号=verify-release-profile 输出 `warnings` 与 `standalone_dependency_hits`；release-enabled 情况命中外部绝对路径应 FAIL
- 排障路径=1) 新增 standalone policy 2) 脚本按 repo policy 扫描路径/正则 3) 增补用例覆盖 release_enabled=true/false
- 未确认假设与纠偏结论=假设:仅在 release_enabled=true 时应阻断；结论:已实现 true=FAIL、false=advisory
- 执行命令=`powershell -File scripts/verify-kit.ps1`; `powershell -File tests/repo-governance-hub.optimization.tests.ps1`; `powershell -File scripts/validate-config.ps1`; `powershell -File scripts/verify.ps1`; `powershell -File scripts/doctor.ps1`; `powershell -File scripts/check-release-profile-coverage.ps1 -AsJson`
- 关键输出=硬门禁通过；release-profile-coverage 中 repo-governance-hub `warning_count=1` 且 `status=PASS`
- 回滚动作=`git restore scripts/verify-release-profile.ps1 scripts/check-release-profile-coverage.ps1 tests/repo-governance-hub.optimization.tests.ps1 AGENTS.md CLAUDE.md GEMINI.md source/project/repo-governance-hub/AGENTS.md source/project/repo-governance-hub/CLAUDE.md source/project/repo-governance-hub/GEMINI.md docs/governance/standalone-release-dependency-contract.md docs/governance/collaboration-contract-repo-skills-manager.md docs/governance/rule-index.md docs/governance/rule-layering-inventory.md docs/governance/rule-layering-migration-plan.md config/standalone-release-policy.json`
- learning_points_3=1) 协作边界与发布边界必须拆开建模 2) release profile 需要输出 warnings 以承载“非阻断但可观测”的依赖 3) 覆盖脚本汇总 warning_count 可防止“通过但不可见”
- reusable_checklist=1) 先定义 policy 2) 在 verify 加阻断/告警分支 3) 覆盖测试 true/false 两态 4) 以 coverage 汇总暴露 warning_count
- open_questions=若未来启用 repo-governance-hub standalone 发布，是否需要将当前绝对路径引用统一迁移为占位符与环境变量
