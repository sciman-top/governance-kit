# GEMINI.md — ClassroomToolkit 项目规则
**项目**: ClassroomToolkit  
**类型**: Windows WPF (.NET 10)  
**适用范围**: 项目级（仓库根）  
**版本**: 3.74  
**最后更新**: 2026-03-30

## 1. 阅读指引（项目级）
- 本文件承接 GlobalUser/GEMINI.md，仅定义本仓落地动作（WHERE/HOW）。
- 固定结构：1 / A / B / C / D。
- 裁决链：运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文。

## A. 项目共性基线（仅本仓）
### A.1 项目不变约束
- 课堂可用性优先：不可崩溃、不可长时间卡死；外部依赖失败必须可降级。
- Interop 防御：Win32/COM/WPS/UIAutomation 异常不得冒泡到 UI，必须在边界层拦截并可观测。
- 兼容保护：不得破坏 students.xlsx、student_photos/、settings.ini 的格式与语义。
- 变更最小化：无证据不得跨层重构；优先在当前边界修复并补测试证据。

### A.2 项目执行锚点
1. 每次改动先声明：边界 -> 当前落点 -> 目标归宿 -> 迁移批次。
2. 小步闭环，优先根因修复；止血补丁必须给出回收时点。
3. 每次变更留存：依据 -> 命令 -> 证据 -> 回滚。

### A.3 N/A 策略
- 仅在命令或脚本客观不存在时允许 N/A。
- 最低字段：reason、alternative_verification、evidence_link。
- N/A 不得改变门禁语义顺序：build -> test -> contract/invariant -> hotspot。

## B. Gemini 平台差异（项目内）
### B.1 加载与诊断
- 优先级：GEMINI.override.md > GEMINI.md > fallback。
- 最小诊断：gemini --version -> gemini --help（若支持状态命令则补充执行）。
- override 仅用于短期排障；结论后必须清理并复测。

### B.2 平台异常回退
- 命令不可用或行为不一致时，记录：N/A、原因、替代命令、证据位置。
- 回退命令只用于补证据，不得改变门禁顺序和阻断语义。

## C. 项目差异（领域与技术）
### C.1 模块边界与归宿
- src/ClassroomToolkit.App：WPF UI、MainViewModel、启动 DI。
- src/ClassroomToolkit.Application：应用用例编排、跨模块流程协调。
- src/ClassroomToolkit.Domain：核心业务规则唯一归宿。
- src/ClassroomToolkit.Services：桥接与编排，不承接核心业务规则。
- src/ClassroomToolkit.Interop：Win32/COM/WPS/UIAutomation 高风险封装与生命周期管理。
- src/ClassroomToolkit.Infra：配置、持久化、文件系统与外部资源。
- src/ClassroomToolkit.App/Windowing：多窗口编排与 UI 生命周期控制。
- tests/ClassroomToolkit.Tests：xUnit + FluentAssertions（回归与契约主阵地）。

### C.2 门禁命令与顺序（硬门禁）
- dotnet build ClassroomToolkit.sln -c Debug
- dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug
- dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~InteropHookLifecycleContractTests|FullyQualifiedName~InteropHookEventDispatchContractTests|FullyQualifiedName~GlobalHookServiceLifecycleContractTests|FullyQualifiedName~CrossPageDisplayLifecycleContractTests"
- N/A (hotspot script not found)
- quick gate（开发期快速复验）：powershell -File scripts/validation/run-stable-tests.ps1 -Configuration Debug -SkipBuild -Profile quick
- 固定顺序：build -> test -> contract/invariant -> hotspot。

### C.3 命令存在性与 N/A 回退验证
- precheck：Get-Command dotnet、Get-Command powershell、Test-Path tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj。
- hotspot 缺失时：标记 N/A，必须执行 contract/invariant 子集并在证据中补人工热点评审说明。
- contract/invariant 子集不可执行时：标记 N/A，必须回退到全量 dotnet test 并记录契约缺口风险。
- 任何回退都要写明替代命令与证据位置。

### C.4 失败分流与阻断
- build 失败：阻断，先修编译错误与引用断裂。
- test 失败：阻断，先修回归或错误用例，再重跑全链路。
- contract/invariant 失败：高风险阻断，禁止合并或发布。
- hotspot 失败或超预算：阻断，先拆分热点逻辑或补性能证据。

### C.5 证据与回滚
- 证据目录：docs/change-evidence/。
- 建议命名：docs/change-evidence/YYYYMMDD-topic.md。
- 最低字段：规则ID、风险等级、执行命令、验证证据、回滚动作。
- Waiver 键：owner、expires_at、status、recovery_plan、evidence_link。
- 回滚优先级：先恢复规则与关键脚本，再恢复配置与模板，最后复验门禁。

### C.6 承接映射（Global -> Repo）
- R1：A.2 落点声明 + C.1 模块边界。
- R2/R3：A.2 小步闭环与根因优先。
- R4/R6：C.2 门禁链路 + C.3 命令存在性与 N/A 替代 + C.4 失败阻断。
- R7：A.1 兼容保护。
- R8/E3：C.5 证据与 Waiver。
- E1/E2：版本化 + observe -> enforce 切换留痕。
- E4/E5/E6：指标联动、供应链门禁、数据结构迁移回滚。

### C.7 目标仓直改回灌策略
- source of truth：E:/CODE/governance-kit/source/project/ClassroomToolkit/*。
- 目标仓允许临时直改以快速试验，但必须当日回灌并留证据。
- 回灌后必须执行 install.ps1 -Mode safe + doctor.ps1，确认 source 和 target 一致。
- 未完成回灌前禁止再次 sync/install，避免覆盖未沉淀改动。

### C.8 CI 与门禁入口差异
- GitHub Actions：.github/workflows/quality-gate.yml（主入口）
- GitHub Actions：.github/workflows/quality-gates.yml（兼容入口）
- Azure Pipelines：azure-pipelines.yml
- GitLab CI：.gitlab-ci.yml
- 若多入口并存，变更时需同步保持门禁语义一致（build/test/contract/hotspot）。

### C.9 Hooks/模板/Git 配置快照
- quick gate script：scripts/validation/run-stable-tests.ps1
- hotspot script：N/A
- hooks pre-commit/pre-push governance block：installed
- git commit.template：.gitmessage.txt
- git governance.kitRoot：E:/CODE/governance-kit
- templates：docs/change-evidence/template.md、docs/governance/waiver-template.md、docs/governance/metrics-template.md 已存在

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复写全局规则正文。
- 与全局文件职责互补，不重叠、不缺失。
- 协同链完整：规则 -> 落点 -> 命令 -> 证据 -> 回滚。
- 目标仓直改后必须完成 回灌 + 再分发 + doctor 闭环。
- 规则升级后同步校验承接映射、CI 门禁语义与证据模板一致性。
