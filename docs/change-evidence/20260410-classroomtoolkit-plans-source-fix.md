规则ID=GK-PLANS-SOURCE-FIX-20260410
规则版本=3.83
兼容窗口(观察期/强制期)=observe -> enforce
影响模块=source/project/ClassroomToolkit/custom/docs/PLANS.md; config/project-custom-files.json; config/targets.json; tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit
目标归宿=ClassroomToolkit 的 live PLANS.md 收敛到 repo-scoped source，避免被 _common 模板误判为漂移
迁移批次=2026-04-10-hotfix
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
任务理解快照=目标: 修复 verify/doctor 因 ClassroomToolkit/docs/PLANS.md 映射错误导致的红灯; 非目标: 修改 verify 语义或扩大默认分发范围; 验收标准: verify ok=106 fail=0、doctor HEALTH=GREEN、全量测试通过; 关键假设: ClassroomToolkit 的 PLANS.md 设计上应保持 repo-scoped live 文档
术语解释点=repo-scoped custom source: 指 source/project/<RepoName>/custom 下的仓专属分发源; 本仓示例是 source/project/ClassroomToolkit/custom/docs/PLANS.md; 常见误解是把所有 custom 文件都固定收敛到 source/project/_common/custom
可观测信号=现象: verify 报 [DIFF] source/project/_common/custom/docs/PLANS.md != E:/CODE/ClassroomToolkit/docs/PLANS.md; 假设: targets.json 仍把 ClassroomToolkit 的 PLANS.md 指向通用模板; 验证命令: powershell -File scripts/refresh-targets.ps1 -Mode safe 后重跑 powershell -File scripts/verify.ps1; 预期结果: 源路径切到 source/project/ClassroomToolkit/custom/docs/PLANS.md 且 verify 全绿; 下一步: 补回归测试防止 add-repo 再回退到 _common
排障路径=1) 读取 verify 差异输出确认唯一失败项是 ClassroomToolkit/docs/PLANS.md 2) 检查 config/targets.json 与 project-custom-files.json，确认该文件仍走默认 custom 分发 3) 新增 repo-scoped source 并把 docs/PLANS.md 注册到 ClassroomToolkit repo custom files 4) refresh-targets 重建映射并用全量 tests + verify + doctor 复验
未确认假设与纠偏结论=未确认: verify 失败是否来自目标仓临时本地修改; 纠偏: 实际根因是 governance-kit 映射仍指向 _common 模板，而证据已明确要求保留 repo-specific override path for live PLANS.md
执行命令=powershell -File scripts/refresh-targets.ps1 -Mode safe; powershell -File scripts/verify.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/doctor.ps1
验证证据=refresh_targets.target_change_count=1; verify done ok=106 fail=0; tests 新增 "add-repo prefers repo-scoped custom source when available" 通过; doctor HEALTH=GREEN
供应链安全扫描=N/A (no dependency/package changes)
发布后验证(指标/阈值/窗口)=即时阈值为 verify fail=0 且 doctor GREEN；观察窗口到 2026-04-17，关注后续 refresh-targets/install 是否保持 ClassroomToolkit/docs/PLANS.md 指向 repo-scoped source
数据变更治理(迁移/回填/回滚)=仅文本源与映射调整，无结构化数据迁移；回滚可恢复 docs/PLANS.md 到 _common 映射
回滚动作=1) 删除 source/project/ClassroomToolkit/custom/docs/PLANS.md 或移除 repo custom files 中 docs/PLANS.md 2) 执行 powershell -File scripts/refresh-targets.ps1 -Mode safe 3) 如需覆盖目标仓，执行 powershell -File scripts/install.ps1 -Mode safe

issue_id=classroomtoolkit-plans-source-fix
attempt_count=1
clarification_mode=direct_fix
clarification_scenario=
clarification_questions=
clarification_answers=

learning_points_3=live 计划文档若允许仓级差异，必须在 source 中有对应 repo-scoped custom 源; verify 红灯先看 targets 映射再怀疑目标仓漂移; refresh-targets 与 verify 并行执行会读到旧 targets，复验必须顺序化
reusable_checklist=定位 verify 唯一 DIFF -> 检查 targets/project-custom-files -> 新增 repo-scoped custom source -> refresh-targets -> verify/test/doctor 顺序复验 -> 记录回滚
open_questions=是否需要把“repo-scoped custom files 优先于 _common”补充到 README 的 custom-file 说明里
