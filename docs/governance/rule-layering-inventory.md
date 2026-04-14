# Rule Layering Inventory (Phase 0)

## Scope
- Source files:
  - `AGENTS.md` (Codex project-level)
  - `CLAUDE.md` (Claude project-level)
  - `GEMINI.md` (Gemini project-level)
- Method:
  - Keep only always-needed protocol in main rule files.
  - Move long process text to repo docs or skills with on-demand loading.

## Decision Labels
- `keep_core`: keep in main rule file (always-loaded minimum protocol).
- `keep_index`: keep only short index/entry in main rule file.
- `move_repo_doc`: move body text to `docs/governance/*.md`.
- `move_skill`: move reusable flow to `source/project/repo-governance-hub/custom/overrides/*/SKILL.md`.
- `platform_specific_keep`: keep in platform file `B.*` only.

## Inventory Table
| Section | Current Files | Decision | Target | Priority | Reason |
|---|---|---|---|---|---|
| `1. 阅读指引` | All 3 | `keep_core` | Main files | P0 | 必须说明承接关系与裁决链。 |
| `A.1 事实边界` | All 3 | `keep_core` | Main files | P0 | 仓库边界与 source of truth 必须常驻。 |
| `A.2 执行锚点` | All 3 | `keep_core` | Main files | P0 | 先定归宿、小步闭环、留痕是硬行为约束。 |
| `A.3 N/A 本仓落地` | All 3 | `keep_core` | Main files | P0 | gate 语义与最小字段不可按需加载。 |
| `A.4 触发式澄清协议` | AGENTS only | `move_skill` + `keep_index` | `source/project/repo-governance-hub/custom/overrides/governance-clarification-protocol/SKILL.md` + main index | P1 | 规则较长且是复用流程，适合 skill 化。 |
| `A.4 教学协作与认知对齐` | CLAUDE/GEMINI | `move_skill` + `keep_index` | `source/project/repo-governance-hub/custom/overrides/governance-teaching-lite-output/SKILL.md` + main index | P1 | 长文本、高复用、可按需触发。 |
| `A.5 教学协作与认知对齐` | AGENTS | `move_skill` + `keep_index` | same as above | P1 | 与 CLAUDE/GEMINI 同语义，避免三处重复。 |
| `A.5 需求/功能/设计主动建议` | CLAUDE/GEMINI | `move_repo_doc` + `keep_index` | `docs/governance/proactive-suggestion-policy.md` | P1 | 策略解释可外移；主规则保留边界约束。 |
| `A.6 需求/功能/设计主动建议` | AGENTS | `move_repo_doc` + `keep_index` | same as above | P1 | 与上同。 |
| `B.1 平台取证命令` | Each platform file | `platform_specific_keep` | `AGENTS.md/CLAUDE.md/GEMINI.md` | P0 | 平台差异必须在 B 段保留。 |
| `B.2 覆盖链与 override` | Each platform file | `platform_specific_keep` | Main files `B.2` | P0 | 平台加载链是关键排障信息。 |
| `B.3 平台异常回退` | Each platform file | `platform_specific_keep` + `move_repo_doc` | Main files + `docs/governance/platform-fallback-runbook.md` | P1 | 主规则保留原则；详细案例移 runbook。 |
| `C.1 模块职责与归宿` | All 3 | `keep_core` | Main files | P0 | 项目边界与归宿必须常驻。 |
| `C.2 硬门禁命令与顺序` | All 3 | `keep_core` | Main files | P0 | 执行入口与顺序是硬约束。 |
| `C.3 命令存在性与 gate_na` | All 3 | `keep_core` | Main files | P0 | 缺失回退逻辑必须常驻。 |
| `C.4 失败分流与阻断` | All 3 | `keep_core` | Main files | P0 | 阻断语义必须常驻。 |
| `C.5 证据与回滚` | All 3 | `keep_core` + `move_repo_doc` | Main files + `docs/governance/evidence-and-rollback-runbook.md` | P1 | 最低字段常驻；模板和示例外移。 |
| `C.6 配置一致性与兼容` | All 3 | `keep_core` | Main files | P0 | 兼容/一致性要求不宜外移。 |
| `C.7 目标仓直改回灌策略` | All 3 | `keep_core` + `move_repo_doc` | Main + `docs/governance/backflow-runbook.md` | P1 | 主规则保留禁止项，流程细节外移。 |
| `C.8 CI 与仓内校验入口` | All 3 | `move_repo_doc` + `keep_index` | `docs/governance/verification-entrypoints.md` | P1 | 列表偏长、变化频繁，适合文档化。 |
| `C.9 承接映射（Global -> Repo）` | All 3 | `move_repo_doc` + `keep_index` | `docs/governance/global-repo-mapping.md` | P1 | 映射可文档维护；主规则留一行指向。 |
| `C.10 协同接口（1+1>2）` | All 3 | `keep_core` | Main files | P0 | 跨层边界要求应常驻。 |
| `C.11 Git 提交与推送边界` | All 3 | `keep_core` + `move_repo_doc` | Main + `docs/governance/git-scope-and-tracked-files.md` | P1 | 关键约束保留，细节流程外移。 |
| `C.12 外层 AI 教学执行条款` | All 3 | `move_skill` + `keep_index` | `governance-teaching-lite-output` skill | P1 | 长规则且重复，最适合 skill。 |
| `C.13 教学质量指标与持续优化` | All 3 | `move_repo_doc` + `keep_index` | `docs/governance/teaching-quality-metrics.md` | P2 | 指标口径文档化便于长期演进。 |
| `C.14 治理问题优先修复顺序` | All 3 | `keep_core` | Main files | P0 | source-of-truth 修复顺序必须常驻。 |
| `C.15 周期更新触发器` | All 3 | `move_repo_doc` + `keep_index` | `docs/governance/update-trigger-runbook.md` | P2 | 周检/月检说明宜放 runbook。 |
| `C.16 子代理并行触发矩阵` | All 3 | `move_skill` + `keep_index` | `source/project/repo-governance-hub/custom/overrides/governance-subagent-trigger/SKILL.md` | P2 | 判定流程可技能化，主规则保留边界。 |
| `C.17 与 skills-manager 联合协作契约` | All 3 | `keep_core` + `keep_index` | Main files + `docs/governance/collaboration-contract-repo-skills-manager.md` | P0 | 跨仓联合协作关系属于执行边界，必须常驻明确。 |
| `C.18 standalone 发布依赖边界` | All 3 | `keep_core` + `keep_index` | Main files + `docs/governance/standalone-release-dependency-contract.md` | P0 | 需要显式区分“协作依赖”与“单仓发布可移植性”，防止发布时隐式外部路径耦合。 |
| `D. 维护校验清单` | All 3 | `keep_core` | Main files | P0 | 文档治理底线应常驻。 |

## First-Wave Backlog (Directly Executable)
1. `[done]` Create `docs/governance/rule-index.md` and add section links by scenario.
2. `[done]` Create `docs/governance/verification-entrypoints.md` and move `C.8` body there.
3. `[done]` Create `docs/governance/global-repo-mapping.md` and move `C.9` body there.
4. `[done]` Draft skill `governance-teaching-lite-output` in `source/project/repo-governance-hub/custom/overrides/`.
5. `[done]` Reduce duplicated long text in `AGENTS.md/CLAUDE.md/GEMINI.md` to index entries.

## Acceptance Checklist
- [x] Main rule files keep `1/A/B/C/D` structure unchanged.
- [x] `B` remains platform-specific and not moved into `A/C/D`.
- [x] Hard gate semantics remain visible in main files.
- [x] All moved sections have explicit target docs/skills and cross-links.
- [x] No script path in gates is changed during inventory phase.
