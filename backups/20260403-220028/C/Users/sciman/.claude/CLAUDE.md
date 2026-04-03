# CLAUDE.md — Universal Agent Protocol v9.37
# Claude Code / Claude CLI — Global User Rules
**版本**: 9.37  
**适用范围**: 全局用户级（GlobalUser/）  
**最后更新**: 2026-04-03

## 1. 阅读指引（必读）
- 本文件定义跨仓通用规则语义（WHAT）；项目级同名文件定义仓库落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（全局）
### A.1 三层职责（强制）
- 共性基线：统一执行与治理标准（WHAT）。
- 平台差异：仅写 Claude 特有加载/诊断/回退（PLATFORM）。
- 项目差异：仅在项目级文件落地仓库事实（WHERE/HOW）。

### A.2 执行与输出
- 默认中文沟通；代码/命令/日志/报错保留英文原文。
- 简单任务：`Result + Evidence`；复杂任务：`Goal / Plan / Changes / Verification / Risks`。
- 默认持续执行到完成；仅在真实阻塞、不可逆风险、连续自修复失败时请求人工确认。

### A.3 强制规则（R1-R8）
1. `R1 先定归宿再改动`：先声明当前落点与目标归宿。
2. `R2 小步闭环`：每步可执行、可验证、可对比。
3. `R3 根因优先`：止血补丁必须标注回收时点与最终归宿。
4. `R4 风险分级`：低风险自动执行；中风险发布前确认；高风险先预演回滚。
5. `R5 反过度设计`：无证据不做预抽象和猜测式优化。
6. `R6 硬门禁`：`build + test + contract/invariant + hotspot` 不可绕过。
7. `R7 一致性与兼容`：未授权不得破坏契约、数据格式、外部行为与向后兼容。
8. `R8 可追溯`：每次变更必须留存 `依据 -> 命令 -> 证据 -> 回滚`。

### A.4 N/A 分类与字段（统一口径）
- `platform_na`：平台能力缺失或命令不支持（如状态命令不存在）。
- `gate_na`：仅在纯文档/纯注释/纯排版或门禁脚本客观缺失时允许。
- 两类 N/A 均必须记录：`reason`、`alternative_verification`、`evidence_link`、`expires_at`。
- N/A 不得改变硬门禁顺序：`build -> test -> contract/invariant -> hotspot`。

### A.5 治理演进（E1-E6）
- `E1` 版本化。
- `E2` 兼容窗口（`observe -> enforce`）。
- `E3` Waiver：`owner/expires_at/status/recovery_plan/evidence_link`。
- `E4` 健康指标联动门禁结果。
- `E5` 供应链门禁（存在即执行）。
- `E6` 数据结构变更需迁移与回滚方案。

## B. Claude 平台差异（全局）
### B.1 加载链与覆盖
- 推荐用户目录：`~/.claude`；实际以 CLI 加载结果为准。
- 优先级：`CLAUDE.override.md > CLAUDE.md > fallback`（平台支持时）。
- `fallback` 定义：CLI 默认行为（无项目规则或规则不可读时）。
- `CLAUDE.override.md` 仅用于短期排障；任务结束后删除并复测。

### B.2 最小诊断矩阵（Claude）
- 必做：`claude --version`、`claude --help`。
- 对状态/加载链命令执行“先探测后调用”：`claude --help` 可见再执行。
- 留痕最低字段：`cmd`、`exit_code`、`key_output`、`timestamp`。

### B.3 能力边界（Claude）
- 不强制假定 `status/doctor` 等命令存在，缺失按 `platform_na` 记录。
- CLI 无显式加载链时，补记 `active_rule_path` 与来源。
- override 能力若当前版本不支持，按 `platform_na` 记录并补替代证据。

### B.4 不支持项回退
- 命令缺失或行为不一致时，记录：`platform_na`、原因、替代命令、证据位置。
- 替代命令仅用于补证据，不得改变规则语义与门禁顺序。

## C. 项目级承接契约（全局模板）
### C.1 自包含与边界
- 项目级同名文件必须完整自包含，并显式承接 `GlobalUser/CLAUDE.md`。
- 项目级仅写本仓事实，不复述全局 R/E 正文。

### C.2 项目级必填项
- 模块边界与目标归宿。
- 门禁命令与顺序：`build -> test -> contract/invariant -> hotspot`。
- 失败分流与阻断条件。
- 证据与回滚位置。
- `Global Rule -> Repo Action` 承接映射（含 `E4/E5/E6` 或明确 `N/A`）。
- 三文件同构约束：`A/C/D` 同构，`B` 按平台差异化。

### C.3 协同接口（1+1>2）
- 全局输出：规则语义、判定标准、N/A 口径。
- 项目输入：仓库路径、门禁命令、证据路径、回滚入口。
- 协同判定：不重叠、不缺失、可执行。

### C.4 边界防重叠（强制）
- 全局不得下沉仓库私有路径、私有命令、私有回滚脚本。
- 项目级不得改写全局 R/E 语义；仅能承接为本仓动作。

## D. 维护校验清单（全局）
- 结构保持 `1 / A / B / C / D`。
- 全局文件不得写仓库特有路径与命令。
- 三层完整：`共性基线 + 平台差异 + 项目差异`。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。
- 文档精简优先：不改变语义前提下删除重复表述。
- 升级后同步校验项目级版本联动与承接映射。
