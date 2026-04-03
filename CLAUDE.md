# CLAUDE.md — governance-kit（Claude 项目级）
**项目**: governance-kit  
**适用范围**: 项目级（仓库根）  
**版本**: 3.81  
**最后更新**: 2026-04-03

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/CLAUDE.md`，仅定义 governance-kit 的仓库落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（仅本仓）
### A.1 事实边界
- 本仓规则源目录：`source/`、`config/`、`templates/`、`hooks/`、`ci/`、`scripts/`、`tests/`。
- 分发以 `config/targets.json` 与 `config/project-rule-policy.json` 为准，禁止脱离配置表手工散落同步。
- `backups/` 为回滚证据区，覆盖式操作必须可追溯到快照。

### A.2 执行锚点
- 先定归宿再改动：项目级规则归宿为 `source/project/governance-kit/*`。
- 小步闭环：先 `plan` 预演，再 `safe` 落地；失败先修根因再重试。
- 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 N/A 本仓落地
- `platform_na`：平台能力缺失或命令不支持。
- `gate_na`：仅纯文档/注释/排版，或门禁脚本客观缺失。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`、`expires_at`。
- 不得改变门禁顺序：`build -> test -> contract/invariant -> hotspot`。

## B. Claude 平台差异（项目内）
### B.1 平台取证命令
- 必做：`claude --version`、`claude --help`。
- 状态能力探测：`claude --help | Select-String status`（有命令再执行，无则记 `platform_na`）。
- 加载链不可见时，补记 `active_rule_path`（仓库根同名文件）与来源说明。

### B.2 覆盖链与短期 override
- 推荐目录：`~/.claude`；以 CLI 实际加载结果为准。
- 优先级：`CLAUDE.override.md > CLAUDE.md > fallback`（平台支持时）。
- `CLAUDE.override.md` 仅用于短期排障；结论后删除并复测。

### B.3 平台异常回退
- 命令缺失或行为不一致：记录 `platform_na + reason + alternative_verification + evidence_link + expires_at`。
- 替代命令仅用于补证据，不改变门禁顺序与阻断语义。
- 禁止在仓内治理脚本中调用模型 CLI（含 `codex/claude/gemini exec`）做自动修复；自动修复必须由当前 AI 会话代理执行。

## C. 项目差异（领域与技术）
### C.1 模块职责与归宿
- `source/global/`：全局规则源（AGENTS/CLAUDE/GEMINI）。
- `source/project/<RepoName>/`：项目级规则源与 custom 分发文件。
- `config/`：分发映射、灰度策略、白名单与基线配置。
- `scripts/`：安装、校验、回灌、审计、优化执行层。
- `tests/`：治理脚本回归与防退化用例。

### C.2 硬门禁命令与顺序
- build：`powershell -File scripts/verify-kit.ps1`
- test：`powershell -File tests/governance-kit.optimization.tests.ps1`
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
- 最低字段：规则 ID、风险等级、执行命令、关键输出、回滚动作。

### C.6 配置一致性与兼容
- `config/repositories.json`、`targets.json`、`rule-rollout.json`、`project-rule-policy.json`、`project-custom-files.json` 必须协同。
- 新增仓库必须通过 `add-repo.ps1` 落地，禁止手工只改单一配置。
- 数据结构变更需同步更新校验脚本与测试夹具，并提供回滚路径。

### C.7 目标仓直改回灌策略
- source of truth：`E:/CODE/governance-kit/source/project/governance-kit/*`。
- 允许在目标仓根 `AGENTS/CLAUDE/GEMINI` 临时直改试验，但同日必须回灌到 source 并留证据。
- 回灌后执行：`powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe`。
- 未完成“回灌 + 复验”前，禁止再次 `sync/install` 覆盖未沉淀改动。

### C.8 CI 与仓内校验入口
- GitHub Actions：`.github/workflows/quality-gates.yml`
- Azure Pipelines：`azure-pipelines.yml`
- GitLab CI：`.gitlab-ci.yml`
- Hooks：`Test-Path .git/hooks/pre-commit`、`Test-Path .git/hooks/pre-push`
- Git 配置：`git config --get commit.template`、`git config --get governance.kitRoot`
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

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复述全局规则正文。
- 与全局职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 三文件同构约束：`A/C/D` 语义一致，仅 `B` 允许平台差异。
- 规则升级后同步校验版本、日期、承接映射与门禁命令一致性。
- 平台差异仅在 B 段表达；A/C/D 不承载平台实现细节。

