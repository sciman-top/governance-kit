# 20260407-cli-capture-dedup

## 任务理解快照
- 目标: 去重 CLI 诊断脚本中的重复命令捕获逻辑, 提升可维护性与一致性。
- 非目标: 不改变门禁语义、不改变对外命令与参数接口。
- 验收标准: `check-cli-capabilities.ps1` 与 `check-cli-version-drift.ps1` 输出结构兼容, 且全门禁通过。
- 关键假设: `scripts/lib/common.ps1` 在仓内可用并可被两个脚本稳定 dot-source（已确认）。

## 规则与风险
- rule_id: R2/R6/R8
- risk_level: low
- 变更类型: 去重重构（行为等价）

## 依据 -> 命令 -> 证据 -> 回滚
- 依据:
  - `scripts/check-cli-capabilities.ps1` 与 `scripts/check-cli-version-drift.ps1` 均存在本地 `Invoke-CommandCapture` 重复实现。
- 命令:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-cli-capabilities.ps1 -AsJson`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-cli-version-drift.ps1 -AsJson`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`
- 关键输出:
  - `check-cli-capabilities`: `status=WARN`（仅 `codex status` 的 `stdin is not a terminal` 被记录为 `platform_na`，符合预期）。
  - `check-cli-version-drift`: `status=PASS`, `drift_count=0`。
  - 门禁链路: `build/test/contract/hotspot` 全部 `exit_code=0`。
- 回滚动作:
  - 回退文件:
    - `scripts/lib/common.ps1`
    - `scripts/check-cli-capabilities.ps1`
    - `scripts/check-cli-version-drift.ps1`
  - 若需目录级回滚: `powershell -File scripts/restore.ps1` + 指定 `backups/<timestamp>/`。

## 术语解释点
- 术语: `platform_na`
  - 一句话定义: 平台能力缺失或命令在当前运行形态不支持时的标准化 N/A 记录。
  - 本仓示例: 非交互环境下 `codex status` 返回 `stdin is not a terminal`。
  - 常见误解: 不是脚本失败, 而是需用替代证据补齐诊断闭环。

## 可观测性与排障
- 现象: CLI 诊断脚本存在重复函数, 后续维护容易漂移。
- 假设: 将重复函数收敛到 `common.ps1` 可降低漂移, 且保持行为兼容（已确认）。
- 验证命令: 见上方“命令”。
- 预期结果: 两脚本 JSON 结构不破坏, 全门禁通过。
- 下一步: 在后续批次继续收敛其他重复函数族（如 `Assert-Command`/`Invoke-LoggedCommand`）。

## 未确认假设与纠偏结论
- 未确认假设: 无。
- 纠偏结论: 无需纠偏。

## learning_points_3
- 统一命令捕获结构可减少跨脚本行为漂移。
- 在 `common.ps1` 中保留 `output/raw_output` 双字段可平滑兼容历史调用方。
- 先做低风险去重并全门禁回归, 比一次性大重构更稳健。

## reusable_checklist
- 识别重复逻辑是否跨脚本重复出现。
- 抽取前确认输出契约字段。
- 抽取后先跑定向脚本, 再跑全门禁顺序链路。
- 补齐证据文档中的回滚入口与关键输出。

## open_questions
- 是否在下一批将 `Resolve-KitRoot`/`Invoke-LoggedCommand` 族统一到共享库。
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
