# CLAUDE.md — ClassroomToolkit 项目规则（Claude Code）
**项目**: ClassroomToolkit  
**类型**: Windows WPF (.NET 10)  
**适用范围**: 项目级（仓库根）  
**版本**: 3.72  
**最后更新**: 2026-03-30

## 1. 阅读指引（项目级）
- 本文件承接 `GlobalUser/CLAUDE.md`，仅定义本仓 WHERE/HOW。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 项目共性基线（仅本仓）
### A.1 项目不变约束
- 课堂可用性优先：不可崩溃、不可长时间卡死；外部依赖失败必须可降级。
- Interop 防御：Win32/COM 异常不得冒泡到 UI，必须在边界层拦截。
- 兼容保护：不得破坏 `students.xlsx`、`student_photos/`、`settings.ini`。

### A.2 项目执行锚点
1. 先声明：`边界 -> 当前落点 -> 目标归宿 -> 迁移批次`。
2. 小步闭环，根因优先；止血补丁必须给出回收时点。
3. 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 N/A 适用策略
- 仅纯文档/纯注释/纯排版可将门禁标记 `N/A`。
- `N/A` 最低字段：`reason`、`alternative_verification`、`evidence_link`。

## B. Claude 平台差异（项目内）
### B.1 加载与诊断
- 优先级：`CLAUDE.override.md > CLAUDE.md > fallback`（平台支持时）。
- 最小诊断：`claude --version -> claude --help`；若支持状态命令则补充执行。
- `CLAUDE.override.md` 仅用于短期排障；结论后清理并复测。

### B.2 平台异常回退
- 命令不可用或行为不一致：记录 `N/A + 原因 + 替代命令 + 证据位置`。

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

### C.2 硬门禁命令与顺序
- `dotnet build ClassroomToolkit.sln -c Debug`
- `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug`
- `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~InteropHookLifecycleContractTests|FullyQualifiedName~InteropHookEventDispatchContractTests|FullyQualifiedName~GlobalHookServiceLifecycleContractTests|FullyQualifiedName~CrossPageDisplayLifecycleContractTests"`
- `powershell -File scripts/quality/check-hotspot-line-budgets.ps1 -AsJson`
- 一键门禁：`powershell -File scripts/quality/run-local-quality-gates.ps1 -Profile quick`
- 顺序固定：`build -> test -> contract/invariant -> hotspot`。

### C.3 命令存在性与 N/A 替代验证
- 预检：`Get-Command dotnet`、`Test-Path ClassroomToolkit.sln`、`Test-Path tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj`、`Test-Path scripts/quality/check-hotspot-line-budgets.ps1`。
- `hotspot` 缺失：`hotspot=N/A`，替代执行 `contract/invariant` 子集并记录热点人工检查结论。
- `contract/invariant` 不可执行：`contract/invariant=N/A`，替代全量 `dotnet test` 并记录契约差异风险。
- 任一 `N/A` 不得跨过 `build -> test -> contract/invariant -> hotspot` 语义顺序。

### C.4 失败分流与阻断
- `build` 失败：先修编译错误。
- `test` 失败：先修回归或用例。
- `contract/invariant` 失败：高风险阻断，禁止合并。
- `hotspot` 超预算：拆分或迁移热点逻辑后复检。

### C.5 证据与回滚
- 证据目录：`docs/change-evidence/`（不存在则首次创建）。
- 建议命名：`docs/change-evidence/YYYYMMDD-<topic>.md`。
- 最低字段：`规则ID`、`风险等级`、`执行命令`、`验证证据`、`回滚动作`。
- Waiver 键：`owner`、`expires_at`、`status`、`recovery_plan`、`evidence_link`。

### C.6 承接映射（Global -> Repo）
- `R1`: A.2 + C.1
- `R2/R3`: A.2
- `R4/R6`: C.2 + C.3 + C.4
- `R7`: A.1
- `R8/E3`: C.5
- `E1/E2/E4/E5/E6`: 版本化、观察到强制切换、指标联动、供应链门禁、数据结构迁移回滚

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复写全局规则正文。
- 与 `GlobalUser/CLAUDE.md` 职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。