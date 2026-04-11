# AGENTS.md — repo-governance-hub（Codex 项目级）
**项目**: repo-governance-hub  
**适用范围**: 项目级（仓库根）  
**版本**: 3.85  
**最后更新**: 2026-04-10

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/AGENTS.md`，仅定义 repo-governance-hub 的仓库落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（仅本仓）
### A.1 事实边界
- 本仓规则源目录：`source/`、`config/`、`templates/`、`hooks/`、`ci/`、`scripts/`、`tests/`。
- 分发以 `config/targets.json` 与 `config/project-rule-policy.json` 为准，禁止脱离配置表手工散落同步。
- `backups/` 为回滚证据区，覆盖式操作必须可追溯到快照。

### A.2 执行锚点
- 先定归宿再改动：项目级规则归宿为 `source/project/repo-governance-hub/*`。
- 小步闭环：先 `plan` 预演，再 `safe` 落地；失败先修根因再重试。
- 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 N/A 本仓落地
- `platform_na`：平台能力缺失或命令不支持。
- `gate_na`：仅纯文档/注释/排版，或门禁脚本客观缺失。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`、`expires_at`。
- 不得改变门禁顺序：`build -> test -> contract/invariant -> hotspot`。

### A.4 触发式澄清协议（本仓）
- 默认执行模式：`direct_fix`；证据充分时直接修复并闭环验证。
- 触发升级：同一 `issue_id` 连续失败、修复后反复回退、用户意图冲突时，自动转 `clarification_mode`。
- 前置触发：即使未达失败阈值，只要出现目标语义冲突或验收口径不一致，也应提前进入澄清。
- 澄清上限：单轮最多 3 个问题，必须与“可执行决策”直接相关，禁止发散问答。
- 澄清落证：将“用户原意/误解点/确认结论/接受标准/回滚点”写入 `docs/change-evidence/` 后再继续自动执行。
- 退出条件：达成接受标准并通过 `build -> test -> contract/invariant -> hotspot`，同时清理该 `issue_id` 的澄清挂起状态。

### A.5 教学协作与认知对齐协议（本仓）
- 默认协作形态：`delivery + teaching` 双通道；每次输出至少包含“执行结论 + 认知增益”。
- 默认教学档位：`lite`；仅在高风险、连续误解或用户明确要求时升级为 `standard/deep`。
- Lite 短答模板：优先使用 `结论 -> 原因 -> 下一步` 三行结构，先解决当前阻塞点。
- 任务理解快照：开始执行前必须明确 `目标/非目标/验收标准/关键假设`，用于与用户原意对齐。
- 术语解释义务：新术语首次出现时，至少给出 `一句话定义 + 本仓示例 + 常见误解`。
- 术语去重：术语首次解释后后续默认只引用术语名，避免重复展开。
- 里程碑对齐回声：`开始前`、`首次改动前`、`门禁前`、`提交前` 必须复述“当前在做什么、为何这样做、与用户原意映射”。
- 对齐压缩句式：里程碑复述优先使用“我在做X，为了Y，验收看Z”单句模板。
- 可观测性教学：遇到问题时按 `现象 -> 假设 -> 验证命令 -> 预期结果 -> 下一步` 输出，指导用户观察与排查。
- 假设显式化：关键推断必须标注 `已确认/未确认`；未确认继续执行时，必须同步 `风险与回滚点`。

### A.6 需求/功能/设计主动建议协议（本仓）
- 默认模式：`lite`；每轮主动建议上限 `1-2` 条，优先一句话可执行建议，避免长解释。
- 升级到 `standard` 的触发场景：`需求澄清`、`方案设计`、`架构选型`、`上线前评审`；升级后上限 `2-3` 条。
- 建议主题至少覆盖其一：`风险前置`、`替代方案`、`验收口径`、`最小可行路径（MVP）`。
- 去重规则：同一 `topic_signature` 在冷却窗口内默认不重复建议；仅在需求显著变化或用户追问时重触发。
- 降级规则：用户明确“只执行不建议/不要扩展”时切 `silent`；仅执行主任务。
- 执行边界：建议“可采纳可忽略”，不得改变用户主指令优先级，不得阻断当前任务。
- 策略文件：`.governance/proactive-suggestion-policy.json`（缺失时回退模板内默认值）。
- 建议留痕字段：`proactive_suggestion_mode(silent|lite|standard)`、`suggestion_count`、`suggestion_topics`、`topic_signature`、`dedupe_skipped`、`user_opt_out`。

## B. Codex 平台差异（项目内）
### B.1 平台取证命令
- 必做：`codex --version`、`codex --help`、`codex status`。
- 状态优先：`codex status`；非交互失败（如 `stdin is not a terminal`）记 `platform_na`。
- 扩展能力采用“先探测后调用”：`codex --help` 可见再执行 `exec/review/mcp/sandbox/cloud/app-server/features`。
- 加载链不可见时，补记 `active_rule_path`（仓库根同名文件）与来源说明。

### B.2 覆盖链与短期 override
- 目录：`~/.codex`（可由 `CODEX_HOME` 覆盖）。
- 优先级：`AGENTS.override.md > AGENTS.md > fallback`。
- `AGENTS.override.md` 仅用于短期排障；结论后删除并复测。

### B.3 平台异常回退
- 命令缺失或行为不一致：记录 `platform_na + reason + alternative_verification + evidence_link + expires_at`。
- 替代命令仅用于补证据，不改变门禁顺序与阻断语义。
- Windows 原生环境若遇到 Codex Hooks 官方临时不可用，按 `platform_na` 记录并回退到仓内 `hooks/pre-commit + hooks/pre-push`。
- 禁止在仓内治理脚本中调用 `codex exec`（或任何模型 CLI 套娃调用）做自动修复；自动修复必须由当前 AI 会话代理执行。

## C. 项目差异（领域与技术）
### C.1 模块职责与归宿
- `source/global/`：全局规则源（AGENTS/CLAUDE/GEMINI）。
- `source/project/<RepoName>/`：项目级规则源与 custom 分发文件。
- `config/`：分发映射、灰度策略、白名单与基线配置。
- `scripts/`：安装、校验、回灌、审计、优化执行层。
- `tests/`：治理脚本回归与防退化用例。

### C.2 硬门禁命令与顺序
- build：`powershell -File scripts/verify-kit.ps1`
- test：`powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- contract/invariant：`powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
- hotspot：`powershell -File scripts/doctor.ps1`
- quick gate：`gate_na (quick gate script not found)`
- fixed order：`build -> test -> contract/invariant -> hotspot`

### C.3 命令存在性与 gate_na 回退
- precheck：`Get-Command powershell`、`Test-Path scripts/verify-kit.ps1`、`Test-Path scripts/verify.ps1`、`Test-Path scripts/validate-config.ps1`、`Test-Path scripts/doctor.ps1`。
- test 脚本不可执行：`test=gate_na`，至少执行 `verify-kit + validate-config + verify` 并记录测试覆盖缺口。
- quick gate 缺失：保持 `quick gate=gate_na`，不影响硬门禁顺序与阻断语义。

### C.4 失败分流与阻断
- build 失败：阻断，先修仓完整性或规则元数据缺失。
- test 失败：阻断，先修脚本行为退化或测试夹具失配。
- contract/invariant 失败：高风险阻断，禁止继续分发与覆盖。
- hotspot 失败：阻断，按失败步骤修复后重跑整链路。
- 执行器边界：脚本仅负责门禁编排与失败上下文输出；修复与重试由外层 AI 代理会话连续执行。

### C.5 证据与回滚
- 证据目录：`docs/change-evidence/`，建议命名 `YYYYMMDD-topic.md`。
- 回滚入口：`scripts/restore.ps1` + `backups/<timestamp>/`。
- 最低字段：规则 ID、风险等级、执行命令、关键输出、回滚动作、任务理解快照、术语解释点、可观测信号、排障路径、未确认假设与纠偏结论、learning_points_3、reusable_checklist、open_questions。

### C.6 配置一致性与兼容
- `config/repositories.json`、`targets.json`、`rule-rollout.json`、`project-rule-policy.json`、`project-custom-files.json` 必须协同。
- 新增仓库必须通过 `add-repo.ps1` 落地，禁止手工只改单一配置。
- 数据结构变更需同步更新校验脚本与测试夹具，并提供回滚路径。

### C.7 目标仓直改回灌策略
- source of truth：`E:/CODE/repo-governance-hub/source/project/repo-governance-hub/*`。
- 允许在目标仓根 `AGENTS/CLAUDE/GEMINI` 临时直改试验，但同日必须回灌到 source 并留证据。
- 回灌后执行：`powershell -File E:/CODE/repo-governance-hub/scripts/install.ps1 -Mode safe`。
- 未完成“回灌 + 复验”前，禁止再次 `sync/install` 覆盖未沉淀改动。

### C.8 CI 与仓内校验入口
- GitHub Actions：`.github/workflows/quality-gates.yml`
- Azure Pipelines：`azure-pipelines.yml`
- GitLab CI：`.gitlab-ci.yml`
- Hooks：`Test-Path .git/hooks/pre-commit`、`Test-Path .git/hooks/pre-push`
- Git 配置：`git config --get commit.template`、`git config --get governance.kitRoot`
- 里程碑自动提交：治理闭环在策略允许时可于 `after_backflow`、`after_redistribute_verify`、`cycle_complete` 执行 `git add -A + 中文提交说明`，并在提交后强校验工作区干净；执行前必须先识别并隔离非本次治理改动，避免误纳入提交。
- 一键安装语义：`install/sync` 默认先执行 `scripts/refresh-targets.ps1`（基于 `repositories.json + project-custom-files.json` 刷新 `targets.json`），再执行分发安装。
- 模板：`Test-Path docs/change-evidence/template.md`、`Test-Path docs/governance/waiver-template.md`、`Test-Path docs/governance/metrics-template.md`

### C.9 承接映射（Global -> Repo）
- R1：A.2 + C.1 + C.7（归宿先行与回灌闭环）。
- R2/R3：A.2 + C.2 + C.3（小步闭环与根因优先）。
- R4/R6：C.2 + C.3 + C.4（硬门禁、N/A 回退与阻断）。
- R7：A.1 + C.6（边界与兼容保护）。
- R8/E3：A.2 + C.5（证据与回滚可追溯）。
- E4/E5/E6：C.4 + C.6 + C.8（指标、供应链与结构变更配套校验）。
- Global 输出字段 -> Repo 证据字段：`N/A 分类/判定标准 -> A.3`，`门禁语义 -> C.2/C.4`，`证据要求 -> C.5`。

### C.10 协同接口（1+1>2）
- Global 负责：规则语义、判定标准、N/A 口径。
- Repo 负责：门禁命令、证据位置、回滚入口、阻断决策。
- 约束：同一规则语义不跨层重复定义；项目级不得覆盖全局语义。

### C.11 Git 提交与推送边界（“全部”定义）
- `整理提交全部` 的“全部”仅指：`本次任务相关 + 应被版本管理 + 通过 tracked-files-policy/.gitignore 的文件`。
- 未跟踪文件处置默认由外层 AI 自动执行：`自动判定(任务产物/运行产物/风险文件) -> 自动处理(纳入提交/加入忽略/保持未跟踪)`，并写入证据。
- 仅当语义不清、存在破坏性删除风险、或与用户显式意图冲突时，才升级提示用户确认。
- 默认不纳入“全部”：IDE/agent 本地配置、临时文件、日志、备份、调试残留、缓存与本地运行态目录。
- `push` 仅推送已存在的 commit 历史，不再次筛选文件；文件筛选必须在 `git add/commit` 前完成。
- 未跟踪文件仅在被确认为本次任务产物且满足策略时纳入提交；否则保持未跟踪。
- 测试文件判定：提交前必须执行 `scripts/governance/check-tracked-files.ps1 -Scope pending -AsJson`，读取 `test_file_suggestions`。
- `suggested_action=ignore`：不得纳入 commit/push；`suggested_action=track`：可纳入；`suggested_action=review_required`：先由外层 AI 明确归类后再继续。
- 策略阻断：当 `.governance/tracked-files-policy.json` 启用 `block_on_test_file_review_required=true` 时，存在 `review_required` 将直接阻断提交/推送。
- 执行 `git add -A` 前必须先隔离非本次改动，避免误纳入。

### C.12 外层 AI 教学执行条款
- 教学目标：在推进任务同时帮助用户理解术语、原理、本质、设计取舍与排障方法。
- 输出模板：默认采用 `执行结论/证据 + 教学说明/方法迁移`；简单任务可压缩但不得省略关键术语解释。
- 默认输出长度策略：先摘要后展开；未被要求时不输出长背景知识。
- 分级展开：`lite` 仅给关键结论与最小解释，`standard` 补方法迁移，`deep` 才展开原理细节。
- 误解主动识别：出现“现象与期望矛盾、用户表述与验收冲突、重复返工迹象”时，优先进入解释与对齐，而非直接堆叠改动。
- 用户观察指引：每次 bug 修复应给出可观察信号（日志、状态、数据、接口行为）与最小复现/复验步骤。
- 方法迁移：在不增加噪音前提下，补充“为何不用其他方案”的边界说明，避免机械套用。
- token 预算护栏：每轮优先控制在 `lite` 预算内，超过预算需先压缩后再扩展。

### C.13 教学质量指标与持续优化
- 推荐指标：`误解触发率`、`澄清后返工率`、`一次通过率`、`用户二次追问率`。
- 效率指标：补充 `平均响应token`、`单任务token`、`token/有效结论比`，用于评估教学性价比。
- 采集位置：`docs/change-evidence/` 与 `docs/governance/metrics-template.md`。
- 优化原则：按指标趋势迭代规则与提示词，优先降低返工与语义偏差。

### C.14 治理问题优先修复顺序
- 发现与 repo-governance-hub 规则/脚本/配置相关的问题时，必须先在 `E:/CODE/repo-governance-hub` 修复 source of truth。
- 修复后按固定顺序复验：`build -> test -> contract/invariant -> hotspot`，确认通过后再在目标仓执行相关命令。
- 禁止带着已知治理问题继续分发、提交或推送。
- 若为临时止血，需在证据中记录回收时点与最终归宿。
### C.15 周期更新触发器（最佳实践）
- 触发策略文件：`config/update-trigger-policy.json`；默认由 `scripts/governance/check-update-triggers.ps1` 执行。
- 周检入口：`scripts/governance/run-recurring-review.ps1`，内置更新触发检查并输出告警计数。
- 月检入口：`scripts/governance/run-monthly-policy-review.ps1`，将更新触发告警写入月报。
- 建议告警优先级：`cli_version_drift -> waiver_expired_unrecovered -> rollout_observe_overdue -> metrics_snapshot_stale -> platform_na_expired`。
### C.16 子代理并行触发矩阵（本仓）
- 策略源：`config/subagent-trigger-policy.json`；分发落点：目标仓 `.governance/subagent-trigger-policy.json`。
- 判定模型：`hard_guard + score`；先执行硬约束，再依据评分阈值输出并行建议与 `max_parallel_agents`。
- 证据字段：`spawn_parallel_subagents`、`max_parallel_agents`、`decision_score`、`reason_codes`、`hard_guard_hits`、`signals`、`policy_path`。
- 执行边界：`scripts/governance/run-target-autopilot.ps1` 仅输出建议与 JSON 证据；并行子代理创建由外层 AI 会话执行。
## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复述全局规则正文。
- 与全局职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 三文件同构约束：`A/C/D` 语义一致，仅 `B` 允许平台差异。
- 规则升级后同步校验版本、日期、承接映射与门禁命令一致性。
- 平台差异仅在 B 段表达；A/C/D 不承载平台实现细节。








