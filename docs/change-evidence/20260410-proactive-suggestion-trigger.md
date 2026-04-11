# 20260410-proactive-suggestion-trigger

- 规则 ID: proactive_suggestion_trigger
- 风险等级: medium
- 变更目标: 目标仓在需求/功能/设计场景下，外层 AI 默认主动提供可执行建议（可选、不阻断主任务）。
- 任务理解快照:
  - 目标: 分发/安装后自动触发主动建议能力
  - 非目标: 引入脚本级自动调用模型、改变硬门禁顺序
  - 验收标准: 模板与已接入目标仓规则文档存在“主动建议协议”；install safe 后 verify/doctor 通过
  - 关键假设: 外层 AI 会话遵循项目级规则文档

## 依据
- 用户需求：希望目标仓在 codex cli 等 AI 编码场景下，需求/功能/设计阶段自动给启发建议。
- 仓库现状：原有规则包含澄清触发与并行建议，但未普遍声明“产品设计类主动建议”条款。

## 命令
1. `powershell -File scripts/verify-kit.ps1`
2. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
3. `powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
4. `powershell -File scripts/doctor.ps1`
5. `powershell -File scripts/install.ps1 -Mode safe`
6. `powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1`

## 关键输出
- 首次 verify 被阻断：source 与目标仓规则文件存在差异（符合“待分发”状态）。
- 执行 `install -Mode safe` 后：
  - 关键规则文件已复制到 `E:/CODE/ClassroomToolkit`、`E:/CODE/skills-manager`、`E:/CODE/repo-governance-hub`。
  - `verify` 输出 `ok=109 fail=0`。
  - `doctor` 输出 `HEALTH=GREEN`，`[ASSERT] post-gate full chain passed`。

## 变更文件（source of truth）
- `source/template/project/AGENTS.md`
- `source/template/project/CLAUDE.md`
- `source/template/project/GEMINI.md`
- `source/project/skills-manager/AGENTS.md`
- `source/project/skills-manager/CLAUDE.md`
- `source/project/skills-manager/GEMINI.md`
- `source/project/ClassroomToolkit/AGENTS.md`
- `source/project/ClassroomToolkit/CLAUDE.md`
- `source/project/ClassroomToolkit/GEMINI.md`
- `source/project/repo-governance-hub/AGENTS.md`
- `source/project/repo-governance-hub/CLAUDE.md`
- `source/project/repo-governance-hub/GEMINI.md`

## 新增条款（摘要）
- 触发场景：`产品需求/功能实现/方案设计/交互流程/技术选型`
- 默认行为：外层 AI 额外提供 `2-3` 条可执行建议
- 约束：建议可忽略，不阻断主指令
- 退出条件：用户显式 `只执行不建议/不要扩展` 时静默
- 留痕字段：`proactive_suggestion_mode`、`suggestion_count`、`suggestion_topics`、`user_opt_out`

## 回滚
- 快照目录：`backups/20260410-225451/`
- 回滚入口：`powershell -File scripts/restore.ps1`
- 细粒度回滚：将上述 source 文件回退并执行 `powershell -File scripts/install.ps1 -Mode safe` 重新分发。

## 术语解释点
- 主动建议协议：在不改变用户主目标的前提下，外层 AI 默认补充可执行建议。
- 可采纳可忽略：建议是“供参考”，不构成流程阻断条件。

## learning_points_3
1. 若规则文本变更未分发，`verify.ps1` 会以 source/target 差异阻断，这是预期保护机制。
2. 版本号需跨项目规则保持一致，否则 `verify-kit.ps1` 会阻断。
3. 将“建议行为”写入项目级规则，比脚本硬编码更稳健且跨平台。

## reusable_checklist
- 修改 source 规则
- 同步版本号与日期
- 跑 `build -> test -> contract/invariant -> hotspot`
- 执行 `install -Mode safe`
- 再跑 `verify + doctor`
- 记录证据与回滚

## open_questions
- 是否要把“建议条数（2-3）”抽成可配置项（例如 `.governance/release-profile.json`）以便仓库级覆盖。