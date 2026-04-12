规则ID=GK-20260407-TEACHING-MODE-HARDENING
规则版本=3.83
兼容窗口(观察期/强制期)=observe=2026-04-07~2026-04-14; enforce>=2026-04-15
影响模块=source/project/repo-governance-hub/{AGENTS,CLAUDE,GEMINI}.md
当前落点=E:/CODE/repo-governance-hub/source/project/repo-governance-hub/*
目标归宿=E:/CODE/repo-governance-hub/{AGENTS,CLAUDE,GEMINI}.md + config/targets.json映射目标仓
迁移批次=2026-04-07-teaching-hardening
风险等级=中
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=apply_patch(source); powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=本文件 + 终端门禁输出
供应链安全扫描=N/A(本次仅规则文档变更, 无新增依赖)
发布后验证(指标/阈值/窗口)=误解触发率下降/一次通过率提升，按周观察，窗口4周
数据变更治理(迁移/回填/回滚)=无结构化数据迁移；仅规则文本升级
回滚动作=powershell -File scripts/restore.ps1 并从 backups/<timestamp>/ 恢复；或回退到3.82版本

任务理解快照=
- 目标：强化外层AI“边做边教”的职责，降低用户与AI的语义偏差与返工。
- 非目标：不改变硬门禁顺序与阻断语义，不引入脚本自动修复套娃。
- 验收标准：三文件落地教学条款、证据字段扩展、分发同步并通过四段门禁。
- 关键假设：目标仓愿意接受教学型输出模板作为默认协作方式。

新增条款摘要=
- AGENTS: A.4 增加前置澄清触发；新增 A.5 教学协作协议。
- 三文件: C.5 证据字段增加“任务理解快照/术语解释点/可观测信号/排障路径/未确认假设与纠偏结论”。
- 三文件: 新增 C.12 外层AI教学执行条款、C.13 教学质量指标与持续优化。
- 三文件: 原 C.12 顺延为 C.14。

术语解释点=
- 任务理解快照：执行前对目标与边界的简明结构化复述。
- 里程碑对齐回声：关键节点进行“做什么/为何/如何映射原意”的对齐复述。
- 可观测信号：用于判断修复是否生效的日志、状态、数据与接口行为证据。

可观测信号=
- 文件版本从 3.82 -> 3.83。
- 三文件均出现 C.12/C.13/C.14 新节。
- install safe 输出中对应目标为 COPIED/UNCHANGED 且无失败。
- build/test/contract/hotspot 全部通过。

排障路径=
- 若 install 失败：先查 targets.json 路径与写权限，再重跑 safe。
- 若 test 失败：按失败脚本定位夹具或断言，修复后重跑全链。
- 若 doctor 失败：按热点提示修复并整链复验。

未确认假设与纠偏结论=
- 未确认：所有目标仓是否立即接受更高教学密度。
- 纠偏：通过“简单任务可压缩，但关键术语解释不得省略”降低噪音风险。

learning_points_3=introduced teaching protocol and alignment checkpoints`r`nreusable_checklist=apply dual-channel output and observability teaching template`r`nopen_questions=target repos may need gradual rollout for message density


decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
