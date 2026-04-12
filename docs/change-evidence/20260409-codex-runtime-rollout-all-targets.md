规则ID=GK-CODEX-RUNTIME-ROLLOUT-ALL-006
规则版本=3.83
兼容窗口(观察期/强制期)=observe -> enforce (codex runtime policy enabled for all configured repos)
影响模块=config/codex-runtime-policy.json; scripts/set-codex-runtime-policy.ps1; tests/repo-governance-hub.optimization.tests.ps1; targets distribution outputs
当前落点=E:/CODE/repo-governance-hub
目标归宿=E:/CODE/ClassroomToolkit + E:/CODE/skills-manager + E:/CODE/repo-governance-hub
迁移批次=2026-04-09-phase-rollout-all-targets
风险等级=medium (controlled write to multi-repo runtime config)
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
任务理解快照=目标: 将 .codex runtime 资产分发到全部目标仓并保持门禁通过; 非目标: 合并仓库结构或改动业务代码; 验收标准: 三仓 .codex 文件存在且 verify/test/contract/hotspot 全绿; 关键假设: repositories.json 中三仓均为本次分发范围
术语解释点=.codex runtime policy: 控制每个目标仓是否接收 .codex 配置文件的策略开关; 本仓示例是 config/codex-runtime-policy.json 的 repos.enabled; 常见误解是以为 install 会无条件把 .codex 分发到所有仓
可观测信号=现象: set-codex-runtime-policy 新增条目时报 property set 异常; 假设: pscustomobject 在空对象路径不能直接属性赋值; 验证命令: powershell -File scripts/set-codex-runtime-policy.ps1 -RepoName skills-manager -Enabled true -Mode safe; 预期结果: 正常写入 repos 条目; 下一步: install -Mode safe 并复验
排障路径=修复 set-codex-runtime-policy.ps1 对新增/更新统一使用 Add-Member -Force -> 新增测试 "adds repoName entry when missing" -> 重新执行策略开启与 install safe
未确认假设与纠偏结论=未确认: install 是否会同步刷新 targets 并复制 .codex 到新启用仓; 纠偏: install 输出 copied=8 且 verify ok=106 fail=0，目标仓 .codex 文件均存在
执行命令=powershell -File scripts/set-codex-runtime-policy.ps1 -RepoName skills-manager -Enabled true -Mode safe; powershell -File scripts/set-codex-runtime-policy.ps1 -RepoName ClassroomToolkit -Enabled true -Mode safe; powershell -File scripts/install.ps1 -Mode safe; Test-Path E:/CODE/ClassroomToolkit/.codex/config.toml; Test-Path E:/CODE/skills-manager/.codex/config.toml
验证证据=install 输出 copied=8 (新增 .codex 到 ClassroomToolkit/skills-manager); verify done ok=106 fail=0; HEALTH=GREEN; tests 包含新增用例 set-codex-runtime-policy adds repoName entry when missing 通过
供应链安全扫描=N/A (config/script/test changes only)
发布后验证(指标/阈值/窗口)=窗口: 当日分发后即时; 阈值: .codex 四文件在三仓均存在，门禁全通过
数据变更治理(迁移/回填/回滚)=无结构化数据迁移；策略文件为可回滚文本变更
回滚动作=将 config/codex-runtime-policy.json 恢复为仅 repo-governance-hub enabled=true；执行 powershell -File scripts/install.ps1 -Mode safe 覆盖回滚
issue_id=codex-runtime-rollout-all-targets
attempt_count=2
clarification_mode=direct_fix
clarification_scenario=
clarification_questions=
clarification_answers=

learning_points_3=分发策略脚本必须覆盖“新增条目”路径测试; policy 开关与 install 流程联动可以实现低风险渐进 rollout; 目标仓分发成功要用文件存在性+门禁双证据确认
reusable_checklist=修脚本缺陷 -> 补测试 -> 开关策略 -> 执行 install safe -> 验证三仓文件存在 -> 全链路门禁 -> 记录证据
open_questions=是否把 codex-runtime-policy 的 repoName 列表同步暴露到 README 的运维片段
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
