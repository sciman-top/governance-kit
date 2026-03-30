# CLAUDE.md — governance-kit（Claude 项目级）
**项目**: governance-kit  
**适用范围**: 项目级（仓库根）  
**版本**: 3.77  
**最后更新**: 2026-03-30

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/CLAUDE.md`，仅定义 governance-kit 的仓库落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（仅本仓）
### A.1 事实边界
- 本仓是治理规则唯一源目录：`source/`、`config/`、`templates/`、`hooks/`、`ci/`、`scripts/`、`tests/`。
- 规则分发以 `config/targets.json` 与 `config/project-rule-policy.json` 为准，禁止脱离配置表手工散落同步。
- `backups/` 为回滚证据区，任何覆盖式操作都应可追溯到备份快照。

### A.2 执行锚点
- 先定归宿再改动：项目级规则最终归宿为 `source/project/governance-kit/*`。
- 小步闭环执行：先 `plan` 预演，再 `safe` 落地，失败先修根因后重试。
- 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 N/A 策略
- 仅在命令/脚本客观不存在时允许 N/A。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`。
- N/A 不得改变门禁顺序：`build -> test -> contract/invariant -> hotspot`。

## B. Claude 平台差异（项目内）
### B.1 加载与覆盖
- 推荐目录：`~/.claude`；实际以 CLI 加载结果为准。
- 优先级：`CLAUDE.override.md > CLAUDE.md > fallback`（平台支持时）。
- override 仅用于短期排障，结论后必须清理并复测。

### B.2 最小诊断矩阵
- 必做：`claude --version -> claude --help`。
- 状态/加载链类命令按“若支持则执行”。
- 留痕最低字段：`cmd`、`exit_code`、`key_output`、`timestamp`。

### B.3 平台能力剖面
- 状态命令能力不可强制假定存在。
- CLI 未显式展示加载链时，补记 `active_rule_path` 与来源。
- override 能力不可用时，按 `reason + alternative_verification + evidence_link` 落证。

### B.4 平台异常回退
- 命令缺失或行为不一致时，必须记录：`N/A`、原因、替代命令、证据位置。
- 替代命令仅用于补证据，不得改变门禁顺序与阻断语义。

## C. 项目差异（领域与技术）
### C.1 模块职责与归宿
- `source/global/`：全局规则源（AGENTS/CLAUDE/GEMINI）。
- `source/project/<RepoName>/`：项目级规则源与 custom 分发文件。
- `config/`：分发映射、灰度策略、白名单与基线配置。
- `scripts/`：安装、校验、回灌、审计、优化脚本执行层。
- `tests/`：治理脚本回归测试与防退化用例。

### C.2 门禁命令与顺序（硬门禁）
- build：`powershell -File scripts/verify-kit.ps1`
- test：`powershell -File tests/governance-kit.optimization.tests.ps1`
- contract/invariant：`powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
- hotspot：`powershell -File scripts/doctor.ps1`
- quick gate（开发快速复验，不替代硬门禁）：`N/A (quick gate script not found)`
- fixed order：`build -> test -> contract/invariant -> hotspot`

### C.3 命令存在性与 N/A 回退验证
- precheck：`Get-Command powershell`、`Test-Path scripts/verify-kit.ps1`、`Test-Path scripts/verify.ps1`、`Test-Path scripts/validate-config.ps1`、`Test-Path scripts/doctor.ps1`。
- test 脚本不可执行：标记 test=N/A，至少执行 `verify-kit + validate-config + verify` 并记录测试覆盖缺口。
- quick gate 缺失：保持 quick gate=N/A，不影响硬门禁顺序与阻断语义。

### C.4 失败分流与阻断
- build 失败：阻断，先修仓完整性或规则元数据缺失。
- test 失败：阻断，先修脚本行为退化或测试夹具失配。
- contract/invariant 失败：高风险阻断，禁止继续分发与覆盖。
- hotspot（doctor）失败：阻断，需按失败步骤逐项修复后重跑整链路。

### C.5 证据与回滚
- 证据目录：`docs/change-evidence/`，建议命名 `YYYYMMDD-topic.md`。
- 回滚入口：`scripts/restore.ps1` + `backups/<timestamp>/` 快照。
- 最低证据字段：规则 ID、风险等级、执行命令、关键输出、回滚动作。

### C.6 配置一致性与兼容
- `config/repositories.json`、`targets.json`、`rule-rollout.json`、`project-rule-policy.json`、`project-custom-files.json` 必须协同。
- 新增仓库必须通过 `add-repo.ps1` 落地，禁止手工只改单一配置。
- 数据结构变更需同步更新校验脚本与测试夹具，并提供回滚路径。

### C.7 目标仓直改回灌策略
- source of truth：`E:/CODE/governance-kit/source/project/governance-kit/*`。
- 允许在目标仓根 `AGENTS/CLAUDE/GEMINI` 临时直改试验，但同日必须回灌到 source 并留证据。
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
- R7：A.1 + C.6（边界与兼容保护）。
- R8/E3：A.2 + C.5（证据与回滚可追溯）。
- E4/E5/E6：C.4 + C.6 + C.8（指标、供应链与结构变更配套校验）。

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复述全局规则正文。
- 与全局职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 三文件同构约束：`A/C/D` 必须语义一致，仅 `B` 允许平台差异。
- 规则升级后同步校验三文件版本、日期、承接映射与门禁命令一致性。
