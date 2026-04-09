规则ID=GK-RELEASE-DISTRIBUTION-POLICY-20260409-001
规则版本=3.83
兼容窗口(观察期/强制期)=observe
影响模块=config/release-distribution-policy.json; scripts/verify-kit.ps1; scripts/validate-config.ps1; scripts/suggest-release-profile.ps1; scripts/verify-release-profile.ps1; tests/governance-kit.optimization.tests.ps1; README.md
当前落点=E:/CODE/governance-kit
目标归宿=发布形态与签名约束统一收敛到分发代码配置层，支持自包含/非自包含、安装版/非安装版、离线/非离线；禁止付费签名
迁移批次=2026-04-09-release-distribution-policy-config-driven
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
任务理解快照=目标: 将目标仓发布形式及设置纳入分发代码并统一治理; 非目标: 引入任何付费签名服务; 验收标准: 配置校验/建议生成/策略校验三者一致且全门禁通过
术语解释点=release-distribution-policy: 用于统一描述每个仓的发布维度约束（签名、分发形态、联网形态、渠道）；常见误解是把发布约束散落在脚本分支里，本次改为配置优先
可观测信号=新增 config/release-distribution-policy.json；validate-config 对策略结构与取值强校验；suggest/verify 均读取同一策略源
排障路径=新增必需配置后旧测试夹具失败 -> 引入 Set-MinReleaseDistributionPolicy 作为最小夹具 -> 回归测试恢复全绿
未确认假设与纠偏结论=未确认: 各目标仓未来是否都需要 installer/offline 组合; 纠偏: 先以 repo 级策略显式声明，默认最小能力 portable+online，后续按仓增量启用
执行命令=codex --version; codex --help; codex status(平台非交互失败); powershell -File scripts/install.ps1 -Mode safe; powershell -File scripts/verify-kit.ps1; powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=tests 全通过；verify-kit PASS；validate-config passed(repositories=3 targets=106 rolloutRepos=1)；verify ok=106 fail=0；doctor HEALTH=GREEN；install safe copied=0 skipped=106
供应链安全扫描=N/A (配置与脚本变更，无新增三方依赖)
发布后验证(指标/阈值/窗口)=release-profile 建议值与策略一致；verify-release-profile 对策略偏离必须阻断；每次策略变更后跑全链路
数据变更治理(迁移/回填/回滚)=无结构化业务数据迁移；仅治理配置与脚本一致性校验
回滚动作=git revert 本次提交；删除 config/release-distribution-policy.json 并回退四个脚本的策略读取逻辑

platform_na.reason=codex status 在当前非交互会话返回 stdin is not a terminal
platform_na.alternative_verification=记录 codex --version/codex --help 输出，并使用项目级 active_rule_path=E:/CODE/governance-kit/AGENTS.md 作为加载链证据
platform_na.evidence_link=docs/change-evidence/20260409-release-distribution-policy-config-driven.md
platform_na.expires_at=2026-05-09

learning_points_3=发布约束必须配置化避免脚本分叉; 建议器与校验器必须同源读取同一策略; 新增必需配置要同步升级测试夹具
reusable_checklist=新增策略文件->verify-kit存在性->validate-config结构校验->suggest读取策略->verify强一致性->测试夹具最小策略->全门禁
open_questions=是否后续增加 per-repo 的 artifact matrix（例如 win-x64/linux-x64）作为同一策略文件扩展字段
