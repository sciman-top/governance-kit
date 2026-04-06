# AGENTS.md — Generic Repo Baseline（governance-kit template）
**模板版本**: 1.3  
**适用范围**: 项目级模板（无仓库专属规则时）  
**最后更新**: 2026-04-06

## 1. 阅读指引
- 本模板承接 `GlobalUser/AGENTS.md`，仅定义项目级落地动作（WHERE/HOW）。
- 固定结构：`1 / A / B / C / D`。
- 裁决链：`运行事实/代码 > 项目级文件 > 全局文件 > 临时上下文`。

## A. 共性基线（模板）
### A.1 三层职责
- 共性基线：执行与治理语义（WHAT）。
- 平台差异：仅写 Codex 加载/诊断/回退（PLATFORM）。
- 项目差异：仅写本仓命令、证据、回滚（WHERE/HOW）。

### A.2 执行与输出
- 默认持续执行到完成；仅在真实阻塞、不可逆风险、连续自修复失败时请求确认。
- 简单任务输出 `Result + Evidence`；复杂任务输出 `Goal / Plan / Changes / Verification / Risks`。
- 每次变更留痕：`依据 -> 命令 -> 证据 -> 回滚`。

### A.3 工程质量与门禁语义
- 优先根因修复；无证据不做预抽象和猜测式优化。
- 兼容优先：未授权不得破坏契约与外部行为。
- 门禁顺序固定：`build -> test -> contract/invariant -> hotspot`。

## B. Codex 平台差异（模板）
### B.1 加载与覆盖
- 目录：`~/.codex`（可由 `CODEX_HOME` 覆盖）。
- 优先级：`AGENTS.override.md > AGENTS.md > fallback`。
- override 仅用于短期排障，结论后删除并复测。

### B.2 最小诊断矩阵
- 必做：`codex --version`、`codex --help`。
- 状态优先：`codex status`；非交互失败按 `platform_na` 记录。
- 留痕字段：`cmd`、`exit_code`、`key_output`、`timestamp`。

### B.3 异常回退
- 命令缺失/行为不一致：记录 `platform_na` + 原因 + 替代验证 + 证据位置。
- 替代命令仅补证据，不改变门禁顺序与阻断语义。
- 禁止在仓内脚本调用 `codex exec`（或任何模型 CLI 套娃调用）做自动修复；自动修复由当前 AI 会话代理执行。

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

### C.4 Git 提交与推送边界（“全部”定义）
- `整理提交全部` 的“全部”仅指：`本次任务相关 + 应被版本管理 + 通过 .gitignore/.governance/tracked-files-policy 的文件`。
- 默认不纳入“全部”：IDE/agent 本地配置、临时文件、日志、备份、调试残留、缓存与本地运行态目录。
- `push` 仅推送 commit 历史，不再次筛选文件；文件筛选必须在 `git add/commit` 前完成。
- 未跟踪文件仅在被确认为本次任务产物且满足策略时纳入提交；否则保持未跟踪。

### C.5 治理问题优先修复顺序
- 发现治理链路（规则/脚本/配置）问题时，先修 governance-kit source of truth，再执行目标仓命令。
- 修复后按固定顺序复验：`build -> test -> contract/invariant -> hotspot`，通过后再继续分发、提交或推送。
- 禁止带着已知治理问题继续执行发布动作。
## D. 维护清单
- 保持 `1 / A / B / C / D` 结构。
- A/C/D 三文件同构，仅 B 允许平台差异。
- 文档精简优先，删除不改变语义的重复描述。
- 规则更新后同步校验版本、日期、映射与门禁命令一致性。

