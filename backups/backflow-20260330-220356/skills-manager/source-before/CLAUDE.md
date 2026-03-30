# CLAUDE.md — Skills Manager（Claude 项目级）
**适用范围**: 项目级（仓库根）  
**版本**: 3.76  
**最后更新**: 2026-03-30

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/CLAUDE.md`，仅定义 Skills Manager 落地动作（WHERE/HOW）。
- 本仓入口是 `skills.ps1`，构建脚本是 `build.ps1`；优先复用仓库既有命令。
- 固定结构：`1 / A / B / C / D`。

## A. 共性基线（项目级）
### A.1 事实边界
- 单一入口：`skills.ps1`；单一配置源：`skills.json`。
- `agent/` 与 `vendor/` 为生成/缓存目录；`agent/` 禁止手改。
- 自定义改动优先放 `overrides/` 或 `imports/`。

### A.2 变更原则
- 先定义归宿再改动：`source/project/skills-manager/*` 是规则唯一归宿。
- 批量改动最小化回归面，优先修复根因。
- 每次变更留痕：`依据 -> 命令 -> 结果 -> 回滚点`。

### A.3 N/A 策略
- 仅在命令客观不存在时可标记 N/A。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`。
- N/A 不得改变门禁顺序语义：`build -> test -> contract/invariant -> hotspot`。

## B. Claude 平台差异（项目内）
### B.1 加载与诊断
- 规则优先级：`CLAUDE.override.md > CLAUDE.md > fallback`。
- 最小诊断链：`claude --version -> claude --help`（状态命令若支持则补充）。
- 若命令不可用，记录 N/A 原因与替代证据。

### B.2 目录同步差异
- 若 `skills.json.targets` 含 `.claude/skills`，需验证其与 `agent/` 同步状态。
- `sync_mode=link` 优先；`sync_mode=sync` 作为无链接权限回退。

## C. 项目差异（Skills Manager）
### C.1 模块职责
- `skills.ps1`：统一命令调度（发现/安装/构建/更新/doctor/MCP）。
- `build.ps1`：拼装 `src/*` 生成根目录 `skills.ps1`。
- `skills.json`：`vendors/mappings/targets/sync_mode/mcp_servers` 的唯一配置源。
- `overrides/`、`imports/`：可维护输入层；`agent/`：分发产物。

### C.2 门禁命令与执行顺序
- build：`./build.ps1`
- test：`./skills.ps1 发现`
- contract/invariant：`./skills.ps1 doctor --strict`
- hotspot：`./skills.ps1 构建生效`
- fixed order：`build -> test -> contract/invariant -> hotspot`

### C.3 命令缺失与回退验证
- precheck：`Get-Command powershell`、`Test-Path ./skills.ps1`、`Test-Path ./build.ps1`。
- 若 `doctor --strict` 不可执行：标记 contract/invariant=N/A，执行 `./skills.ps1 发现 + 构建生效` 并记录风险。
- 若 `构建生效` 受环境限制：标记 hotspot=N/A，至少完成 `build + doctor --strict` 并记录风险。

### C.4 构建/验证/回滚
- 构建：`./build.ps1`。
- 生效：`./skills.ps1 构建生效`。
- 最小验证：`./skills.ps1 doctor --strict`。
- 回滚：恢复 `skills.json` 与 `overrides/` 变更后，重新执行 `./skills.ps1 构建生效`。

### C.5 同步模式
- `link`：Junction 链接，适合日常开发。
- `sync`：镜像复制（`robocopy /MIR`），适合受限环境。

### C.6 批量改动记录模板
- 影响模块=；
- 影响配置/数据=；
- 生成/同步目录=；
- 验证命令与结果=；
- 回滚路径=。

### C.7 目标仓直改回灌策略
- 规则归宿：`E:/CODE/governance-kit/source/project/skills-manager/*`。
- 允许在 `E:/CODE/skills-manager` 临时试改，但同日必须回灌并附证据。
- 回灌后必须执行：`powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe`。

### C.8 CI 入口差异
- GitHub Actions：`.github/workflows/quality-gates.yml`
- Azure Pipelines：`azure-pipelines.yml`
- GitLab CI：`.gitlab-ci.yml`

### C.9 Hooks/模板/Git 校验
- hooks 校验：`Test-Path .git/hooks/pre-commit`、`Test-Path .git/hooks/pre-push`
- git config 校验：`git config --get commit.template`、`git config --get governance.kitRoot`
- 模板校验：`Test-Path docs/change-evidence/template.md`、`Test-Path docs/governance/waiver-template.md`、`Test-Path docs/governance/metrics-template.md`

### C.10 承接映射（Global -> Repo）
- R1：A.2 + C.1 + C.7（归宿先行与回灌闭环）。
- R2/R3：A.2 + C.2 + C.3（小步闭环与根因优先）。
- R4/R6：C.2 + C.3（固定门禁与 N/A 回退约束）。
- R7：A.1 + C.1（边界与配置契约不破坏）。
- R8/E3：A.2 + C.6（证据与回滚可追溯）。
- E4：C.2 + C.4（门禁结果与 `doctor --strict` 健康结论联动）。
- E5：C.2 + C.4（若仓内存在供应链检查则纳入 contract/invariant；不存在时标记 `N/A` 并记录替代验证）。
- E6：C.1 + C.4（`skills.json` 结构变更需迁移说明与可执行回滚）。

## D. 维护校验清单（项目级）
- 三文件（AGENTS/CLAUDE/GEMINI）结构、版本、日期一致。
- 项目级只写仓库事实，不复述全局 R/E 正文。
- 每次改动提供可执行命令与证据位置。
