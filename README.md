# governance-kit

统一治理唯一源目录（copy 模式）。

变更记录：`CHANGELOG.md`

## 目录
- `source/global/`：全局用户级规则（AGENTS/CLAUDE/GEMINI）
- `source/project/`：项目级规则（按仓分层，示例：`source/project/<RepoName>/{AGENTS,CLAUDE,GEMINI}.md`）
- `config/targets.json`：复制映射表（source -> target）
- `config/rule-rollout.json`：规则灰度配置（observe/enforce + waiver 阻断开关）
- `config/project-rule-policy.json`：项目级规则分发白名单与自动化策略（含 `allow_local_optimize_without_backflow`、`max_autonomous_iterations`、`max_repeated_failure_per_step`、`stop_on_irreversible_risk`）
- `config/project-custom-files.json`：项目级“定制文件回拷/分发”清单（除 AGENTS/CLAUDE/GEMINI 外，建议仅放仓库特有文件）
- `config/governance-baseline.json`：治理基线版本与冻结日期
- `scripts/install.ps1`：首次部署（默认带备份）
- `scripts/sync.ps1`：快速同步（不备份）
- `scripts/verify.ps1`：先校验配置结构，再校验 source 与 target 一致性
- `scripts/restore.ps1`：从 backup 快照回滚到目标位置
- `scripts/install-extras.ps1`：分发 PR 模板、evidence 模板、git hooks、commit template
- `scripts/install-global-git.ps1`：设置全局 git `core.hooksPath` 与 `commit.template`
- `scripts/add-repo.ps1`：新增仓库并自动补齐 repositories/targets 映射，同时自动补齐 `project-custom-files.json` 仓库条目（默认空 files）
- `scripts/remove-repo.ps1`：移除仓库并清理 repositories/targets 映射，同时自动清理 `project-custom-files.json` 对应仓库条目
- `scripts/status.ps1`：输出治理映射状态统计
- `scripts/doctor.ps1`：一键健康检查（verify-kit -> validate-config -> verify -> waiver-check -> status -> rollout-status）
- `scripts/bootstrap-repo.ps1`：一键接入新仓（add-repo -> merge-rules -> install-extras -> install -> doctor）
- `scripts/bootstrap-here.ps1`：在目标仓目录执行时，自动以当前目录作为 `RepoPath` 一键接入
- `scripts/install-full-stack.ps1`：新仓/旧仓一键全量安装（bootstrap -> governance-cycle -> target-autopilot smoke -> doctor）
- `scripts/verify-kit.ps1`：校验 governance-kit 目录完整性
- `scripts/validate-config.ps1`：校验 `repositories/targets/rule-rollout/project-rule-policy` 结构与关键字段格式（含 ISO 日期）
- `scripts/merge-rules.ps1`：按章节锚点将治理规则与目标仓既有规则做半自动整合（输出 merge report）
- `scripts/rollout-status.ps1`：查看各仓规则灰度状态
- `scripts/set-rollout.ps1`：按仓库设置灰度参数（phase/block/planned_enforce_date/note）
- `scripts/check-waivers.ps1`：检查 waiver 到期（提醒/按策略阻断）
- `scripts/collect-governance-metrics.ps1`：汇总治理指标并写入各仓 `docs/governance/metrics-auto.md`
- `scripts/bump-rule-version.ps1`：批量更新规则文档 `版本/最后更新`（支持 `plan` 预览）
- `scripts/backflow-project-rules.ps1`：将目标仓项目级规则（AGENTS/CLAUDE/GEMINI）一键回拷并备份到治理源
- `scripts/analyze-repo-governance.ps1`：自动勘察目标仓结构/门禁/CI/证据目录并输出推荐配置
- `scripts/optimize-project-rules.ps1`：按勘察结果自动优化目标仓项目级规则文档
- `scripts/run-project-governance-cycle.ps1`：一键执行“安装 -> 分析 -> 优化 -> 回拷 -> 再分发校验”闭环
- `docs/governance/agent-remediation-contract.md`：脚本与外层 AI 会话代理的修复接管合同（失败 JSON 字段约定）
- `scripts/validate-failure-context.ps1`：校验 `[FAILURE_CONTEXT_JSON]` 合同字段，确保外层 AI 接管上下文完整
- `docs/governance/oneclick-target-state-matrix.md`：一键安装目标终态分级验收矩阵（L1/L2/L3）
- `scripts/run-endstate-onboarding.ps1`：一键执行“接入 -> 安装 -> 证据收敛 -> 终态门禁 -> doctor”终态接入闭环
- `scripts/audit-governance-readiness.ps1`：生成一键治理就绪审计报告（Markdown/JSON）
- `scripts/governance/run-target-autopilot.ps1`：纯门禁编排器（`build -> test -> contract/invariant -> hotspot`），不内嵌 `codex/claude/gemini exec`；智能修复与规则优化由外层 AI 会话负责。
- `scripts/check-orphan-custom-sources.ps1`：检查 `source/project/*/custom` 未映射且不在清单中的孤儿文件
- `scripts/prune-orphan-custom-sources.ps1`：归档并清理孤儿 custom 源文件
- `scripts/prune-backups.ps1`：按保留天数/保留数量清理 `backups/` 历史快照（支持 `plan` 预演）
- `scripts/suggest-project-custom-files.ps1`：扫描目标仓并给出 `project-custom-files.json` 候选条目（支持 `-AsJson`）
- `scripts/verify-json-contract.ps1`：校验 `status/rollout-status/doctor` 的 JSON 合同字段与 schema 版本
- `scripts/run-real-repo-regression.ps1`：按真实仓库矩阵执行计划/烟测/全量回归
- `backups/`：install 生成的目标文件备份
- `ci/`：GitHub Actions / Azure Pipelines / GitLab CI 通用模板
- `config/editorconfig.base`：跨语言最小格式基线

## 当前目标映射（以 `scripts/status.ps1` 输出为准）
- `source/global/AGENTS.md -> C:\Users\sciman\.codex\AGENTS.md`
- `source/global/CLAUDE.md -> C:\Users\sciman\.claude\CLAUDE.md`
- `source/global/GEMINI.md -> C:\Users\sciman\.gemini\GEMINI.md`
- `source/project/ClassroomToolkit/AGENTS.md -> E:\CODE\ClassroomToolkit\AGENTS.md`
- `source/project/ClassroomToolkit/CLAUDE.md -> E:\CODE\ClassroomToolkit\CLAUDE.md`
- `source/project/ClassroomToolkit/GEMINI.md -> E:\CODE\ClassroomToolkit\GEMINI.md`
- `source/project/ClassroomToolkit/custom/* -> E:\CODE\ClassroomToolkit\<relative-path>`
- `source/project/_common/custom/* -> <AnyTargetRepo>/<relative-path>`（新仓默认通用能力）

说明：
- 全局用户级规则只分发到本机用户目录（`.codex` / `.claude` / `.gemini`），不再复制到目标仓 `GlobalUser/*`。
- 目标仓项目级“非三规则文档”的文件清单由 `config/project-custom-files.json` 控制。
- 通用模板/通用 CI 由 `install-extras.ps1` 维护；`project-custom-files.json` 建议只保留仓库特有文件，避免双轨维护。
- 新仓默认会分发通用自动化脚本（`source/project/_common/custom/scripts/governance/*`），用于目标仓本地连续自动执行。
- 新仓若未命中 `project-rule-policy` 白名单，仍会注入通用项目级三规则模板（`source/template/project/{AGENTS,CLAUDE,GEMINI}.md`），确保“持续自动执行 + 最佳实践终态 + 防过度设计/过度优化”基线可落地。
- 建议每个仓在 `project-custom-files.json` 都保留显式条目（可空 `files: []`），以便审计与自动化一致性校验。
- 备份目录结构按目标绝对路径镜像生成。

## 使用
### 推荐流程（系统安装 + 项目级定制回路）
适用于新仓与旧仓，差别仅在“是否需要先接入仓库映射”。

一键全量安装（推荐）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install-full-stack.ps1 -RepoPath E:\CODE\NewRepo -Mode safe
```
说明：
- 自动执行：`bootstrap-repo -> run-project-governance-cycle -> target-autopilot dry-run -> doctor`。
- 脚本仅负责编排与失败上下文输出；修复由当前 AI 会话代理执行（不在脚本内调用 `codex/claude/gemini exec`）。
- 目标仓会安装通用脚本：`scripts/governance/run-project-governance-cycle.ps1`、`scripts/governance/run-target-autopilot.ps1`。
- 对不在 `project-rule-policy` 白名单的仓库，默认会自动跳过 `optimize/backflow`；若策略开启 `allow_local_optimize_without_backflow=true`，允许仅本仓优化并继续禁止回灌。
- 自动连续执行边界由 `project-rule-policy` 控制：`max_autonomous_iterations`（最大自治轮次）、`max_repeated_failure_per_step`（单步骤重复失败上限）、`stop_on_irreversible_risk`（不可逆风险边界停机，默认对 `contract.*` 失败立即停机）。

主流程（系统安装流）：
1. 新仓先接入（旧仓可跳过）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\bootstrap-repo.ps1 -RepoPath E:\CODE\NewRepo -Mode safe
```
2. 已接入仓执行标准安装：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1 -Mode safe
powershell -File E:\CODE\governance-kit\scripts\install-extras.ps1 -Mode safe
powershell -File E:\CODE\governance-kit\scripts\doctor.ps1
```

项目级定制回路（需要目标仓试改时）：
1. 先把仓库专属项目规则覆盖到目标仓三文件：
```powershell
# 示例仓：ClassroomToolkit
Copy-Item E:\CODE\governance-kit\source\project\ClassroomToolkit\AGENTS.md E:\CODE\ClassroomToolkit\AGENTS.md -Force
Copy-Item E:\CODE\governance-kit\source\project\ClassroomToolkit\CLAUDE.md E:\CODE\ClassroomToolkit\CLAUDE.md -Force
Copy-Item E:\CODE\governance-kit\source\project\ClassroomToolkit\GEMINI.md E:\CODE\ClassroomToolkit\GEMINI.md -Force
```
2. 在目标仓直接优化三份项目级文档（`AGENTS/CLAUDE/GEMINI`）。
3. 将优化结果回灌到治理源：
```powershell
Copy-Item E:\CODE\ClassroomToolkit\AGENTS.md E:\CODE\governance-kit\source\project\ClassroomToolkit\AGENTS.md -Force
Copy-Item E:\CODE\ClassroomToolkit\CLAUDE.md E:\CODE\governance-kit\source\project\ClassroomToolkit\CLAUDE.md -Force
Copy-Item E:\CODE\ClassroomToolkit\GEMINI.md E:\CODE\governance-kit\source\project\ClassroomToolkit\GEMINI.md -Force
```
4. 回灌后立即再分发与校验，确保 source/target 一致：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1 -Mode safe
powershell -File E:\CODE\governance-kit\scripts\doctor.ps1
```

约束：
- 未完成“回灌 + 再分发校验”前，不要再次执行 `sync/install`，避免覆盖目标仓未沉淀改动。
- 项目级规则以 `source/project/<RepoName>/*` 为唯一归宿，不在目标仓长期维护“孤儿版本”。

### 提示词模板（可直接复制）
1. 完整闭环（推荐）
```text
按上次“真正全面审查后优化”的同标准，对 <目标仓路径> 自动连续执行完整闭环（safe）：安装、深度审查（规则分发/hooks/模板/git配置/CI门禁）、优化项目级文档、回灌到 governance-kit、再分发并 doctor 验证；有错由当前 AI 会话代理修复后继续执行。
```

2. 仅深度审查 + 代理修复
```text
全面审查 <目标仓路径> 的治理落地（分发映射、hooks、模板、git config、CI门禁、证据目录、风险阻断），直接修复问题并复验。
```

3. 仅项目级文档优化
```text
基于目标仓真实结构，优化 <目标仓路径> 的 AGENTS/CLAUDE/GEMINI（重点 C2/C3/C7/C8/C9），避免过度设计，按事实收敛。
```

4. 仅回灌备份（目标仓 -> governance-kit）
```text
把 <目标仓路径> 的 AGENTS/CLAUDE/GEMINI 回灌到 governance-kit 的 source/project/<RepoName>，并生成备份快照，不处理全局用户级文件。
```

5. 仅健康复验
```text
对 governance-kit 与 <目标仓路径> 执行 install + doctor + verify 全量复验，输出失败项并由当前 AI 会话代理修复。
```

1. 首次部署（带备份，默认 `safe`）
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1
```

仅查看将要变更的规则文件（不落地）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1 -Mode plan
```
执行前打印本次将处理的文件清单：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1 -Mode safe -ShowScope
```

禁止覆盖目标仓已存在且有差异的规则文件：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1 -Mode safe -NoOverwriteRules
```

如需跳过安装后的目标一致性断言（默认会自动执行 `verify.ps1`）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install.ps1 -SkipPostVerify
```

2. 日常同步（不备份，默认 `safe`）
```powershell
powershell -File E:\CODE\governance-kit\scripts\sync.ps1
```

日常同步预览（只读）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\sync.ps1 -Mode plan
```

输出结构化摘要（JSON）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\sync.ps1 -AsJson
```

3. 一致性校验
```powershell
powershell -File E:\CODE\governance-kit\scripts\verify.ps1
```

4. 分发扩展项（模板/hooks，默认 `safe`）
```powershell
powershell -File E:\CODE\governance-kit\scripts\install-extras.ps1
```
会落地到仓库：
- `.github/pull_request_template.md`
- `.github/workflows/quality-gates.yml`
- `azure-pipelines.yml`
- `.gitlab-ci.yml`
- `docs/change-evidence/template.md`
- `docs/governance/waiver-template.md`
- `docs/governance/metrics-template.md`
- `docs/governance/waivers/_template.md`
- `.editorconfig`（目标仓不存在时创建）
- 已存在模板默认不覆盖（`pull_request_template.md`、`docs/change-evidence/template.md`、`.gitmessage.txt`）
- CI 模板会尝试执行 `scripts/quality/run-supply-chain-checks.ps1`（不存在则跳过）
- CI 模板会尝试执行 `scripts/quality/check-waivers.ps1`（不存在则跳过）
- hooks 在 `safe` 模式默认“注入治理块”，不整文件覆盖已有 hook；`force` 模式会覆盖 hook 文件

只查看将要变更内容（不落地）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install-extras.ps1 -Mode plan
```

如需覆盖仓库已存在的 CI 文件（默认不覆盖）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install-extras.ps1 -OverwriteCI
```

如需覆盖仓库已存在的模板文件：
```powershell
powershell -File E:\CODE\governance-kit\scripts\install-extras.ps1 -OverwriteTemplates
```

5. 安装全局 Git 治理（不依赖单仓 .git）
```powershell
powershell -File E:\CODE\governance-kit\scripts\install-global-git.ps1
```
该命令会设置全局：
- `core.hooksPath`
- `commit.template`
- `governance.kitRoot`（供仓库 hooks 动态定位 governance-kit）

6. 新仓接入（自动补齐映射）
```powershell
powershell -File E:\CODE\governance-kit\scripts\add-repo.ps1 -RepoPath E:\CODE\NewRepo
```
说明：
- 新仓不会新增“全局用户级 -> 目标仓 GlobalUser/*”映射。
- `source/project/*` 仅会分发到 `config/project-rule-policy.json` 白名单仓。
- 项目级规则优先读取 `source/project/<RepoName>/{AGENTS,CLAUDE,GEMINI}.md`；若不存在则回退旧路径 `source/project/{AGENTS,CLAUDE,GEMINI}.md`。

移除仓库映射（支持只读预览）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\remove-repo.ps1 -RepoPath E:\CODE\OldRepo -Mode plan
```

7. 查看治理状态
```powershell
powershell -File E:\CODE\governance-kit\scripts\status.ps1
```

8. 一键健康检查
```powershell
powershell -File E:\CODE\governance-kit\scripts\doctor.ps1
```

仅做结构健康检查（跳过 target 一致性校验）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\doctor.ps1 -SkipVerifyTargets
```

单独校验配置结构：
```powershell
powershell -File E:\CODE\governance-kit\scripts\validate-config.ps1
```

9. 新仓一键接入（推荐）
```powershell
powershell -File E:\CODE\governance-kit\scripts\bootstrap-repo.ps1 -RepoPath E:\CODE\NewRepo
```

按模式接入（`plan/safe/force`）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\bootstrap-repo.ps1 -RepoPath E:\CODE\NewRepo -Mode safe
```
说明：
- `plan` 为只读模式：不会写 `repositories.json`、`targets.json`，也不会执行全局 git 配置写入。
- `safe/force` 会先执行 `merge-rules`，再执行安装；`safe` 下安装阶段默认不覆写该仓已存在规则文件。

在目标仓目录直接执行（自动使用当前目录）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\bootstrap-here.ps1 -Mode safe
```

10. 单独执行规则整合（先看计划）
```powershell
powershell -File E:\CODE\governance-kit\scripts\merge-rules.ps1 -RepoPath E:\CODE\NewRepo -Mode plan
```

11. 回滚到最近一次备份
```powershell
powershell -File E:\CODE\governance-kit\scripts\restore.ps1
```

指定回滚快照：
```powershell
powershell -File E:\CODE\governance-kit\scripts\restore.ps1 -BackupName 20260329-191309
```

允许回滚到 `targets.json` 白名单之外的路径（默认阻断）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\restore.ps1 -BackupName 20260329-191309 -AllowOutOfScope
```

12. 查看规则灰度状态
```powershell
powershell -File E:\CODE\governance-kit\scripts\rollout-status.ps1
```
说明：
- `phase.observe_overdue` / `rollout.observe_overdue` 表示“已超过 `planned_enforce_date` 但仍处于 observe”的仓库数量。

设置某仓灰度参数（推荐先 `plan`）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\set-rollout.ps1 -RepoPath E:\CODE\ClassroomToolkit -Phase observe -BlockExpiredWaiver:$false -PlannedEnforceDate 2026-04-15 -Mode plan
```

13. 执行 Waiver 到期检查
```powershell
powershell -File E:\CODE\governance-kit\scripts\check-waivers.ps1
```

14. 汇总治理指标（写入各仓 docs/governance/metrics-auto.md）
```powershell
powershell -File E:\CODE\governance-kit\scripts\collect-governance-metrics.ps1
```

15. 统一更新规则版本号与日期（先预览）
```powershell
powershell -File E:\CODE\governance-kit\scripts\bump-rule-version.ps1 -Scope all -Version 9.32 -Mode plan
```
只更新全局规则：
```powershell
powershell -File E:\CODE\governance-kit\scripts\bump-rule-version.ps1 -Scope global -Version 9.32 -Date 2026-03-29

16. 新仓/旧仓一键终态接入（推荐）
```powershell
powershell -File E:\CODE\governance-kit\scripts\run-endstate-onboarding.ps1 -RepoPath E:\CODE\NewRepo -Mode safe -EvidenceMode all
```
说明：
- 自动执行：`add-repo -> install -> install-extras -> evidence-check -> (可选backfill) -> run-endstate-loop -> doctor`。
- 默认 `AutoBackfillEvidence=true`，用于旧仓证据存量收敛。
- 若仓库不具备 `scripts/governance/*`，会自动跳过对应步骤，仅执行通用接入与健康检查。
```

16. 一键回拷目标仓项目级规则到治理源（默认不处理全局用户级文件）
```powershell
powershell -File E:\CODE\governance-kit\scripts\backflow-project-rules.ps1 -RepoPath E:\CODE\ClassroomToolkit -RepoName ClassroomToolkit -Mode safe
```
说明：
- 会自动备份“回拷前 source”与“目标仓快照”，备份目录：`backups/backflow-<timestamp>/<RepoName>/`。
- 默认处理目标仓根目录 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md`，并按 `config/project-custom-files.json` 回拷项目级定制文件。
- 回拷定制文件时会自动补齐 `config/targets.json` 映射：`source/project/<RepoName>/custom/<relative> -> <Repo>/<relative>`。
- 全局用户级文件（如 `.codex/.claude/.gemini`）默认不参与回拷。
- 如需额外记录 CI 入口差异快照，可加 `-IncludeCiSnapshot`。
- 如需禁用定制文件回拷，优先使用 `-SkipCustomFiles`（保留兼容：`-IncludeCustomFiles:$false`）。
- 执行前打印本次回拷文件清单，可加 `-ShowScope`。

17. 自动勘察目标仓治理事实（第2步前置）
```powershell
powershell -File E:\CODE\governance-kit\scripts\analyze-repo-governance.ps1 -RepoPath E:\CODE\ClassroomToolkit
```
输出 JSON：
```powershell
powershell -File E:\CODE\governance-kit\scripts\analyze-repo-governance.ps1 -RepoPath E:\CODE\ClassroomToolkit -AsJson
```

18. JSON 状态输出（便于 CI 或监控消费）
```powershell
powershell -File E:\CODE\governance-kit\scripts\status.ps1 -AsJson
powershell -File E:\CODE\governance-kit\scripts\rollout-status.ps1 -AsJson
powershell -File E:\CODE\governance-kit\scripts\doctor.ps1 -AsJson
```
说明：JSON 输出包含 `schema_version` 字段，便于做稳定合同校验。

19. 备份快照保留策略（先预演再执行）
```powershell
powershell -File E:\CODE\governance-kit\scripts\prune-backups.ps1 -Mode plan -RetainDays 30 -RetainCount 50
powershell -File E:\CODE\governance-kit\scripts\prune-backups.ps1 -Mode safe -RetainDays 30 -RetainCount 50
```
如需保护特定前缀快照不被清理：
```powershell
powershell -File E:\CODE\governance-kit\scripts\prune-backups.ps1 -Mode safe -RetainDays 30 -RetainCount 50 -ProtectPrefixes backflow-,orphan-custom-prune-
```

20. JSON 合同校验（建议在发布前执行）
```powershell
powershell -File E:\CODE\governance-kit\scripts\verify-json-contract.ps1
```

21. 真实仓库回归矩阵（plan/smoke/full）
```powershell
powershell -File E:\CODE\governance-kit\scripts\run-real-repo-regression.ps1 -Mode plan
powershell -File E:\CODE\governance-kit\scripts\run-real-repo-regression.ps1 -Mode smoke
```
矩阵配置文件：
- `config/real-repo-regression-matrix.json`

发布流程与模板：
- `docs/governance/rule-release-process.md`
- `docs/governance/rule-release-template.md`

18. 自动优化目标仓项目级规则文档（第2步自动化）
```powershell
powershell -File E:\CODE\governance-kit\scripts\optimize-project-rules.ps1 -RepoPath E:\CODE\ClassroomToolkit -Mode safe
```
仅预览将要修改内容：
```powershell
powershell -File E:\CODE\governance-kit\scripts\optimize-project-rules.ps1 -RepoPath E:\CODE\ClassroomToolkit -Mode plan
```
执行前打印将优化的文件清单：
```powershell
powershell -File E:\CODE\governance-kit\scripts\optimize-project-rules.ps1 -RepoPath E:\CODE\ClassroomToolkit -Mode safe -ShowScope
```

19. 一键执行完整闭环（第1步 + 第2步 + 第3步）
```powershell
powershell -File E:\CODE\governance-kit\scripts\run-project-governance-cycle.ps1 -RepoPath E:\CODE\ClassroomToolkit -RepoName ClassroomToolkit -Mode safe
```
说明：
- 默认包含：安装、分析、优化、回拷、再分发、doctor 验证。
- 脚本不再内嵌自动修复；失败会输出 `[FAILURE_CONTEXT_JSON]`，由当前 AI 会话代理接管修复并重跑。
- 可用 `-SkipInstall/-SkipOptimize/-SkipBackflow` 按需跳过阶段。
- 可用 `-ShowScope` 在 install/optimize/backflow/re-distribute 前打印“本次将处理文件清单”。
- 自动连续执行遵循策略上限：超过 `max_autonomous_iterations` 或命中重复失败/不可逆风险边界后，脚本停止并输出失败上下文。

19.1 校验失败上下文合同（外层 AI 接管前）
```powershell
powershell -File E:\CODE\governance-kit\scripts\validate-failure-context.ps1 -LogPath <log-file-path>
```
或直接传 JSON：
```powershell
powershell -File E:\CODE\governance-kit\scripts\validate-failure-context.ps1 -FailureContextJson '<json>'
```

20. 生成治理就绪审计报告（发布前建议执行）
```powershell
powershell -File E:\CODE\governance-kit\scripts\audit-governance-readiness.ps1
```
输出 JSON：
```powershell
powershell -File E:\CODE\governance-kit\scripts\audit-governance-readiness.ps1 -AsJson
```

21. 检查 project custom 孤儿源文件（未映射且不在清单中）
```powershell
powershell -File E:\CODE\governance-kit\scripts\check-orphan-custom-sources.ps1
```
严格模式（发现即失败）：
```powershell
powershell -File E:\CODE\governance-kit\scripts\check-orphan-custom-sources.ps1 -FailOnOrphans
```

22. 一键归档并清理孤儿 custom 源文件
```powershell
powershell -File E:\CODE\governance-kit\scripts\prune-orphan-custom-sources.ps1 -Mode safe
```
先预览：
```powershell
powershell -File E:\CODE\governance-kit\scripts\prune-orphan-custom-sources.ps1 -Mode plan
```

## 故障排查（doctor）
- 当 `scripts/doctor.ps1` 输出 `HEALTH=RED` 时，会同时输出 `failed_steps=...`。
- 示例：`failed_steps=verify-targets` 表示失败发生在目标一致性检查阶段。
- 建议按失败步骤单独执行对应脚本复现：
  - `verify-kit` -> `scripts/verify-kit.ps1`
  - `validate-config` -> `scripts/validate-config.ps1`
  - `verify-targets` -> `scripts/verify.ps1`
  - `waiver-check` -> `scripts/check-waivers.ps1`
  - `status` -> `scripts/status.ps1`
  - `rollout-status` -> `scripts/rollout-status.ps1`

## 任务清单（最小）
- [x] 建立唯一源目录
- [x] 收敛 6 个规则文件到 source
- [x] 建立目标映射 targets.json
- [x] 提供 install/sync/verify 脚本
- [x] 提供 restore 回滚脚本
- [x] 提供模板自动分发脚本（install-extras）
- [x] 提供 hooks 载体（pre-commit/pre-push）
- [x] 提供全局 Git 安装脚本（install-global-git）
- [x] 提供 CI 通用模板（GitHub/Azure/GitLab）
- [x] 提供 editorconfig 基线并支持自动分发
- [x] 提供新仓接入/移除脚本（add-repo/remove-repo）
- [x] 提供一键健康检查脚本（doctor）
- [x] 提供新仓一键接入脚本（bootstrap-repo）
- [x] Git 仓库接入后启用 hooks 与 commit.template（ClassroomToolkit 已启用）
