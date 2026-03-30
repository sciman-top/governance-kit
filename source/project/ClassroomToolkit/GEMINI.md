# GEMINI.md — ClassroomToolkit（Gemini 项目级）
**项目**: ClassroomToolkit  
**类型**: Windows WPF (.NET 10)  
**适用范围**: 项目级（仓库根）  
**版本**: 3.78  
**最后更新**: 2026-03-30

## 1. 阅读指引（必读）
- 本文件承接 `GlobalUser/GEMINI.md`，仅定义本仓落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（仅本仓）
### A.1 项目不变约束
- 课堂可用性优先：不可崩溃、不可长时间卡死，外部依赖失败必须可降级。
- Interop 防护：`Win32/COM/WPS/UIAutomation` 异常不得冒泡到 UI。
- 兼容保护：不得破坏 `students.xlsx`、`student_photos/`、`settings.ini` 的格式与语义。
- 变更最小化：无证据不做跨层重构。

### A.2 执行锚点
- 每次改动先声明：边界 -> 当前落点 -> 目标归宿 -> 迁移批次。
- 小步闭环，优先根因修复；止血补丁必须标明回收时点。
- 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 N/A 策略
- `platform_na`：平台能力缺失或命令不支持。
- `gate_na`：仅纯文档/注释/排版或门禁脚本客观缺失时允许。
- 最低字段：`reason`、`alternative_verification`、`evidence_link`、`expires_at`。
- N/A 不得改变门禁顺序：`build -> test -> contract/invariant -> hotspot`。

## B. Gemini 平台差异（项目内）
### B.1 加载与覆盖
- 推荐目录：`~/.gemini`；实际以 CLI 加载结果为准。
- 优先级：`GEMINI.override.md > GEMINI.md > fallback`（平台支持时）。
- override 仅用于短期排障，结论后必须清理并复测。

### B.2 最小诊断矩阵
- 必做：`gemini --version -> gemini --help`。
- 状态/加载链类命令按“若支持则执行”。
- 留痕最低字段：`cmd`、`exit_code`、`key_output`、`timestamp`。

### B.3 平台能力剖面
- 状态命令能力不可强制假定存在；支持则执行，不支持按 B.4 处理。
- CLI 未显式展示加载链时，需补记 `active_rule_path` 与来源。
- override 能力若不可用，按 `reason + alternative_verification + evidence_link` 落证。

### B.4 平台异常回退
- 命令缺失或行为不一致时，必须记录：`platform_na/gate_na`、原因、替代命令、证据位置。
- 替代命令仅用于补证据，不得改变门禁顺序与阻断语义。

## C. 项目差异（领域与技术）
### C.1 模块边界与归宿
- `src/ClassroomToolkit.App`：WPF UI、MainViewModel、启动 DI。
- `src/ClassroomToolkit.Application`：用例编排、跨模块流程协调。
- `src/ClassroomToolkit.Domain`：核心业务规则唯一归宿。
- `src/ClassroomToolkit.Services`：桥接与编排，不承载核心业务规则。
- `src/ClassroomToolkit.Interop`：高风险 Interop 封装与生命周期管理。
- `src/ClassroomToolkit.Infra`：配置、持久化、文件系统、外部资源。
- `src/ClassroomToolkit.App/Windowing`：多窗口编排与 UI 生命周期控制。
- `tests/ClassroomToolkit.Tests`：回归与契约测试主阵地。

### C.2 门禁命令与顺序（硬门禁）
- build：`dotnet build ClassroomToolkit.sln -c Debug`
- test：`dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug`
- contract/invariant：
  `dotnet test tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj -c Debug --filter "FullyQualifiedName~ArchitectureDependencyTests|FullyQualifiedName~InteropHookLifecycleContractTests|FullyQualifiedName~InteropHookEventDispatchContractTests|FullyQualifiedName~GlobalHookServiceLifecycleContractTests|FullyQualifiedName~CrossPageDisplayLifecycleContractTests"`
- hotspot：`gate_na (hotspot script not found)`
- fixed order：`build -> test -> contract/invariant -> hotspot`
- quick gate（开发快速复验，不替代硬门禁）：
  `powershell -File scripts/validation/run-stable-tests.ps1 -Configuration Debug -SkipBuild -Profile quick`

### C.3 命令存在性与 N/A 回退验证
- precheck：`Get-Command dotnet`、`Get-Command powershell`、`Test-Path tests/ClassroomToolkit.Tests/ClassroomToolkit.Tests.csproj`。
- hotspot 缺失：标记 gate_na，必须执行 contract/invariant 子集，并补人工热点评审证据。
- contract/invariant 子集不可执行：标记 gate_na，回退到全量 `dotnet test` 并记录契约缺口风险。

### C.4 失败分流与阻断
- build 失败：阻断，先修编译错误和引用断裂。
- test 失败：阻断，先修回归失败再重跑全链路。
- contract/invariant 失败：高风险阻断，禁止合并或发布。
- hotspot：脚本存在且执行失败/超预算时阻断；脚本不存在时按 C.3 执行 gate_na 回退与证据补齐。

### C.5 证据与回滚
- 证据目录：`docs/change-evidence/`。
- 建议命名：`docs/change-evidence/YYYYMMDD-topic.md`。
- 最低字段：规则 ID、风险等级、执行命令、验证证据、回滚动作。
- waiver 字段：`owner/expires_at/status/recovery_plan/evidence_link`。

### C.6 目标仓直改回灌策略
- source of truth：`E:/CODE/governance-kit/source/project/ClassroomToolkit/*`。
- 允许在目标仓临时直改做试验，但同日必须回灌并留证据。
- 回灌后必须执行：`powershell -File E:/CODE/governance-kit/scripts/install.ps1 -Mode safe` + `powershell -File E:/CODE/governance-kit/scripts/doctor.ps1`。
- 未完成“回灌 + 复验”前，禁止再次 `sync/install` 覆盖未沉淀改动。

### C.7 CI 入口差异
- GitHub Actions：`.github/workflows/quality-gate.yml`（主入口）
- GitHub Actions：`.github/workflows/quality-gates.yml`（兼容入口）
- Azure Pipelines：`azure-pipelines.yml`
- GitLab CI：`.gitlab-ci.yml`

### C.8 Hooks/模板/Git 校验
- quick gate：`scripts/validation/run-stable-tests.ps1`
- hotspot script：`gate_na (script not found)`
- hooks 校验：`Test-Path .git/hooks/pre-commit`、`Test-Path .git/hooks/pre-push`
- git config 校验：`git config --get commit.template`、`git config --get governance.kitRoot`
- 模板校验：`Test-Path docs/change-evidence/template.md`、`Test-Path docs/governance/waiver-template.md`、`Test-Path docs/governance/metrics-template.md`

### C.9 承接映射（Global -> Repo）
- R1：A.2 + C.1 + C.6（归宿先行与回灌闭环）。
- R2/R3：A.2 + C.2 + C.3（小步闭环与根因优先）。
- R4/R6：C.2 + C.3 + C.4（硬门禁、N/A 回退与阻断）。
- R7：A.1 + C.1（兼容与边界保护）。
- R8/E3：A.2 + C.5（证据与 waiver 可追溯）。
- E4/E5/E6：C.4 + C.7 + C.8（指标、供应链、结构变更配套校验）。

## D. 维护校验清单（项目级）
- 仅落地本仓事实，不复述全局规则正文。
- 与全局职责互补，不重叠、不缺失。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 三文件同构约束：`A/C/D` 必须语义一致，仅 `B` 允许平台差异。
- 平台诊断命令在非交互环境失败时，必须按 A.3 字段落证，不得静默跳过。
- 规则升级后同步校验三文件版本、日期、承接映射与门禁命令一致性。
