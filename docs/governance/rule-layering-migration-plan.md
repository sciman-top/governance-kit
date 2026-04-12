# Rule Layering Migration Plan (Global + Repo + Skills)

## 1) 目标与边界
- 目标：在不破坏现有门禁与兼容性的前提下，降低规则常驻上下文 token 成本。
- 非目标：不重写治理语义，不更改现有硬门禁顺序，不一次性重构全部文档。
- 验收口径：
  - 主规则文件（`AGENTS.md/CLAUDE.md/GEMINI.md`）仅保留“核心协议 + 索引”。
  - 专用流程迁移到 `docs/governance/*.md` 或 skills，并能按需加载。
  - 现有门禁仍按 `build -> test -> contract/invariant -> hotspot` 可执行。
  - `repo-governance-hub <-> skills-manager` 联合协作边界在主规则中常驻可见。
  - `standalone release` 与 `external dependency` 的判定与回退路径明确可验证。

## 2) 分层原则（决策矩阵）
- 留在主规则（必须常驻）：
  - 裁决链、硬门禁顺序、阻断条件、证据最小字段、N/A 口径。
- 迁到 Repo 文档（按需阅读）：
  - 运行手册、案例、排障流程、指标解释、模板示例。
- 迁到 Skill（按触发加载）：
  - 高频可复用流程（澄清协议、教学输出模式、建议策略、并行触发判定）。

## 3) 目录建议
- GlobalUser 层（跨仓语义）：
  - `GlobalUser/docs/governance/`（WHAT：通用语义与判定标准）
- Repo 层（本仓落地）：
  - `docs/governance/`（WHERE/HOW：命令、路径、模板、runbook）
- Skill 层（按需执行）：
  - source of truth：`source/project/skills-manager/custom/overrides/<skill-name>/SKILL.md`
  - 分发目标：`E:/CODE/skills-manager/overrides/<skill-name>/SKILL.md`（再由 skills-manager 生态同步）
  - 说明：仓内根 `.agents/` 在本仓默认被 `.gitignore` 忽略，不作为新增技能的正式落点

## 4) 任务清单（可执行）

## Phase 0 - 基线与盘点（P0，必须先做）
1. 任务：建立“规则段落去向清单”（主规则每段标记保留/迁移目标）。
   - 产出：`docs/governance/rule-layering-inventory.md`
   - 依赖：无
   - 验收：每条段落有 `target_layer` 与 `reason`
2. 任务：补齐 token 基线采样，确保 `average_response_token` 非 N/A。
   - 产出：`docs/governance/metrics-auto.md` 连续样本
   - 依赖：现有 metrics 采集脚本
   - 验收：`average_response_token`、`single_task_token`、`token_per_effective_conclusion` 可观测

## Phase 1 - 主规则瘦身（P1，低风险高收益）
1. 任务：将 `AGENTS.md/CLAUDE.md/GEMINI.md` 压缩为“核心协议 + 文档索引”。
   - 产出：三个主规则文件更新
   - 依赖：Phase 0 inventory
   - 验收：语义不丢失，主规则长度下降，索引可导航
2. 任务：新增“按场景索引”文档，替代主规则内长段落解释。
   - 产出：`docs/governance/rule-index.md`
   - 验收：覆盖常见场景（plan/bugfix/review/release）

## Phase 2 - 流程技能化（P1/P2）
1. 任务：把高频流程迁为 skill（先 1-2 个试点）。
   - 推荐首批：
     - `governance-clarification-protocol`
     - `governance-teaching-lite-output`
   - 产出：`source/project/skills-manager/custom/overrides/*/SKILL.md`
   - 门槛：满足技能创建门槛（ack、trigger eval、唯一 family、生命周期策略）
   - 验收：触发条件清晰、可独立执行、可回退
2. 任务：主规则改为“触发说明 + skill 入口”，避免重复正文。
   - 产出：主规则引用 skill 触发条款
   - 验收：同一语义不在 A/C/D 重复展开

## Phase 3 - 工具链降噪（P2）
1. 任务：先试点命令输出过滤（建议 tokf 小范围）。
   - 范围：高噪声命令（测试、构建、安装）
   - 产出：试点配置与对照报告
   - 验收：失败信息保留、成功冗余下降、质量无回退
2. 任务：形成“过滤白名单/黑名单”策略。
   - 产出：`docs/governance/output-filter-policy.md`
   - 验收：安全与可观测性检查通过

## Phase 4 - 灰度与推广（P2）
1. 任务：在一个目标仓灰度分发，观察 1-2 周。
   - 产出：`docs/change-evidence/YYYYMMDD-rule-layering-pilot.md`
   - 验收：一次通过率不降，返工率不升，token 指标改善
2. 任务：通过后再推广到其他目标仓。
   - 产出：分发记录 + 回滚脚本验证记录
   - 验收：跨仓一致性通过

## 5) 执行顺序（最小可行路径）
1. 先做 Phase 0（只盘点 + 基线采样）。
2. 再做 Phase 1（只改索引和主规则瘦身，不动脚本逻辑）。
3. 选 1 个流程做 Phase 2 技能化试点。
4. Phase 3 仅在试点稳定后启用。
5. 最后 Phase 4 灰度分发。

## 6) 风险与回滚
- 风险1：规则拆分后导航成本上升。
  - 缓解：主规则保留“场景索引 + 快速入口”。
- 风险2：skills 触发不稳定导致遗漏。
  - 缓解：主规则保留兜底最小条款。
- 风险3：输出过滤误删关键信息。
  - 缓解：先试点；保留原始日志落盘；失败输出不压缩。
- 回滚入口：
  - 文档回滚：`git restore AGENTS.md CLAUDE.md GEMINI.md docs/governance/*`
  - 仓级回滚：`scripts/restore.ps1` + `backups/<timestamp>/`

## 7) 任务看板模板（可复制）
```md
- [ ] Task:
  - Owner:
  - Layer: global|repo|skill
  - Change set:
  - Verification:
  - Evidence file:
  - Rollback:
  - Status: todo|doing|done|blocked
```

## 8) 本次建议的首周工作包
1. 完成 `rule-layering-inventory.md`（当天）。
2. 产出 `rule-index.md` 初版（当天）。
3. 主规则首轮瘦身（次日）。
4. `governance-clarification-protocol` skill 试点（次日）。
5. 输出一次周度对照（token + 一次通过率 + 返工率）。

## 9) 当前执行状态（2026-04-13）
- Phase 0：`已完成`
  - 规则盘点已完成。
  - token 基线采样已闭环：`average_response_token=980`、`response_token_sample_count=1`。
  - 通过脚本修复 + 回归测试完成收敛（见变更证据）。
- Phase 1：`已完成（本轮范围）`
  - 主规则瘦身与索引分流已完成。
  - `verification-entrypoints / global-repo-mapping / evidence-and-rollback-runbook / backflow-runbook / git-scope-and-tracked-files` 已落地。
- Phase 2：`进行中`
  - 已新增 `source/project/skills-manager/custom/overrides/governance-teaching-lite-output/SKILL.md` 草案。
  - 已新增 `source/project/skills-manager/custom/overrides/governance-clarification-protocol/SKILL.md` 试点草案。
  - 已解除跨仓数据阻断：`skills-manager` 侧 `trigger-eval summary` 已由 `no_data` 修复为 `ok`。
  - 当前 `create/promote` 仍未执行，原因从“数据缺失”变为“候选不满足 promotion 触发条件（如 no_material_delta / ack 未满足）”。
  - 证据：`docs/change-evidence/20260413-phase2-trigger-eval-gate-checkpoint.md`、`docs/change-evidence/20260413-phase2-cross-repo-trigger-eval-unblocked.md`。
- Phase 3：`进行中`
  - 已落地 `docs/governance/output-filter-policy.md`（先 advisory 再 enforce）。
  - 已补充 W0 试点对照报告（见变更证据）。
  - 已完成运行态噪声收敛：`report-growth-readiness` 默认输出改为 `docs/governance/reviews/growth-readiness-latest.md`，避免在 `docs/change-evidence/` 持续生成未跟踪文件。
  - 证据：`docs/change-evidence/20260413-phase3-growth-readiness-output-noise-fix.md`。
  - 下一步：按周对照质量指标并评估是否扩展到目标仓。
- Phase 4：`进行中`
  - 已启动观察窗口（2026-04-13~2026-04-27），证据：`docs/change-evidence/20260413-rule-layering-pilot-kickoff.md`。
  - 已沉淀 W0 基线对照：`docs/change-evidence/20260413-rule-layering-week0-baseline.md`。
  - 未完成项：窗口期满后输出周度对照与推广决策。
