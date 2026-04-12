# 20260410-proactive-suggestion-matrix

- 规则 ID: proactive_suggestion_matrix_v1
- 风险等级: medium
- 目标: 在需求/功能/设计场景实现“高覆盖主动建议 + token 可控 + 去重防重复”。

## 任务理解快照
- 目标: 各目标仓在合适时机主动给建议、启发用户，并控制 token 消耗。
- 非目标: 在脚本内自动调用模型 CLI；改变硬门禁顺序。
- 验收标准:
  - 模板与项目规则包含 `silent/lite/standard` 分级、触发场景、去重、降级条款。
  - 策略文件 `.governance/proactive-suggestion-policy.json` 已随分发落地到目标仓。
  - 硬门禁 `build -> test -> contract/invariant -> hotspot` 全通过。

## 变更文件
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
- `source/project/_common/custom/.governance/proactive-suggestion-policy.json`（新增）
- `config/project-custom-files.json`（默认分发清单新增策略文件）

## 关键策略
- 默认 `lite`：每轮 `1-2` 条建议，短句可执行。
- 升级 `standard`：需求澄清/方案设计/架构选型/上线前评审触发，最多 `2-3` 条。
- `silent`：用户显式 opt-out 时静默。
- 去重: `topic_signature + cooldown_turns=6`，避免同主题重复输出。
- token 护栏：`max_total_suggestion_words_per_turn=120`，预算紧张优先 `lite`。

## 分发与验证命令
1. `powershell -File scripts/install.ps1 -Mode safe`
2. `powershell -File scripts/verify-kit.ps1`
3. `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
4. `powershell -File scripts/validate-config.ps1`
5. `powershell -File scripts/verify.ps1`
6. `powershell -File scripts/doctor.ps1`

## 关键输出
- `install`: `copied=9`, `skipped=103`, `targets=112`，并验证 source/target `ok=112 fail=0`。
- `verify`: `ok=112 fail=0`。
- `doctor`: `HEALTH=GREEN`。
- 硬门禁全通过。

## 回滚
- 回滚入口：`powershell -File scripts/restore.ps1`
- 本次快照目录：`backups/20260410-230229/`
- 快速回退：撤销上述 source/config 变更后执行 `scripts/install.ps1 -Mode safe`。

## learning_points_3
1. 主动建议能力应优先通过规则与策略文件表达，而非脚本硬编码。
2. 去重与 token 护栏必须与触发场景一起定义，才能兼顾覆盖与成本。
3. 先分发再跑 verify，可避免 source/target 预期差异导致的阻断噪音。

## reusable_checklist
- 更新模板与项目规则文本
- 新增/更新 `.governance` 策略文件
- 将策略文件加入 `project-custom-files` 默认分发
- `install -Mode safe`
- 跑四段硬门禁并记录证据

## open_questions
- 是否需要为不同仓库设置不同 `cooldown_turns` 与 `max_total_suggestion_words_per_turn`（repo override）。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
