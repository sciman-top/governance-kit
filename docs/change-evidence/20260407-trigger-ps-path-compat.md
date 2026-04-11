规则ID=GK-20260407-TRIGGER-PS-PATH-COMPAT
规则版本=3.83
兼容窗口(观察期/强制期)=observe(2026-04-07) -> enforce(2026-04-08)
影响模块=scripts/governance/check-update-triggers.ps1; scripts/governance/run-monthly-policy-review.ps1; source/project/repo-governance-hub/custom; source/project/_common/custom
当前落点=scripts/governance/* + source/project/*/custom/scripts/governance/*
目标归宿=source/project/repo-governance-hub/custom/scripts/governance/* + source/project/_common/custom/scripts/governance/*
迁移批次=20260407-batch-trigger-ps-path
风险等级=LOW
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1; powershell -File E:/CODE/ClassroomToolkit/scripts/governance/check-update-triggers.ps1 -RepoRoot E:/CODE/ClassroomToolkit -AsJson; powershell -File E:/CODE/skills-manager/scripts/governance/check-update-triggers.ps1 -RepoRoot E:/CODE/skills-manager -AsJson
验证证据=full gates pass; verify ok=73 fail=0; doctor HEALTH=GREEN; cross-repo trigger scripts run without missing-common error
供应链安全扫描=N/A(无新依赖)
发布后验证(指标/阈值/窗口)=next recurring review cycle should keep alert script executable in all target repos
数据变更治理(迁移/回填/回滚)=N/A(无数据结构变更)
回滚动作=git checkout -- scripts/governance/check-update-triggers.ps1 scripts/governance/run-monthly-policy-review.ps1 source/project/repo-governance-hub/custom/scripts/governance/check-update-triggers.ps1 source/project/repo-governance-hub/custom/scripts/governance/run-monthly-policy-review.ps1 source/project/_common/custom/scripts/governance/check-update-triggers.ps1 source/project/_common/custom/scripts/governance/run-monthly-policy-review.ps1

learning_points_3=跨仓复用脚本不能强依赖本仓 helper; 先跨仓冒烟再跑本仓门禁可更快发现兼容问题; source 与目标仓必须同步更新避免 verify DIFF
reusable_checklist=改 governance 分发脚本后执行 target smoke; 同步 repo-governance-hub/custom 与 _common/custom; 再跑 build->test->contract->hotspot
open_questions=是否在 _common 脚本层引入稳定的轻量 helper 包以替代各脚本 fallback 逻辑
