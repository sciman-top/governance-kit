# 20260413 Manual Override Binding Dedup Guard

规则ID=C.17/C.18 + skill lifecycle dedup
issue_id=manual-override-binding-dedup-guard-20260413
当前落点=repo-governance-hub promotion gate
目标归宿=source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1 + source/project/_common/custom/.governance/skill-promotion-policy.json
风险等级=medium
执行模式=direct_fix

任务理解快照=在“同类技能归一”场景下，阻断 governance 语义类技能被 auto-create 重复新建；命中既有 canonical override 时仅允许 skip/create-block，不允许新建并行 skill。

变更摘要=
1) promote-skill-candidates 新增 `manual_override_bindings` 解析与匹配。
2) 当 issue signature 命中绑定规则时，写入 `decision_audit(action=skip, reason=manual_override_binding:...)` 并阻断 create。
3) policy 增加两条绑定：
   - `^governance-clarification-` -> `governance-clarification-protocol`
   - `^governance-teaching-lite-output` -> `governance-teaching-lite-output`
4) 新增回归测试：`promote-skill-candidates skips create when signature matches manual override binding`。

执行命令=
1) `powershell -File scripts/verify-kit.ps1`
2) `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3) `powershell -File scripts/validate-config.ps1`
4) `powershell -File scripts/verify.ps1`
5) `powershell -File scripts/doctor.ps1`

关键输出=
- tests: 新增绑定用例通过；全量 optimization tests 通过。
- verify: `ok=270 fail=0`
- doctor: `HEALTH=GREEN`

回滚动作=
1) 回退脚本与策略：
   - `scripts/governance/promote-skill-candidates.ps1`
   - `.governance/skill-promotion-policy.json`
   - `source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1`
   - `source/project/_common/custom/.governance/skill-promotion-policy.json`
2) 回退测试：
   - `tests/repo-governance-hub.optimization.tests.ps1`

learning_points_3=1) 去重应优先在 gate 层做强约束而非靠人工约定 2) canonical manual override 需要显式 signature 绑定 3) create 与 optimize/skip 的边界必须可审计
reusable_checklist=新增技能归一策略时：policy 绑定 -> gate 拦截 -> 回归测试 -> build/test/contract/hotspot -> 证据落档
open_questions=是否将更多已稳定治理类 signature 家族纳入 `manual_override_bindings` 白名单以进一步收敛 create 面。
