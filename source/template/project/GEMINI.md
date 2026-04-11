# GEMINI.md — Generic Repo Baseline（governance-kit template）
**模板版本**: 1.5  
**适用范围**: 项目级模板（无仓库专属规则时）  
**最后更新**: 2026-04-10

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



### A.4 需求/功能/设计主动建议协议（模板）
- 默认模式：`lite`；每轮主动建议上限 `1-2` 条，优先一句话可执行建议，避免长解释。
- 升级到 `standard` 的触发场景：`需求澄清`、`方案设计`、`架构选型`、`上线前评审`；升级后上限 `2-3` 条。
- 建议主题至少覆盖其一：`风险前置`、`替代方案`、`验收口径`、`最小可行路径（MVP）`。
- 去重规则：同一 `topic_signature` 在冷却窗口内默认不重复建议；仅在需求显著变化或用户追问时重触发。
- 降级规则：用户明确“只执行不建议/不要扩展”时切 `silent`；仅执行主任务。
- 执行边界：建议“可采纳可忽略”，不得改变用户主指令优先级，不得阻断当前任务。
- 策略文件：`.governance/proactive-suggestion-policy.json`（缺失时回退模板内默认值）。
- 建议留痕字段：`proactive_suggestion_mode(silent|lite|standard)`、`suggestion_count`、`suggestion_topics`、`topic_signature`、`dedupe_skipped`、`user_opt_out`。

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

### C.4 Git 提交与推送边界（“全部”定义）
- `整理提交全部` 的“全部”仅指：`本次任务相关 + 应被版本管理 + 通过 .gitignore/.governance/tracked-files-policy 的文件`。
- 默认不纳入“全部”：IDE/agent 本地配置、临时文件、日志、备份、调试残留、缓存与本地运行态目录。
- `push` 仅推送 commit 历史，不再次筛选文件；文件筛选必须在 `git add/commit` 前完成。
- 未跟踪文件仅在被确认为本次任务产物且满足策略时纳入提交；否则保持未跟踪。
- 测试文件判定：提交前必须执行 `scripts/governance/check-tracked-files.ps1 -Scope pending -AsJson`，读取 `test_file_suggestions`。
- `suggested_action=ignore`：不得纳入 commit/push；`suggested_action=track`：可纳入；`suggested_action=review_required`：先由外层 AI 明确归类后再继续。
- 策略阻断：当 `.governance/tracked-files-policy.json` 启用 `block_on_test_file_review_required=true` 时，存在 `review_required` 将直接阻断提交/推送。

### C.5 治理问题优先修复顺序
- 发现治理链路（规则/脚本/配置）问题时，先修 governance-kit source of truth，再执行目标仓命令。
- 修复后按固定顺序复验：`build -> test -> contract/invariant -> hotspot`，通过后再继续分发、提交或推送。
- 禁止带着已知治理问题继续执行发布动作。
### C.6 子代理并行触发矩阵（默认）
- 策略文件：`.governance/subagent-trigger-policy.json`（缺失时回退到 governance-kit 内置默认策略）。
- 判定模型：`hard_guard + score`；先过硬约束（显式并行意图/可证明写集互斥/非高风险/非关键路径阻塞），再按分数阈值决定 `spawn`。
- 证据字段最少包含：`spawn_parallel_subagents`、`max_parallel_agents`、`decision_score`、`reason_codes`、`hard_guard_hits`、`policy_path`。
- 执行边界：仓内脚本只输出“并行建议与证据”；真正 `spawn` 仍由外层 AI 会话执行，不在脚本中调用模型 CLI 套娃。
## D. 维护清单
- 保持 `1 / A / B / C / D` 结构。
- A/C/D 三文件同构，仅 B 允许平台差异。
- 文档精简优先，删除不改变语义的重复描述。
- 规则更新后同步校验版本、日期、映射与门禁命令一致性。


