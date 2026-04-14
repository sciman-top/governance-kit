# Agent Runtime Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a thin-core agent runtime governance baseline to `repo-governance-hub` without changing the existing hard-gate order or creating a second governance plane.

**Architecture:** Introduce one new runtime policy entrypoint in `config/`, then extend existing validation, doctor, recurring review, and tests to read it. Keep all new runtime controls in `observe` first; only static low-noise checks can later move to `enforce`.

**Tech Stack:** PowerShell scripts, JSON policy files, markdown governance docs, existing verify/doctor/test chain.

---

## File Structure
- Create: `config/agent-runtime-policy.json`
- Create: `scripts/governance/check-agent-runtime-baseline.ps1`
- Update: `scripts/verify-kit.ps1`
- Update: `scripts/validate-config.ps1`
- Update: `scripts/governance/run-recurring-review.ps1`
- Update: `scripts/doctor.ps1`
- Update: `tests/repo-governance-hub.optimization.tests.ps1`
- Update: `docs/governance/metrics-template.md`
- Update: `docs/change-evidence/YYYYMMDD-topic.md`

## Checkpoint 0: Planning Complete
- [ ] Scope does not overlap ambiguously with `practice-stack` or `ai-self-evolution`
- [ ] Runtime terms are stable: `prompt_registry`, `tool_contracts`, `context_management`, `memory_policy`, `agent_evals`, `agent_observability`, `cost_controls`, `observe_to_enforce`

### Task 1: Add Runtime Policy Skeleton

**Files:**
- Create: `config/agent-runtime-policy.json`
- Test: `tests/repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Write the failing config-validation test**

Add a test case that loads `config/agent-runtime-policy.json` and asserts the required top-level keys exist:

```powershell
$requiredKeys = @(
  'prompt_registry',
  'tool_contracts',
  'context_management',
  'memory_policy',
  'agent_evals',
  'agent_observability',
  'cost_controls',
  'observe_to_enforce'
)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: FAIL because `config/agent-runtime-policy.json` does not exist yet.

- [ ] **Step 3: Write minimal runtime policy file**

Create `config/agent-runtime-policy.json` with:
- `schema_version`
- `last_updated`
- `mode`
- the required eight top-level sections
- default `observe` mode for all new controls

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: PASS for the new policy presence test.

- [ ] **Step 5: Commit**

```bash
git add config/agent-runtime-policy.json tests/repo-governance-hub.optimization.tests.ps1
git commit -m "feat: add agent runtime policy skeleton"
```

### Task 2: Wire Runtime Policy into Config Validation

**Files:**
- Modify: `scripts/validate-config.ps1`
- Test: `tests/repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Write the failing validation test**

Add a test that feeds malformed runtime policy data and expects validation to fail on missing required sections.

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: FAIL because validation does not inspect runtime policy yet.

- [ ] **Step 3: Extend `scripts/validate-config.ps1`**

Implement minimal checks:
- runtime policy file exists
- JSON parses
- required top-level keys are present
- `mode` values are within `observe|enforce|advisory`

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: PASS, and malformed runtime policy is rejected deterministically.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-config.ps1 tests/repo-governance-hub.optimization.tests.ps1
git commit -m "feat: validate agent runtime policy"
```

### Task 3: Add Runtime Baseline Checker

**Files:**
- Create: `scripts/governance/check-agent-runtime-baseline.ps1`
- Modify: `scripts/verify-kit.ps1`
- Test: `tests/repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Write the failing checker test**

Add a test expecting a runtime checker result object with:

```powershell
@{
  status = 'PASS' # or 'WARN'
  checks = @()
  policy_path = 'config/agent-runtime-policy.json'
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: FAIL because the checker script does not exist.

- [ ] **Step 3: Implement the checker**

The script should:
- read `config/agent-runtime-policy.json`
- verify presence of runtime docs and metrics keys
- return advisory status in Q2 initial phase

- [ ] **Step 4: Call checker from `verify-kit.ps1`**

Add the checker as a non-blocking advisory step during initial rollout.

- [ ] **Step 5: Run verification**

Run:
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/verify-kit.ps1`

Expected: tests pass, verify-kit prints runtime advisory output without changing hard-gate order.

- [ ] **Step 6: Commit**

```bash
git add scripts/governance/check-agent-runtime-baseline.ps1 scripts/verify-kit.ps1 tests/repo-governance-hub.optimization.tests.ps1
git commit -m "feat: add agent runtime baseline checker"
```

## Checkpoint 1: Policy and Checker Online
- [ ] Runtime policy validates
- [ ] Verify-kit surfaces runtime advisory signal
- [ ] No hard-gate order change

### Task 4: Extend Metrics Template and Recurring Review

**Files:**
- Modify: `docs/governance/metrics-template.md`
- Modify: `scripts/governance/run-recurring-review.ps1`
- Test: `tests/repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Write the failing recurring-review test**

Add assertions for runtime keys:

```powershell
$runtimeKeys = @(
  'agent_task_success_rate',
  'runtime_eval_pass_rate',
  'cache_hit_rate',
  'cost_per_successful_run',
  'tool_error_rate',
  'compaction_count'
)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: FAIL because recurring review output does not include these keys yet.

- [ ] **Step 3: Update metrics template**

Add runtime KPI placeholders and short field descriptions to `docs/governance/metrics-template.md`.

- [ ] **Step 4: Update recurring review**

Extend `scripts/governance/run-recurring-review.ps1` to emit a runtime section, even when some values are `advisory` or empty.

- [ ] **Step 5: Run verification**

Run:
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/governance/run-recurring-review.ps1 -RepoRoot . -AsJson`

Expected: runtime section exists and key names are stable.

- [ ] **Step 6: Commit**

```bash
git add docs/governance/metrics-template.md scripts/governance/run-recurring-review.ps1 tests/repo-governance-hub.optimization.tests.ps1
git commit -m "feat: add agent runtime recurring review metrics"
```

### Task 5: Add Doctor Runtime Summary

**Files:**
- Modify: `scripts/doctor.ps1`
- Test: `tests/repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Write the failing doctor-output test**

Add a test expecting doctor JSON to contain:

```powershell
@{
  runtime_readiness = @{
    status = 'GREEN' # or 'YELLOW'
    policy_present = $true
    metrics_present = $true
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: FAIL because doctor does not yet export runtime readiness.

- [ ] **Step 3: Extend doctor**

Add a runtime summary that:
- reads the runtime checker output
- maps advisory health to `GREEN/YELLOW`
- does not block otherwise healthy repos in initial observe phase

- [ ] **Step 4: Run verification**

Run:
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/doctor.ps1`

Expected: runtime readiness appears in doctor output.

- [ ] **Step 5: Commit**

```bash
git add scripts/doctor.ps1 tests/repo-governance-hub.optimization.tests.ps1
git commit -m "feat: add agent runtime doctor summary"
```

## Checkpoint 2: Runtime Signals Visible
- [ ] Recurring review exports runtime KPI keys
- [ ] Doctor shows runtime readiness
- [ ] All existing hard gates still pass

### Task 6: Add Prompt, Tool, and Memory Baselines

**Files:**
- Modify: `config/agent-runtime-policy.json`
- Modify: `tests/repo-governance-hub.optimization.tests.ps1`
- Modify: `docs/change-evidence/YYYYMMDD-topic.md`

- [ ] **Step 1: Write failing tests for three baseline sections**

Add assertions for:
- prompt fields: `prompt_id`, `owner`, `eval_set`, `rollback_ref`, `cacheability`
- tool fields: `tool_name`, `risk_class`, `approval_policy`, `timeout_ms`, `retry_policy`
- memory fields: `session_memory`, `durable_memory`, `forbidden_memory_classes`, `retention_rules`

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
Expected: FAIL because section schemas are placeholders.

- [ ] **Step 3: Expand runtime policy**

Add one concrete sample entry per baseline slice while keeping global mode as `observe`.

- [ ] **Step 4: Update evidence template/example**

Ensure change evidence can record:
- `runtime_policy_mode`
- `prompt_registry_coverage`
- `tool_contract_coverage`
- `memory_policy_coverage`
- `runtime_eval_freshness_days`

- [ ] **Step 5: Run verification**

Run:
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`

Expected: schema and example fields are stable.

- [ ] **Step 6: Commit**

```bash
git add config/agent-runtime-policy.json tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/*.md
git commit -m "feat: add prompt tool memory runtime policy baselines"
```

### Task 7: Pilot Observe Cycle and Promotion Criteria

**Files:**
- Modify: `docs/governance/agent-runtime-roadmap-2026Q2-Q3.md`
- Modify: `docs/governance/agent-runtime-backlog-2026Q2.md`
- Modify: `docs/change-evidence/YYYYMMDD-topic.md`

- [ ] **Step 1: Define pilot success thresholds**

Document:
- `false_positive_rate`
- `gate_latency_delta_ms`
- `policy_drift_count`
- `runtime_eval_pass_rate`

- [ ] **Step 2: Run three pilot cycles**

Run:
- `powershell -File scripts/verify-kit.ps1`
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1`
- `powershell -File scripts/validate-config.ps1`
- `powershell -File scripts/verify.ps1`
- `powershell -File scripts/doctor.ps1`

Expected: three successful observe-mode runs with evidence captured.

- [ ] **Step 3: Decide promotion candidates**

Promote only static, low-noise checks:
- policy file existence
- required runtime metrics fields
- required registry keys

- [ ] **Step 4: Commit**

```bash
git add docs/governance/agent-runtime-roadmap-2026Q2-Q3.md docs/governance/agent-runtime-backlog-2026Q2.md docs/change-evidence/*.md
git commit -m "docs: record agent runtime pilot thresholds"
```

## Checkpoint 3: Ready for Controlled Execution
- [ ] Runtime baseline exists in config, scripts, tests, and docs
- [ ] Observe-mode pilot thresholds are explicit
- [ ] Rollback path remains unchanged

## Risks and Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Runtime policy duplicates existing canonical rules | High | Merge semantics into one canonical config source |
| New runtime metrics cause noisy reports | Medium | Keep advisory-only until three stable cycles |
| Memory policy is over-scoped | High | Restrict Q2 to boundary and audit rules |
| Prompt/tool registry becomes stale | Medium | Require tests and recurring review coverage |

## Open Questions
- Should prompt registry be a nested section under `agent-runtime-policy.json` or a separate dedicated file?
- Should runtime cost metrics stay repo-local in Q2 or be promoted into cross-repo recurring review immediately?
