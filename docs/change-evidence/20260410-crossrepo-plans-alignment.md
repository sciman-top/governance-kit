规则ID=GK-CROSSREPO-PLANS-ALIGN-20260410
规则版本=3.83
兼容窗口(观察期/强制期)=observe -> enforce
影响模块=source/project/ClassroomToolkit/custom/docs/PLANS.md; source/project/skills-manager/custom/docs/PLANS.md; config/project-custom-files.json; config/targets.json
当前落点=E:/CODE/governance-kit
目标归宿=ClassroomToolkit 与 skills-manager 的 PLANS 均收敛到 repo-scoped source，并通过分发链路保持一致
迁移批次=2026-04-10-plan-alignment
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
任务理解快照=目标: 修复 governance-kit verify 对 ClassroomToolkit PLANS 的漂移，并让 skills-manager 拥有可判定的目标与验收标准; 非目标: 修改门禁语义或扩展默认分发范围; 验收标准: install 后 verify fail=0 且 doctor GREEN，skills-manager/docs/PLANS.md 非空模板; 关键假设: 两仓 PLANS 都应由 repo-scoped custom source 管理
术语解释点=repo-scoped PLANS: 指 source/project/<RepoName>/custom/docs/PLANS.md 作为该仓计划源; 本次示例是 ClassroomToolkit 和 skills-manager; 常见误解是把所有仓的 PLANS 固定映射到 _common 模板
可观测信号=现象: governance-kit verify 出现 ClassroomToolkit PLANS DIFF 且 doctor RED; 假设: source phase 信息落后且 skills-manager 缺 repo-scoped PLANS; 验证命令: refresh-targets + install safe + verify + doctor; 预期结果: verify ok=106 fail=0 且 doctor GREEN; 下一步: 持续按 repo-scoped PLANS 维护目标变更
排障路径=1) 对比 ClassroomToolkit target/source PLANS 发现 Current phase 不一致 2) 同步 ClassroomToolkit source phase 3) 新增 skills-manager repo-scoped PLANS 并将 docs/PLANS.md 注册到 repo custom files 4) refresh-targets 更新映射 5) install safe 分发并跑全链路门禁
未确认假设与纠偏结论=未确认: skills-manager 是否需要独立 PLANS 管理; 纠偏: 当前已通过 repo-scoped source 下发，目标仓 PLANS 由该源直接管理
执行命令=powershell -File scripts/refresh-targets.ps1 -Mode safe; powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=install copied=1 (skills-manager/docs/PLANS.md); verify done ok=106 fail=0; doctor HEALTH=GREEN; post-gate full chain passed
供应链安全扫描=N/A (no dependency/package changes)
发布后验证(指标/阈值/窗口)=窗口到 2026-04-17；阈值: verify fail=0、doctor GREEN、skills-manager PLANS 保持非空模板
数据变更治理(迁移/回填/回滚)=仅文档源与映射调整，无结构化数据迁移
回滚动作=1) 回退本次四个文件变更 2) 执行 powershell -File scripts/refresh-targets.ps1 -Mode safe 3) 执行 powershell -File scripts/install.ps1 -Mode safe 覆盖回滚

issue_id=crossrepo-plans-alignment
attempt_count=1
clarification_mode=direct_fix
clarification_scenario=
clarification_questions=
clarification_answers=

learning_points_3=repo-scoped PLANS 需要随仓内 phase 变化及时回灌; 缺少目标定义会使“是否达成”不可判定; refresh-targets 与 install 组合可以把映射修复与分发验证一次闭环
reusable_checklist=定位 DIFF -> 对齐 repo-scoped source -> 注册 project-custom-files -> refresh-targets -> install safe -> verify + doctor -> 留证据
open_questions=是否为 skills-manager 增加周期自动提醒，强制每周刷新 PLANS current phase
