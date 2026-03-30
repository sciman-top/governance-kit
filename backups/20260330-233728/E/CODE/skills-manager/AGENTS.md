# AGENTS.md — Skills Manager（Codex 项目级）
**项目**: skills-manager  
**适用范围**: 项目级（仓库根）  
**版本**: 3.78  
**最后更新**: 2026-03-30

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/AGENTS.md`，仅定义 Skills Manager 的仓库落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（仅本仓）
### A.1 事实边界
- 单一入口：`skills.ps1`；单一配置源：`skills.json`。
- `agent/` 与 `vendor/` 为生成/缓存目录；`agent/` 禁止手改。
- 自定义改动优先落在 `overrides/`、`imports/`，避免直接改第三方缓存。

### A.2 执行锚点
- 规则目标归宿：`E:/CODE/governance-kit/source/project/skills-manager/*`。
- 每次变更必须留痕：`依据 -> 命令 -> 证据 -> 回滚`。
- 证据默认目录：`docs/change-evidence/`；文件名建议：`YYYYMMDD-<platform>-<topic>.md`。

### A.3 N/A 策略
- 仅在命令/脚本客观不存在或环境不可用时允许 N/A。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`。
- N/A 不得改变门禁顺序：`build -> test -> contract/invariant -> hotspot`。

## B. Codex 平台差异（项目内）
### B.1 加载与覆盖
- 用户目录：`~/.codex`（可由 `CODEX_HOME` 覆盖）。
- 规则优先级：`AGENTS.override.md > AGENTS.md > fallback`。
- override 仅用于短期排障，结论后必须清理并复测。

### B.2 诊断与留痕
- 诊断顺序：`codex --version -> codex --help -> codex status`。
- `codex status` 若失败（如 `stdin is not a terminal`），按 B.4 记录 N/A，不阻断后续仓内门禁。
- 证据最小字段：`cmd`、`exit_code`、`key_output`、`timestamp`、`active_rule_path`、`source`。
- `active_rule_path` 默认记录：`E:/CODE/skills-manager/AGENTS.md`（当 CLI 未显式提供加载链时）。

### B.3 平台能力剖面
- 以 `codex status` 作为首选状态入口。
- 若 CLI 未显示加载链，必须在证据文件补记 `active_rule_path` 与判定来源（命令输出/人工判定）。

### B.4 平台异常回退
- 命令缺失或行为不一致时，记录：`N/A`、原因、替代命令、证据位置。
- 替代命令仅用于补证据，不改变门禁顺序与阻断语义。

## C. 项目差异（领域与技术）
### C.1 模块职责与归宿
- `skills.ps1`：统一命令调度（发现/安装/构建/更新/doctor/MCP）。
- `build.ps1`：拼装 `src/*` 生成根目录 `skills.ps1`。
- `skills.json`：`vendors/mappings/targets/sync_mode/mcp_servers` 唯一配置源。
- `overrides/`、`imports/`：本地可维护输入层；`agent/`：最终分发产物。

### C.2 门禁命令与顺序（硬门禁）
- build：`./build.ps1`
- test：`./skills.ps1 发现`
- contract/invariant：`./skills.ps1 doctor --strict`
- hotspot：`./skills.ps1 构建生效`
- fixed order：`build -> test -> contract/invariant -> hotspot`

### C.3 命令存在性与 N/A 回退验证
- precheck：`Get-Command powershell`、`Test-Path ./skills.ps1`、`Test-Path ./build.ps1`。
- `doctor --strict` 不可执行：标记 `contract/invariant=N/A`，执行 `发现 + 构建生效`，记录契约风险。
- `构建生效` 受环境限制：标记 `hotspot=N/A`，至少完成 `build + doctor --strict`，记录未覆盖风险。

### C.4 失败分流与阻断
- build 失败：阻断，先修构建脚本与入口拼装错误。
- test 失败：阻断，先修发现链路与映射异常。
- contract/invariant 失败：高风险阻断，禁止分发。
- hotspot 失败：阻断；若 N/A 按 C.3 补齐替代验证与证据。

### C.5 构建、生效与回滚
- 构建：`./build.ps1`。
- 生效：`./skills.ps1 构建生效`。
- 最小验证：`./skills.ps1 doctor --strict`。
- 回滚：恢复 `skills.json` 与 `overrides/` 后重新执行 `构建生效`。

### C.6 同步与目录策略
- `sync_mode=link` 优先；`sync_mode=sync` 作为受限环境回退。
- 若 `skills.json.targets` 含 `.codex/skills`，必须验证其与 `agent/` 同步状态。

### C.7 目标仓直改回灌策略
- source of truth：`E:/CODE/governance-kit/source/project/skills-manager/*`。
- 允许在 `E:/CODE/skills-manager` 临时直改试验，但同日必须回灌并留证据。
- 回灌后必须执行：`powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe`。
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
- R7：A.1 + C.1（边界与兼容保护）。
- R8/E3：A.2 + C.5（证据与回滚可追溯）。
- E4/E5/E6：C.4 + C.6 + C.8（指标、供应链与结构变更配套校验）。

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复述全局规则正文。
- 与全局职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 三文件同构约束：`A/C/D` 必须语义一致，仅 `B` 允许平台差异。
- 升级后同步校验三文件版本、日期、承接映射与门禁命令一致性。
