# AGENTS.md — ClassroomToolkit 项目规则（Codex）
**项目**: ClassroomToolkit  
**类型**: Windows WPF (.NET 10)  
**适用范围**: 项目级（仓库根）  
**版本**: 3.73  
**最后更新**: 2026-03-30

## 1. 阅读指引（项目级）
- 本文件承接 `GlobalUser/AGENTS.md`，仅定义本仓落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 项目共性基线（仅本仓）
### A.1 项目不变约束
- 课堂可用性优先：不可崩溃、不可长时间卡死；外部依赖失败必须可降级。
- Interop 防御：Win32/COM 异常不得冒泡到 UI，必须在边界层拦截。
- 兼容保护：不得破坏 `students.xlsx`、`student_photos/`、`settings.ini`。

### A.2 项目执行锚点
1. 每次改动先声明：`边界 -> 当前落点 -> 目标归宿 -> 迁移批次`。
2. 小步闭环，优先根因修复；止血补丁必须给出回收时点。
3. 每次变更留存：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 N/A policy
- minimum fields: reason, alternative_verification, evidence_link.

## B. Codex 平台差异（项目内）
### B.1 加载与诊断
- 优先级：`AGENTS.override.md > AGENTS.md > fallback`。
- 最小诊断：`codex status -> codex --version -> codex --help`。
- `override` 仅用于短期排障；结论后必须清理并复测。

### B.2 平台异常回退
- 命令不可用或行为不一致时，记录：`N/A`、原因、替代命令、证据位置。

## C. 项目差异（领域与技术）
### C.1 模块边界与归宿
- `src/ClassroomToolkit.App`：WPF UI、MainViewModel、启动 DI。
- `src/ClassroomToolkit.Application`：应用用例编排、跨模块流程协调。
- `src/ClassroomToolkit.Domain`：核心业务规则。
- `src/ClassroomToolkit.Services`：桥接与编排，不承接核心业务规则。
- `src/ClassroomToolkit.Interop`：Win32/COM/WPS/UIAutomation 高风险封装。
- `src/ClassroomToolkit.Infra`：配置、持久化、文件系统。
- `src/ClassroomToolkit.App/Windowing`：多窗口编排。
- `tests/ClassroomToolkit.Tests`：xUnit + FluentAssertions。

### C.2 Gate commands and execution order
- dotnet build ClassroomToolkit.sln -c Debug
- dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug
- dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~InteropHookLifecycleContractTests|FullyQualifiedName~InteropHookEventDispatchContractTests|FullyQualifiedName~GlobalHookServiceLifecycleContractTests|FullyQualifiedName~CrossPageDisplayLifecycleContractTests"
- N/A (hotspot script not found)
- quick gate: powershell -File scripts/validation/run-stable-tests.ps1 -Configuration Debug -SkipBuild -Profile quick
- fixed order: build -> test -> contract/invariant -> hotspot.

### C.3 Command presence and N/A fallback verification
- precheck: Get-Command dotnet, Test-Path tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj, N/A (hotspot script missing).
- if hotspot is missing: mark hotspot=N/A, run contract/invariant subset and record manual hotspot review.
- if contract/invariant subset is unavailable: mark contract/invariant=N/A, run full dotnet test and record contract-gap risks.
- any N/A must preserve semantic order: build -> test -> contract/invariant -> hotspot.

### C.4 失败分流与阻断
- `build` 失败：先修编译错误。
- `test` 失败：先修回归或用例。
- `contract/invariant` 失败：高风险阻断，禁止合并。
- `hotspot` 超预算：拆分或迁移热点逻辑后复检。

### C.5 证据与回滚
- 证据目录：`docs/change-evidence/`（不存在则首次创建）。
- 建议命名：`docs/change-evidence/YYYYMMDD-<topic>.md`。
- 留痕模板：`规则ID=；影响模块=；当前落点=；目标归宿=；迁移批次=；风险等级=；执行命令=；验证证据=；回滚动作=`。
- 最低字段：`规则ID`、`风险等级`、`执行命令`、`验证证据`、`回滚动作`。
- Waiver 键：`owner`、`expires_at`、`status`、`recovery_plan`、`evidence_link`。

### C.6 承接映射（Global -> Repo）
- `R1`：A.2 落点声明 + C.1 模块边界。
- `R2/R3`：A.2 小步闭环与根因优先。
- `R4/R6`：C.2 门禁链路 + C.3 命令存在性与 N/A 替代 + C.4 失败阻断。
- `R7`：A.1 兼容保护。
- `R8/E3`：C.5 证据与 Waiver。
- `E1/E2`：文档版本化 + `observe -> enforce` 切换留痕。
- `E4/E5/E6`：指标联动、供应链门禁、数据结构迁移回滚。

### C.7 Target-repo direct edit backflow policy
- source of truth: E:/CODE/governance-kit/source/project/ClassroomToolkit/*.
- temporary direct edits in target repo are allowed for fast trial, but must backflow to source the same day with evidence.
- after backflow, run powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe to re-sync source and target.
- before backflow completion, do not run sync/install again to avoid overwriting unsaved target edits.

### C.8 CI entry differences
- GitHub Actions: .github/workflows/quality-gate.yml
- GitHub Actions: .github/workflows/quality-gates.yml
- Azure Pipelines: azure-pipelines.yml
- GitLab CI: .gitlab-ci.yml

### C.9 Hooks/templates/git config snapshot
- quick gate script selected: scripts/validation/run-stable-tests.ps1
- hotspot script selected: N/A
- hooks/pre-commit+pre-push governance block installed: True
- git commit.template configured: True
- git governance.kitRoot configured: True
- docs/change-evidence/template.md exists: True
- docs/governance/waiver-template.md exists: True
- docs/governance/metrics-template.md exists: True

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复写全局规则正文。
- 与 `GlobalUser/AGENTS.md` 职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 目标仓直改后必须完成规则源回灌与再分发校验。
- 规则升级后同步校验承接映射与证据模板一致性。



