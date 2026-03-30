# GEMINI.md — ClassroomToolkit 项目规则（Gemini CLI）
**项目**: ClassroomToolkit  
**类型**: Windows WPF (.NET 10)  
**适用范围**: 项目级（仓库根）  
**版本**: 3.40  
**最后更新**: 2026-03-29

## 1. 阅读指引（项目级）
- 本文件承接 `GlobalUser/GEMINI.md`，仅定义本仓落地动作。
- 固定结构：`A 共性基线 + B 平台差异 + C 项目差异 + D 维护清单`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（项目级）
### A.1 执行与输出
- 默认输出模板：`理解 / 改动范围 / 最小方案 / 验证方法 / 风险与回滚`。
- 默认持续执行到完成；仅在真实阻塞、不可逆风险、连续自修复失败时请求人工确认。

### A.2 项目不变约束
- 课堂可用性优先：不可崩溃、不可长时间卡死；外部依赖失败必须可降级。
- Interop 防御：Win32/COM 异常不得冒泡到 UI，必须在边界层拦截。
- 兼容保护：不得破坏 `students.xlsx`、`student_photos/`、`settings.ini`。

### A.3 全局-项目执行锚点
1. 先写清 `边界 -> 当前落点 -> 目标归宿 -> 迁移批次`。
2. 按小步闭环执行；修复优先根因；止血补丁必须给出回收时点与最终归宿。
3. 按风险分级执行：低风险自动；中风险确认；高风险先预演回滚。
4. 严格执行 C.2 门禁，任一步失败即阻断。
5. 兼容不破坏；冲突按裁决链；仅真实阻塞才打断。
6. 每次变更必须留存 `依据 -> 命令 -> 证据 -> 回滚`。

### A.4 N/A 适用策略
- 纯文档、纯注释、纯排版可将门禁标记为 `N/A`。
- `N/A` 必须记录理由与替代验证，不得整项跳过。

## B. 平台差异（Gemini 项目内）
### B.1 加载与诊断
- 优先级：`GEMINI.override.md > GEMINI.md > fallback`（如平台支持）。
- 规则异常优先 Gemini CLI 对应状态/诊断命令；临时 override 与排障说明需在结论后清理。

## C. 项目差异（领域与技术）
### C.1 目录与模块边界
- `src/ClassroomToolkit.App`：WPF UI、MainViewModel、启动 DI。
- `src/ClassroomToolkit.Application`：应用用例编排、跨模块流程协调。
- `src/ClassroomToolkit.Domain`：核心业务规则。
- `src/ClassroomToolkit.Services`：桥接与编排，不承接核心业务规则。
- `src/ClassroomToolkit.Interop`：Win32/COM/WPS/UIAutomation 高风险封装。
- `src/ClassroomToolkit.Infra`：配置、持久化、文件系统。
- `src/ClassroomToolkit.App/Windowing`：多窗口编排。
- `tests/ClassroomToolkit.Tests`：xUnit + FluentAssertions。

### C.2 硬门禁命令（本仓）
- `dotnet build ClassroomToolkit.sln -c Debug`
- `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug`
- `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~InteropHookLifecycleContractTests|FullyQualifiedName~InteropHookEventDispatchContractTests|FullyQualifiedName~GlobalHookServiceLifecycleContractTests|FullyQualifiedName~CrossPageDisplayLifecycleContractTests"`
- `powershell -File scripts/quality/check-hotspot-line-budgets.ps1 -AsJson`
- 一键门禁：`powershell -File scripts/quality/run-local-quality-gates.ps1 -Profile quick`

### C.3 执行顺序与失败分流
- 执行顺序：`build -> test -> contract/invariant -> hotspot`。
- `build` 失败：先修编译错误，不进入后续门禁。
- `test` 失败：先修回归或用例，再复跑全链路。
- `contract/invariant` 失败：高风险阻断，禁止合并。
- `hotspot` 超预算：拆分或迁移热点逻辑后复检。

### C.4 证据与回滚
- 留痕模板：`规则ID=；影响模块=；当前落点=；目标归宿=；迁移批次=；风险等级=；执行命令=；验证证据=；回滚动作=`。
- 证据位置：`docs/change-evidence/`（不存在则首次创建）。
- 回滚最低要求：可逆命令、回滚触发条件、回滚后复验命令。

## D. 维护校验清单（项目级）
- 结构保持 `1 / A / B / C / D`。
- 与 `GlobalUser/` 对应文件职责互补，不重叠、不缺失。
- 三层协同完整：`共性基线 + 平台差异 + 项目差异`。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
