# CLAUDE.md — Skills Manager（Claude 项目级）
**适用范围**: 项目级（仓库根）  
**版本**: 1.7  
**最后更新**: 2026-01-24

## 0. 变更记录
- 2026-01-24 v1.7：收敛表述并提升可操作性。
- 2026-01-24 v1.6：全量优化结构与措辞；强化协作边界；与全局规则对齐。
- 2026-01-21 v1.0–v1.5：项目结构与模板完善。

## 1. 阅读指引（必读）
- 本文件仅补充仓库差异；跨项目通用规则在 `GlobalUser/CLAUDE.md`。
- 三层结构：共性基线 + 平台差异 + 项目差异；冲突以项目级为准并说明采用。
- 默认中文沟通，必要时保留英文术语/命令/日志。

## A. 共性基线（项目级）
### A.1 入口与生成目录
- `skills.ps1` 为唯一入口；`skills.json` 为唯一配置源。
- `vendor/`、`agent/` 为自动生成；**禁止手改** `agent/`（构建会清空）。
- 定制优先走 `overrides/`，不要直接修改 `vendor/`。

### A.2 协作与优先级
- 继承 `GlobalUser/CLAUDE.md`，项目级规则优先于全局规则。
- 项目级只补充仓库差异，不复写全局共性条款。
- 规则来源：`GlobalUser/CLAUDE.md` → `CLAUDE.md`。

### A.3 N/A policy
- minimum fields: reason, alternative_verification, evidence_link.

## B. 平台差异（Claude 项目内）
- `targets` 包含 `.claude/skills` 时，需确认其指向或同步到 `agent/`。
- 扩展说明优先使用 `@` 引用仓库内文件，避免重复粘贴。

## C. 项目差异（Skills Manager）
### C.1 目录与职责
- `skills.ps1`：中文菜单脚本（初始化、发现、选择、构建生效、更新）。
- `skills.json`：`vendors`、`mappings`、`sync_mode`、`targets`。
- `vendor/`：上游缓存；`agent/`：合并输出；`overrides/`：覆盖层。

### C.2 Gate commands and execution order
- dotnet build -c Debug
- dotnet test -c Debug
- N/A (no test project detected)
- N/A (hotspot script not found)
- quick gate: N/A (quick gate script not found)
- fixed order: build -> test -> contract/invariant -> hotspot.

### C.3 Command presence and N/A fallback verification
- precheck: Get-Command dotnet, N/A (contract/invariant subset not detected), N/A (hotspot script missing).
- if hotspot is missing: mark hotspot=N/A, run contract/invariant subset and record manual hotspot review.
- if contract/invariant subset is unavailable: mark contract/invariant=N/A, run full dotnet test and record contract-gap risks.
- any N/A must preserve semantic order: build -> test -> contract/invariant -> hotspot.

### C.4 构建/验证/回滚
- 构建：`.\skills.ps1 构建生效`。
- 验证：`agent/` 生成 + `targets` 同步到 `agent/`。
- 最小验证：`.\skills.ps1 发现` 或 `.\skills.ps1 构建生效`。
- 回滚：恢复 `skills.json` 或撤销 `overrides/` 后重建。
- 运行/发布：无固定流程，需用户指定。
- 备注：`mappings` 为空不会构建任何技能。

### C.5 同步模式
- `link`：Windows 优先 Junction，立即生效（推荐）。
- `sync`：`robocopy /MIR` 镜像，适合链接受限环境。

### C.6 变更影响模板（批量改动必填）
- 模板：影响模块=；影响数据/配置=；同步/生成目录=；平台差异=；验证与回滚=。
- 示例：影响模块=脚本/配置；影响数据/配置=skills.json；同步/生成目录=agent/；平台差异=无；验证与回滚=未测/恢复 skills.json 后重建。

### C.7 Target-repo direct edit backflow policy
- source of truth: E:/CODE/governance-kit/source/project/skills-manager/*.
- temporary direct edits in target repo are allowed for fast trial, but must backflow to source the same day with evidence.
- after backflow, run powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe to re-sync source and target.
- before backflow completion, do not run sync/install again to avoid overwriting unsaved target edits.

### C.8 CI entry differences
- GitHub Actions: .github/workflows/quality-gates.yml
- Azure Pipelines: azure-pipelines.yml
- GitLab CI: .gitlab-ci.yml

### C.9 Hooks/templates/git config snapshot
- quick gate script selected: N/A
- hotspot script selected: N/A
- hooks/pre-commit+pre-push governance block installed: True
- git commit.template configured: True
- git governance.kitRoot configured: True
- docs/change-evidence/template.md exists: True
- docs/governance/waiver-template.md exists: True
- docs/governance/metrics-template.md exists: True

## D. 维护校验清单（项目级）
- 三文件结构一致，版本/日期同步。
- 批量改动需说明验证与风险，并列出受影响文件清单。
- 平台差异触发条件新增时同步更新三文件。
