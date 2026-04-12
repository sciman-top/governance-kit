规则ID=GK-COMMON-POLICY-SUMMARY-DEDUP-20260410
规则版本=3.83
兼容窗口(观察期/强制期)=observe -> enforce
影响模块=scripts/lib/common.ps1; scripts/install-full-stack.ps1; scripts/run-project-governance-cycle.ps1
当前落点=E:/CODE/repo-governance-hub
目标归宿=统一 policy 摘要输出函数，减少跨脚本重复格式字符串
迁移批次=2026-04-10-governance-common-dedup
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=verify-kit PASS; optimization tests PASS; validate-config PASS; verify ok=106 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A (no dependency changes)
发布后验证(指标/阈值/窗口)=窗口到 2026-04-17；阈值: verify fail=0 且 doctor GREEN
数据变更治理(迁移/回填/回滚)=无数据结构变更
回滚动作=将 Write-RepoAutomationPolicySummary 调用改回原内联 Write-Host 格式字符串并删除 common 中新增函数，然后重跑全链路门禁

learning_points_3=重复日志格式应优先下沉 common helper; 低风险去重也必须跑完整硬门禁; policy 输出统一可降低后续维护误差
reusable_checklist=识别重复输出 -> 提炼 common helper -> 逐脚本替换 -> 跑 build/test/contract/hotspot -> 留证据
open_questions=是否把 autopilot 的 policy 输出也统一迁移到同一 helper
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
