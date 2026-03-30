# CLAUDE.md — Skills Manager（Claude 项目级）
**适用范围**: 项目级（仓库根）  
**版本**: 3.74  
**最后更新**: 2026-03-30

## 0. 变更记录
- 2026-03-30：按目标仓事实完成开放式重写，重构 C2/C3/C7/C8/C9，收敛为可执行闭环。
- 2026-01-24 v1.7：收敛表述并提升可操作性。
- 2026-01-24 v1.6：全量优化结构与措辞；强化协作边界；与全局规则对齐。

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/CLAUDE.md`，只定义 Skills Manager 落地动作（WHERE/HOW）。
- 本仓入口是 `skills.ps1`，构建脚本是 `build.ps1`；优先使用仓库既有命令，不发明平行流程。
- 输出语言默认中文；命令、日志、错误信息保持英文原文。

## A. 共性基线（项目级）
### A.1 事实边界
- 单一入口：`skills.ps1`；单一配置源：`skills.json`。
- `agent/` 与 `vendor/` 为生成/缓存目录；`agent/` 禁止手改。
- 自定义改动优先放 `overrides/` 或 `imports/`，避免直接改第三方缓存内容。

### A.2 变更原则
- 先定义归宿再改动：`source/project/skills-manager/*` 是项目级规则唯一归宿。
- 批量改动需最小化回归面，优先修复根因，不做无证据预抽象。
- 改动后必须留痕：依据 -> 命令 -> 结果 -> 回滚点。

### A.3 N/A 策略
- 仅在命令客观不存在时可标记 N/A。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`。
- N/A 不得改变门禁顺序语义：`build -> test -> contract/invariant -> hotspot`。

## B. 平台差异（Claude 项目内）
### B.1 规则与上下文
- 规则优先级：`CLAUDE.override.md > CLAUDE.md > fallback`。
- 引用仓库内容时优先基于文件事实，不依赖记忆。

### B.2 目录同步差异
- 若 `skills.json.targets` 含 `.claude/skills`，验证其与 `agent/` 同步状态。
- `sync_mode=link` 优先，`sync_mode=sync` 作为无链接权限环境回退。

## C. 项目差异（Skills Manager）
### C.1 模块职责
- `skills.ps1`：统一命令调度（发现/安装/构建/更新/doctor/MCP）。
- `build.ps1`：拼装 `src/*` 生成根目录 `skills.ps1`。
- `skills.json`：`vendors/mappings/targets/sync_mode/mcp_servers` 的唯一配置源。
- `overrides/`、`imports/`：本地可维护输入层；`agent/`：最终分发产物。

### C.2 门禁命令与执行顺序
- build：`.\build.ps1`
- test：`.\skills.ps1 发现`
- contract/invariant：`.\skills.ps1 doctor --strict`
- hotspot：`.\skills.ps1 构建生效`
- fixed order：`build -> test -> contract/invariant -> hotspot`

### C.3 命令缺失与回退验证
- precheck：`Get-Command powershell`、`Test-Path .\skills.ps1`、`Test-Path .\build.ps1`。
- 若 `doctor --strict` 不可执行：标记 contract/invariant=N/A，执行 `.\skills.ps1 发现` + `.\skills.ps1 构建生效` 并记录风险。
- 若 `构建生效` 受环境限制：标记 hotspot=N/A，至少完成 `build + doctor --strict`，并记录未覆盖风险。

### C.4 构建/验证/回滚
- 构建：`.\build.ps1`。
- 生效：`.\skills.ps1 构建生效`。
- 最小验证：`.\skills.ps1 doctor --strict`。
- 回滚：恢复 `skills.json` 与 `overrides/` 变更后，重新执行 `.\skills.ps1 构建生效`。

### C.5 同步模式
- `link`：Junction 链接，快速、可追踪，适合日常开发。
- `sync`：镜像复制（`robocopy /MIR`），适合受限环境或链接被禁场景。

### C.6 批量改动记录模板
- 影响模块=；
- 影响配置/数据=；
- 生成/同步目录=；
- 验证命令与结果=；
- 回滚路径=。

### C.7 目标仓直改回灌策略
- 规则归宿固定为：`E:/CODE/governance-kit/source/project/skills-manager/*`。
- 允许在 `E:/CODE/skills-manager` 临时试改，但同日必须回灌并附证据。
- 回灌后必须执行：`powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe`。
- 回灌完成前禁止再次 `sync/install`，避免覆盖未沉淀改动。

### C.8 CI 入口差异
- GitHub Actions：`.github/workflows/quality-gates.yml`
- Azure Pipelines：`azure-pipelines.yml`
- GitLab CI：`.gitlab-ci.yml`

### C.9 Hooks/模板/git 配置快照（2026-03-30）
- hooks：`.git/hooks/pre-commit`、`.git/hooks/pre-push` 已注入治理块。
- git config：`commit.template` 与 `governance.kitRoot` 已设置。
- 模板：`docs/change-evidence/template.md`、`docs/governance/*` 已存在。

## D. 维护校验清单（项目级）
- 三文件（AGENTS/CLAUDE/GEMINI）结构一致、版本一致、日期一致。
- 每次改动都要给出可执行命令与证据，不能只给描述性结论。
- 升级治理规则后，先回灌 source，再分发到目标仓并执行 doctor 复验。
