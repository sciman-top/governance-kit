规则ID=GK-RELEASE-DRIFT-TRIGGER-20260409-001
规则版本=3.83
兼容窗口(观察期/强制期)=observe
影响模块=config/update-trigger-policy.json; scripts/governance/check-update-triggers.ps1; scripts/governance/run-recurring-review.ps1; scripts/governance/run-monthly-policy-review.ps1; source/project/_common/custom/scripts/governance/*; source/project/governance-kit/custom/scripts/governance/*; tests/governance-kit.optimization.tests.ps1
当前落点=E:/CODE/governance-kit
目标归宿=在周期任务中自动识别“发布参数偏离分发策略”的漂移，触发告警并指导自动回收
迁移批次=2026-04-09-release-distribution-policy-drift-trigger
风险等级=low
是否豁免(Waiver)=no
任务理解快照=目标: 让 AI 发布前后可自动发现并收敛到策略最优参数集合; 非目标: 引入重型机器学习或付费依赖; 验收标准: 新触发器可检测漂移且全门禁通过
术语解释点=release_distribution_policy_drift: 指 source/project/<Repo>/custom/.governance/release-profile.json 与 config/release-distribution-policy.json 不一致；常见误解是只校验目标仓现状而忽略 source of truth 偏移
可观测信号=check-update-triggers 输出 release_distribution_policy_drift_count；run-recurring-review 与 monthly-review 输出同名汇总指标
排障路径=新增触发器后单测触发严格模式数组计数异常 -> 修复数组归一化函数为稳定数组返回 -> 单测与全链路恢复通过
未确认假设与纠偏结论=未确认: 各仓未来是否需要更细粒度 artifact 维度; 纠偏: 当前先聚焦发布策略关键维度(签名/通道/形态/联网/FDD/SCD)
执行命令=powershell -File tests/governance-kit.optimization.tests.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1; powershell -File scripts/install.ps1 -Mode safe
验证证据=新增测试 check-update-triggers reports release-distribution-policy drift 通过；verify ok=106 fail=0；doctor HEALTH=GREEN；install safe copied=6(同步 ClassroomToolkit/skills-manager 周检脚本)
发布后验证(指标/阈值/窗口)=weekly recurring review 若 release_distribution_policy_drift_count>0 则 status=ALERT；monthly review 同步汇总该指标
数据变更治理(迁移/回填/回滚)=无业务数据迁移；仅配置与脚本行为增强
回滚动作=git revert 本批提交；必要时将 update-trigger-policy.json 的 release_distribution_policy_drift.enabled=false

learning_points_3=最小闭环优先于一次性大而全系统; 触发器应优先复用现有周检/月检管道; 严格模式下数组返回必须防止单元素展开
reusable_checklist=新增触发器配置->触发器脚本输出计数->周检/月检汇总透传->增加单测->同步 source/custom 分发源->install safe->全门禁
open_questions=是否将 release_distribution_policy_drift 的推荐动作升级为自动生成修复补丁清单
