# 20260415 Agent Runtime Task6 Policy Baselines

## Goal
- 为 runtime policy 补齐 prompt/tool/memory 三类 baseline 实例，并让证据模板可记录 runtime 覆盖率与新鲜度字段。

## Task Snapshot
- 目标：`config/agent-runtime-policy.json` 从“占位结构”升级到“最小可执行示例”。
- 非目标：切换到 enforce；修改 gate 顺序。
- 验收：新增测试通过 + `validate-config` 通过。
- 关键假设（已确认）：Q2 阶段允许单条样例起步，后续扩展覆盖率。

## Rule / Risk
- rule_id: `agent-runtime-task6-20260415`
- risk_level: `medium`
- clarification_mode: `direct_fix`

## Changes
- Updated `tests/repo-governance-hub.optimization.tests.ps1`
  - 新增 `agent runtime policy includes concrete prompt tool and memory baselines`：
    - 校验 `prompt_registry.entries >= 1` 且含 `prompt_id/owner/eval_set/rollback_ref/cacheability`
    - 校验 `tool_contracts.entries >= 1` 且含 `tool_name/risk_class/approval_policy/timeout_ms/retry_policy`
    - 校验 `memory_policy.retention_rules` 存在
- Updated `config/agent-runtime-policy.json`
  - 增加 prompt baseline 示例条目
  - 增加 tool contract 示例条目（含 `trace_attrs`）
  - 增加 `memory_policy.retention_rules`
- Updated `docs/change-evidence/template.md`
  - 增加字段：
    - `runtime_policy_mode`
    - `prompt_registry_coverage`
    - `tool_contract_coverage`
    - `memory_policy_coverage`
    - `runtime_eval_freshness_days`

## Commands
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`

## Verification
- 新增测试先失败后通过（失败点：`prompt_registry.entries` 空）。
- 最终结果：
  - `tests`: `Passed: 150 Failed: 0`
  - `validate-config`: PASS

## Terminology
- prompt registry coverage：已登记 prompt 与要求集合的覆盖程度。
- tool contract coverage：已登记工具契约与运行中工具集合的覆盖程度。
- runtime eval freshness：runtime eval 结果距当前时间的时效天数。

## Rollback
- `git restore config/agent-runtime-policy.json tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/template.md`

## learning_points_3
- 用例先失败再补配置可避免“看似有字段但不可用”的假阳性。
- baseline 样例需与 required_fields 同步，避免字段集漂移。
- 证据模板字段前置可减少后续周检补录成本。

## reusable_checklist
- baseline 是否至少一条可执行样例
- required_fields 与 entries 字段名是否一致
- memory policy 是否含 retention 语义
- tests + validate-config 是否同时通过

## open_questions
- 后续是否将 prompt/tool baseline 外置为独立 registry 文件并纳入 drift 检测
