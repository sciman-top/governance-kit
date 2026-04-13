# 20260413 Phase2 SLSA Provenance Pipeline Upgrade

- 规则ID=phase2-slsa-provenance-pipeline-upgrade
- 风险等级=high
- 当前落点=Phase2 supply-chain enforce tuning
- 目标归宿=从 placeholder SLSA 工作流升级为可验证 provenance attestation pipeline，并可被 update-trigger 识别
- 任务理解快照=目标:替换 placeholder workflow 并新增 placeholder 漂移检测；非目标:本轮不扩展到 org-level artifact signing; 验收:workflow 使用 slsa-github-generator 且 triggers 可识别 placeholder 回退
- 术语解释点=SLSA provenance: 构建产物来源与构建过程可验证的证明；本仓示例为 `slsa-framework/slsa-github-generator` + `id-token:write`；常见误解是把“上传说明文件”当作 provenance
- 执行命令=更新 source/project/_common/custom/.github/workflows/slsa.yml; 更新 update-trigger-policy 与 check-update-triggers; 增加 slsa placeholder 回归测试; install safe 分发; 全门禁复验
- 关键输出=新增 generator-based slsa workflow；新增 trigger `slsa_provenance_placeholder` 与字段 `slsa_provenance_placeholder_count`
- 可观测信号=若目标仓 slsa.yml 回退为 placeholder 或缺失 generator/id-token，update-triggers 直接 high 告警
- 排障路径=现象(slsa 为 placeholder) -> 假设(缺少真实 attestation 与回退检测) -> 验证(脚本 + 测试) -> 结果(可生成 attestation 且可检测回退) -> 下一步(周检观察信号质量)
- 未确认假设与纠偏结论=未确认所有目标仓对 upload-assets 的发布流程兼容性；先保留 workflow_dispatch 与 release/push 触发并观察两周期
- learning_points_3=1) 供应链能力要“能产出证明+能防回退”双闭环; 2) 高风险项应通过 trigger 常态巡检; 3) 先统一 _common baseline 再分发最稳
- reusable_checklist=替换 placeholder pipeline -> 加入回退检测 trigger -> 新增回归测试 -> 分发 -> 全链门禁 -> 证据归档
- open_questions=是否在 recurring-review summary 增加 `slsa_provenance_status` 独立字段；是否在下一阶段切换更严格的 provenance verify gate
- 回滚动作=git restore source/project/_common/custom/.github/workflows/slsa.yml config/update-trigger-policy.json scripts/governance/check-update-triggers.ps1 source/project/_common/custom/scripts/governance/check-update-triggers.ps1 source/project/repo-governance-hub/custom/scripts/governance/check-update-triggers.ps1 source/project/ClassroomToolkit/custom/scripts/governance/check-update-triggers.ps1 source/project/skills-manager/custom/scripts/governance/check-update-triggers.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/governance/execution-practice-gap-matrix-2026Q2.md docs/change-evidence/20260413-phase2-slsa-provenance-pipeline-upgrade.md
