# CLAUDE.md — Universal Agent Protocol v9.42
# Claude Code / Claude CLI — Global User Rules
**版本**: 9.42  
**适用范围**: 全局用户级（GlobalUser/）  
**最后更新**: 2026-03-30

## 1. 阅读指引（必读）
- 本文件定义 WHAT；仓库根同名文件定义 WHERE/HOW。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（全局）
### A.1 三层职责（强制）
- 共性基线：统一执行与治理标准。
- 平台差异：仅写 Claude 特有加载/诊断/回退。
- 项目差异：仅在项目级文件落地仓库事实。

### A.2 执行与输出
- 默认中文沟通；代码/命令/日志/报错保留英文原文。
- 简单任务：`Result + Evidence`；复杂任务：`Goal / Plan / Changes / Verification / Risks`。
- 默认持续执行到完成；仅在真实阻塞、不可逆风险、连续自修复失败时请求人工确认。

### A.3 强制规则（R1-R8）
1. `R1` 先定归宿再改动。
2. `R2` 小步闭环（可执行、可验证、可对比）。
3. `R3` 根因优先（止血补丁必须标注回收时点）。
4. `R4` 风险分级（低自动、中确认、高先预演回滚）。
5. `R5` 无证据不做预抽象或猜测式优化。
6. `R6` 硬门禁：`build + test + contract/invariant + hotspot`。
7. `R7` 不破坏契约、数据格式、外部行为与向后兼容。
8. `R8` 留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.4 N/A 与 Waiver 最低字段
- `N/A`: `reason`、`alternative_verification`、`evidence_link`。
- `Waiver`: `owner`、`expires_at`、`status`、`recovery_plan`、`evidence_link`。

## B. Claude 平台差异（全局）
### B.1 加载链与覆盖
- 推荐目录：`~/.claude`；以 CLI 实际加载结果为准。
- 优先级：`CLAUDE.override.md > CLAUDE.md > fallback`（平台支持时）。
- `CLAUDE.override.md` 仅用于短期排障；结束后删除并复测。

### B.2 最小诊断矩阵（Claude）
- 必做：`claude --version`、`claude --help`。
- 可选：状态/加载链命令（若 CLI 提供）。
- 留痕字段：`cmd`、`exit_code`、`key_output`、`timestamp`。

### B.3 不支持项回退
- 命令缺失/行为不一致：记录 `N/A + 原因 + 替代命令 + 证据位置`。
- 替代命令仅补证据，不改变规则语义与门禁顺序。

## C. 项目级承接契约（全局模板）
### C.1 自包含与边界
- 项目级同名文件必须完整自包含，并显式承接 `GlobalUser/CLAUDE.md`。
- 项目级仅写本仓事实，不复述全局规则正文。

### C.2 项目级必填项
- 模块边界与目标归宿。
- 门禁命令与顺序：`build -> test -> contract/invariant -> hotspot`。
- 失败分流与阻断条件。
- 证据与回滚位置。
- `Global Rule -> Repo Action` 承接映射。

### C.3 协同判定（1+1>2）
- 不重叠：同一语义只在一个层级定义。
- 不缺失：项目级必须有落地动作或 `N/A`。
- 可执行：任一层级单独阅读即可执行本层职责。

## D. 维护校验清单（全局）
- 结构保持 `1 / A / B / C / D`。
- 全局文件不得写仓库特有路径与命令。
- 三层完整：`共性基线 + 平台差异 + 项目差异`。
- 协同链完整：`规则 -> 落点 -> 命令 -> 证据 -> 回滚`。