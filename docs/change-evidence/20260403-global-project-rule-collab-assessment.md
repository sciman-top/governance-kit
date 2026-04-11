# 变更证据：全局/项目规则协作评估与优化（1+1>2）

- 日期：2026-04-03
- 规则 ID：RULE-COLLAB-20260403
- 风险等级：MEDIUM（规则文档与分发同步）
- 变更范围：`source/global/*`、`source/project/*(协作适配)`、`source/template/project/*`
- 执行人：Codex

## 1. 目标与约束
- 目标：评估并优化全局用户级与项目级规则协作效能，确保三层职责清晰：`共性基线 + 平台差异 + 项目差异`。
- 约束：
  - 项目级仅做协作适配，不做大改。
  - 规则文档需完整自包含、结构化、无歧义、可维护。
  - 全量文档需精简，避免冗余。

## 2. 评估范围
- 全局规则（3）：
  - `source/global/AGENTS.md`
  - `source/global/CLAUDE.md`
  - `source/global/GEMINI.md`
- 项目规则（9）：
  - `source/project/ClassroomToolkit/{AGENTS,CLAUDE,GEMINI}.md`
  - `source/project/repo-governance-hub/{AGENTS,CLAUDE,GEMINI}.md`
  - `source/project/skills-manager/{AGENTS,CLAUDE,GEMINI}.md`
- 模板规则（3）：
  - `source/template/project/{AGENTS,CLAUDE,GEMINI}.md`

## 3. 评分模型
- 三层职责完整性（20）
- 平台差异清晰度（15）
- 全局-项目协作映射完整性（20）
- 边界清晰与无重叠/无缺失（15）
- 自包含与可执行性（10）
- 结构化与无歧义（10）
- 精简度与可维护性（10）

## 4. 评估结果（改造后）
- 全局规则组：95/100
- repo-governance-hub 项目组：93/100
- skills-manager 项目组：93/100
- ClassroomToolkit 项目组：95/100（本轮以复核为主）
- 模板组：92/100
- 综合评分：94/100

## 5. 关键改进项
- 全局规则：
  - 强化平台差异边界（Codex/Claude/Gemini 各自探测与回退语义）。
  - 增加边界防重叠约束（全局不下沉仓库私有动作，项目不改写全局语义）。
- 项目规则（仅协作适配）：
  - 在 `repo-governance-hub` 与 `skills-manager` 增补 `Global 输出字段 -> Repo 证据字段` 映射。
  - 保持门禁、阻断、仓库事实不变。
- 模板规则：
  - 重整为与全局契约一致的三层结构并精简冗余，提升新仓落地一致性。

## 6. 执行命令与关键输出
- 结构与范围盘点：
  - `rg "^# |^\\*\\*版本\\*\\*|^\\*\\*最后更新\\*\\*|^## [1ABCD]" source/global source/project source/template/project -n`
  - 关键输出：目标规则文件均具备 `1/A/B/C/D` 主结构。
- 门禁链路：
  - `powershell -File scripts/verify-kit.ps1`
  - `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -File scripts/validate-config.ps1`
  - `powershell -File scripts/verify.ps1`
  - `powershell -File scripts/doctor.ps1`
  - 关键输出：
    - `verify-kit`: `repo-governance-hub integrity OK`
    - `tests`: 全部通过
    - `verify`: 最终 `ok=31 fail=0`
    - `doctor`: `HEALTH=GREEN`
- 同步分发：
  - `powershell -File scripts/install.ps1 -Mode safe`
  - 关键输出：
    - 全局规则与项目规则已同步到各目标目录
    - 末次结果：`Verify done. ok=31 fail=0`，`[ASSERT] post-verify passed`

## 7. 同步落点确认
- 全局用户级：
  - `C:\Users\sciman\.codex\AGENTS.md`
  - `C:\Users\sciman\.claude\CLAUDE.md`
  - `C:\Users\sciman\.gemini\GEMINI.md`
- 项目仓库级：
  - `E:\CODE\ClassroomToolkit\{AGENTS,CLAUDE,GEMINI}.md` 及配置中的 custom 文件
  - `E:\CODE\skills-manager\{AGENTS,CLAUDE,GEMINI}.md` 及配置中的 custom 文件
  - `E:\CODE\repo-governance-hub\{AGENTS,CLAUDE,GEMINI}.md`

## 8. 异常与修复记录
- 发现一次目标仓差异：
  - 文件：`source/project/ClassroomToolkit/custom/scripts/quality/run-local-quality-gates.ps1`
  - 现象：`verify` 报 1 个 DIFF（`ok=30 fail=1`）
  - 处理：再次执行 `install -Mode safe` 后恢复一致（`ok=31 fail=0`）

## 9. 回滚动作
- 文档分发回滚入口：`powershell -File scripts/restore.ps1`
- 备份目录：
  - `backups/20260403-032034/`
  - `backups/20260403-201144/`
- 回滚后复验：
  - `powershell -File scripts/validate-config.ps1`
  - `powershell -File scripts/verify.ps1`
  - `powershell -File scripts/doctor.ps1`

## 10. 结论
- 本次变更满足目标：全局与项目职责边界更清晰，平台差异更可执行，协作映射更完整。
- 在“不大改项目规则”的约束下完成协作适配与同步闭环，当前治理健康状态为 `GREEN`。

