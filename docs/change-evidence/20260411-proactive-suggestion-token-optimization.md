# Change Evidence — 20260411 proactive-suggestion token optimization

## rule_id
- GK-PROACTIVE-SUGGESTION-TOKEN-OPT-20260411

## risk_level
- medium (policy behavior change, no code-path refactor)

## task_snapshot
- goal: 在目标仓 AI 编码时提高主动建议覆盖并降低 token 消耗。
- non_goal: 不改动门禁顺序，不引入新执行脚本，不改变回滚机制。
- acceptance: build/test/contract/hotspot 全通过，且分发后 source 与目标仓策略一致。
- key_assumptions:
  - confirmed: 目标仓的主动建议策略来自 `source/project/_common/custom/.governance/*` 分发。
  - confirmed: 减少建议词数预算不会影响门禁脚本语义。

## rationale
- 增加高价值触发场景，减少“该提醒未提醒”。
- 下调建议字数预算，控制会话 token 成本。

## changes
- updated `.governance/proactive-suggestion-policy.json`
  - triggers added: `test_failure`, `ci_failure`, `core_config_change`, `pre_commit_check`, `compatibility_risk`
  - token_guard tuned:
    - `max_total_suggestion_words_per_turn`: 60 -> 40
    - `max_total_suggestion_words_per_issue`: 200 -> 160
- updated `.governance/token-saver-policy.json`
  - token_guard tuned:
    - `max_total_words_per_turn`: 120 -> 90
- synced source-of-truth mirror:
  - `source/project/_common/custom/.governance/proactive-suggestion-policy.json`
  - `source/project/_common/custom/.governance/token-saver-policy.json`
- redistributed by install safe mode so downstream repos receive same policy.

## commands
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File tests/governance-kit.optimization.tests.ps1`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1`
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1`
5. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe`
6. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1`

## key_output
- verify-kit: `governance-kit integrity OK`
- tests: optimization test suite passed (full suite green)
- verify(before install): found DIFF against `ClassroomToolkit/skills-manager` proactive/token policy files
- install safe: copied updated policy files to target repos
- verify(after install): `Verify done. ok=187 fail=0`
- doctor: `HEALTH=GREEN`

## observability_signals
- source->target policy parity changed from DIFF to OK.
- hotspot summary remained GREEN after redistribution.

## troubleshooting_path
- symptom: contract gate failed (`verify.ps1` reported DIFF on policy files)
- hypothesis: source policy changed but target repos not yet redistributed
- validation: run `install.ps1 -Mode safe`
- result: DIFF cleared, gates passed

## rollback
- entry: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restore.ps1`
- backup location: `backups/<timestamp>/`
- fine-grained manual rollback targets:
  - `.governance/proactive-suggestion-policy.json`
  - `.governance/token-saver-policy.json`
  - `source/project/_common/custom/.governance/proactive-suggestion-policy.json`
  - `source/project/_common/custom/.governance/token-saver-policy.json`

## terminology
- proactive suggestion: AI 在不打断主任务前提下主动给出可执行建议。
- token guard: 对建议长度和总量的预算约束，超预算自动降级。
- dedupe cooldown: 同主题建议冷却窗口，避免重复打扰。

## unconfirmed_assumptions_and_corrections
- unconfirmed: 新增 triggers 是否被每个外层 AI 运行时统一消费。
- mitigation: 保持向后兼容（仅新增字段，不移除旧字段），并通过分发一致性和门禁验证保证当前仓可用。

## learning_points_3
1. 政策类变更在本仓通过后仍需 `install` 才能消除跨仓 DIFF。
2. 建议覆盖与 token 成本可通过“触发增量 + 预算下调”同时优化。
3. `verify.ps1` 是发现 source/target 漂移的关键哨兵。

## reusable_checklist
- [x] 修改 runtime policy 文件与 source 同步文件
- [x] 按 `build -> test -> contract/invariant -> hotspot` 运行门禁
- [x] 若 contract 出现 DIFF，执行 `install -Mode safe` 后重验
- [x] 记录回滚入口与关键输出

## open_questions
- 是否需要为各 AI 运行时增加统一 trigger 映射文档，明确新字段的消费优先级。
