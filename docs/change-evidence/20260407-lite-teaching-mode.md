规则ID=GK-20260407-LITE-TEACHING-MODE
规则版本=3.83
兼容窗口(观察期/强制期)=observe=2026-04-07~2026-04-14; enforce>=2026-04-15
影响模块=source/project/governance-kit/{AGENTS,CLAUDE,GEMINI}.md
当前落点=E:/CODE/governance-kit/source/project/governance-kit/*
目标归宿=E:/CODE/governance-kit/{AGENTS,CLAUDE,GEMINI}.md
迁移批次=2026-04-07-lite-teaching
风险等级=低
是否豁免(Waiver)=否
执行命令=apply_patch + powershell -File scripts/install.ps1 -Mode safe + 四段门禁
验证证据=本文件+终端门禁输出
供应链安全扫描=gate_na; reason=仅规则文档变更，无新增依赖; alternative_verification=verify-kit/tests/validate-config/verify/doctor; evidence_link=docs/change-evidence/20260407-lite-teaching-mode.md; expires_at=2026-04-30
发布后验证(指标/阈值/窗口)=关注单任务token与用户二次追问率，观察4周
数据变更治理(迁移/回填/回滚)=无结构化数据变更
回滚动作=git restore source/project/governance-kit/AGENTS.md source/project/governance-kit/CLAUDE.md source/project/governance-kit/GEMINI.md AGENTS.md CLAUDE.md GEMINI.md

learning_points_3=lite档位要有固定短答模板，避免教学冗长;分级展开可在不丢信息前提下控token;术语去重能显著降低重复成本
reusable_checklist=默认lite三行输出;高风险再升级standard/deep;里程碑对齐用单句模板
open_questions=是否需要把token阈值数值化到配置文件（如project-rule-policy.json）
