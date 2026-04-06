规则ID=GK-20260407-LEARNING-LOOP-ENFORCE
规则版本=3.83
兼容窗口(观察期/强制期)=observe=2026-04-07~2026-04-14; enforce>=2026-04-15
影响模块=templates/change-evidence.md; docs/change-evidence/template.md; scripts/verify-kit.ps1; scripts/collect-governance-metrics.ps1; templates/governance-metrics.md; docs/governance/metrics-template.md; source/project/governance-kit/*
当前落点=E:/CODE/governance-kit
目标归宿=规则/模板/指标三处一致，学习闭环字段可被模板引导、门禁检测与指标统计
迁移批次=2026-04-07-learning-loop-enforcement
风险等级=低
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=apply_patch + powershell -File scripts/install.ps1 -Mode safe + 四段门禁
验证证据=本文件 + 门禁输出
供应链安全扫描=gate_na; reason=仅文档模板与本地脚本逻辑变更，无新增依赖; alternative_verification=verify-kit/tests/validate-config/verify/doctor; evidence_link=docs/change-evidence/20260407-learning-loop-enforcement.md; expires_at=2026-04-30
发布后验证(指标/阈值/窗口)=新增 learning_loop_evidence_rate，观察4周
数据变更治理(迁移/回填/回滚)=无结构化数据迁移
回滚动作=git restore templates/change-evidence.md docs/change-evidence/template.md scripts/verify-kit.ps1 scripts/collect-governance-metrics.ps1 templates/governance-metrics.md docs/governance/metrics-template.md AGENTS.md CLAUDE.md GEMINI.md source/project/governance-kit/AGENTS.md source/project/governance-kit/CLAUDE.md source/project/governance-kit/GEMINI.md

本次学到的3点=
1) 仅有规则条款不足以形成行为约束，必须配套模板与校验脚本。
2) 学习闭环字段应进入度量体系，否则难以持续优化。
3) 规则、模板、指标三处必须同名同义，避免执行偏差。

下次可复用清单=
1) 先补模板字段，再补门禁检查，再补指标采集。
2) 对 evidence 采用 key=value 统一格式，便于 Parse-KeyValueFile 复用。
3) 变更后按 build->test->contract/invariant->hotspot 固定顺序复验。

仍不确定的问题=
1) 目标仓是否需要额外自动 backfill 脚本来补齐历史 evidence 的学习闭环字段。
2) learning_loop_evidence_rate 的告警阈值是否应按仓库阶段分级。

learning_points_3=template+gate+metrics must change together`r`nreusable_checklist=add fields then enforce via verify-kit then measure via metrics`r`nopen_questions=alert threshold for learning_loop_evidence_rate still pending


