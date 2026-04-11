规则ID=boundary-classification-decision-kit-v1
规则版本=1.0
兼容窗口(观察期/强制期)=observe=2026-04-12, enforce=2026-04-12
影响模块=config/boundary-classification-policy.json; docs/governance/boundary-classification-checklist.zh-CN.md; docs/governance/boundary-review-template.zh-CN.md; scripts/governance/check-boundary-classification.ps1; scripts/add-repo.ps1; scripts/doctor.ps1; scripts/install.ps1
当前落点=现有边界策略只定义最小 machine-check 规则，缺少一份统一的人类评审模板、保守回退口径，以及脚本级提示与建议输出
目标归宿=将“如何判断 global-user / project / shared-template”固化为策略字段 + 中文清单 + 评审模板 + 机器建议输出
迁移批次=20260412
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=python - <<not-used>>; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=门禁链通过；boundary classification policy JSON 可解析；新增模板文件已纳入仓内文档；boundary check 输出包含 recommended_boundary_class/fallback_class/review_template_path；doctor 默认链包含 boundary-classification 步骤；install post-gate contract/invariant 包含 boundary-classification
供应链安全扫描=N/A（本次仅策略/文档变更，无新增外部依赖）
发布后验证(指标/阈值/窗口)=后续新增组件评审时，统一使用 boundary-review-template.zh-CN.md；窗口=即刻生效
数据变更治理(迁移/回填/回滚)=无数据结构迁移；如需回滚，删除新增模板并恢复 policy/checklist 变更
回滚动作=git revert 本次提交，或手动恢复上述 3 个文件到前一版本并删除新增模板
subagent_decision_mode=not_used
spawn_parallel_subagents=false
max_parallel_agents=0
decision_score=
reason_codes=repo_dependency_first; global_user_only_for_repo_agnostic; fallback_to_project_when_ambiguous
hard_guard_hits=none
policy_path=config/boundary-classification-policy.json
growth_pack_enabled=
target_repo_count=3
readiness_score=
quickstart_presence=
release_template_presence=
任务理解快照=目标=固化边界判定口径并可重复执行; 非目标=改写分发逻辑或重分类现有 targets; 验收标准=有文档、有模板、有策略字段且门禁通过; 关键假设=现有脚本会忽略新增 JSON 字段
术语解释点=shared-template=多仓复用但仍落仓内的项目级模板源，不等于用户级全局文件
可观测信号=check-boundary-classification 继续通过；targets 边界统计不变；新增组件可按模板评审；add-repo 输出直接提示 boundary review template；doctor 输出可见 boundary-classification 步骤状态
排障路径=先查 boundary-classification-policy.json 是否可解析，再查 common.ps1 的 boundary helper 是否仅依赖已存在字段
未确认假设与纠偏结论=未确认=所有脚本均完全忽略新增 policy 字段；纠偏=通过完整门禁链验证兼容性
learning_points_3=1) 多仓复用不等于全局; 2) 判定先看 repo dependency 再看复用性; 3) 文档模板应尽量下沉到脚本提示和 JSON 建议字段
reusable_checklist=新增组件时先填 boundary-review-template.zh-CN.md，再更新 targets.json，最后跑 check-boundary-classification.ps1 并读取 recommended_boundary_class/fallback_class
open_questions=是否还需要把 boundary review 模板接入 refresh-targets 或 validate-config 的失败提示

---
增量更新=2026-04-12T00:49:00+08:00
增量主题=run-safe-autopilot 接入 boundary-classification contract 子门禁
增量改动=scripts/automation/run-safe-autopilot.ps1 新增 contract.boundary-classification；新增 preflight 脚本存在性检查；dry-run planned_order 更新；tests/repo-governance-hub.optimization.tests.ps1 的4个run-safe-autopilot用例补充 scripts/governance/check-boundary-classification.ps1 夹具
增量验证命令=powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
增量验证证据=run-safe-autopilot 四个边界用例通过；完整硬门禁链通过；doctor 输出包含 [PASS] boundary-classification
增量风险与回滚=风险低；回滚可仅还原 run-safe-autopilot.ps1 与对应 tests 夹具变更
