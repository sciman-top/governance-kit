# GEMINI.md — Generic Repo Baseline（governance-kit template）
**模板版本**: 1.2  
**适用范围**: 项目级模板（无仓库专属规则时）  
**最后更新**: 2026-04-03

## 1. 阅读指引
- 本模板承接 `GlobalUser/GEMINI.md`，仅定义项目级落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（模板）
### A.1 三层职责
- 共性基线：执行与治理语义（WHAT）。
- 平台差异：仅写 Gemini 加载/诊断/回退（PLATFORM）。
- 项目差异：仅写本仓命令、证据、回滚（WHERE/HOW）。

### A.2 执行与输出
- 默认持续执行到完成；仅在真实阻塞、不可逆风险、连续自修复失败时请求确认。
- 简单任务输出 `Result + Evidence`；复杂任务输出 `Goal / Plan / Changes / Verification / Risks`。
- 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 工程质量与门禁语义
- 优先根因修复；无证据不做预抽象和猜测式优化。
- 兼容优先：未授权不得破坏契约与外部行为。
- 门禁顺序固定：`build -> test -> contract/invariant -> hotspot`。

## B. Gemini 平台差异（模板）
### B.1 加载与覆盖
- 推荐目录：`~/.gemini`；实际以 CLI 加载结果为准。
- 优先级：`GEMINI.override.md > GEMINI.md > fallback`（平台支持时）。
- override 仅用于短期排障，结论后删除并复测。

### B.2 最小诊断矩阵
- 必做：`gemini --version`、`gemini --help`。
- 状态/扩展能力按“先探测后调用”；不可用时按 `platform_na` 记录。
- 留痕字段：`cmd`、`exit_code`、`key_output`、`timestamp`。

### B.3 异常回退
- 命令缺失/行为不一致：记录 `platform_na` + 原因 + 替代验证 + 证据位置。
- 替代命令仅补证据，不改变门禁顺序与阻断语义。
- 禁止在仓内脚本调用模型 CLI（含 `codex/claude/gemini exec`）做自动修复；自动修复由当前 AI 会话代理执行。

## C. 项目差异承接（模板）
### C.1 必填项
- 模块边界与目标归宿。
- 门禁命令（按 `build -> test -> contract/invariant -> hotspot`）。
- 失败分流与阻断条件。
- 证据目录与回滚入口。
- `Global Rule -> Repo Action` 承接映射（含 `E4/E5/E6` 或明确 `N/A`）。

### C.2 N/A 口径
- `platform_na`：平台能力不足或命令不存在。
- `gate_na`：门禁步骤客观不可执行（脚本缺失/纯文档变更等）。
- 必填字段：`reason`、`alternative_verification`、`evidence_link`、`expires_at`。

### C.3 协作边界（1+1>2）
- 全局负责语义与判定标准；项目级负责本仓命令、证据、回滚。
- 项目级不得改写全局语义；全局不得下沉仓库私有实现。
- 执行边界：脚本仅作为门禁编排器并输出失败上下文 JSON；修复与重试由外层代理连续执行。

## D. 维护清单
- 保持 `1 / A / B / C / D` 结构。
- A/C/D 三文件同构，仅 B 允许平台差异。
- 文档精简优先，删除不改变语义的重复描述。
- 规则更新后同步校验版本、日期、映射与门禁命令一致性。
