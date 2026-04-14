# Control-Plane Inventory (2026 Q2)

## Scope
- Repo: `E:/CODE/repo-governance-hub`
- Target repos in current distribution scope:
  - `repo-governance-hub`
  - `skills-manager`
  - `ClassroomToolkit`
- Inventory date: `2026-04-14`

## Objective
- Create a single working inventory of active governance controls.
- Distinguish `source-only` controls from `distributable` controls.
- Provide the baseline needed for later `noise reduction`, `tightening`, `promotion`, `downgrade`, and `retirement`.

## Classification Rules
- `class`
  - `hard`: should block on failure because it protects safety, compatibility, rollback, or source-of-truth integrity.
  - `progressive`: high-value but should mature through `observe -> advisory -> enforce`.
  - `advisory`: useful signal, but not blocking by default.
- `repo_scope`
  - `source_only`: only meaningful in this repo as governance source-of-truth.
  - `common_distributable`: intended for rollout to multiple target repos.
  - `repo_specific_distributable`: distributed only to selected repos.
- `inventory_status`
  - `balanced`
  - `too_strict_candidate`
  - `too_loose_candidate`
  - `duplicate_candidate`
  - `stale_candidate`
  - `not_observable_candidate`

## Control Inventory

| control_id | plane | primary artifact | repo_scope | class | mode | inventory_status | notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rule.main_protocol` | rule | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` | `source_only` | `hard` | `enforce` | `balanced` | Main protocol and hard-gate semantics live here; risk is rule bloat rather than weak control. |
| `rule.project_source_mirror` | rule | `source/project/repo-governance-hub/*` | `source_only` | `hard` | `enforce` | `balanced` | Protects source-of-truth mirror for local repo rule distribution. |
| `rule.index_indirection` | rule | `docs/governance/rule-index.md` | `source_only` | `advisory` | `advisory` | `balanced` | Reduces top-level rule verbosity and should continue as non-blocking guidance. |
| `runtime.clarification_upgrade` | runtime_policy | `config/clarification-policy.json` | `common_distributable` | `progressive` | `observe` | `balanced` | Useful for avoiding repeated wrong fixes; should remain policy-driven, not prose-only. |
| `runtime.proactive_suggestion_balance` | runtime_policy | `.governance/proactive-suggestion-policy.json` | `common_distributable` | `progressive` | `advisory` | `balanced` | Prevents over-suggesting and token waste; requires ongoing tuning by issue context. |
| `runtime.subagent_trigger` | runtime_policy | `config/subagent-trigger-policy.json`, `.governance/subagent-trigger-policy.json` | `common_distributable` | `hard` | `enforce` | `balanced` | Parallel work needs guardrails because misuse can corrupt write boundaries. |
| `runtime.agent_runtime_profile` | runtime_policy | `config/agent-runtime-policy.json` | `repo_specific_distributable` | `progressive` | `observe` | `not_observable_candidate` | Runtime profile exists, but adoption and effect signals still need clearer weekly reporting. |
| `gate.hard_chain` | gate | `scripts/verify-kit.ps1`, `tests/repo-governance-hub.optimization.tests.ps1`, `scripts/validate-config.ps1`, `scripts/verify.ps1`, `scripts/doctor.ps1` | `source_only` | `hard` | `enforce` | `balanced` | This is the repo's fixed hard-gate backbone and should not be softened. |
| `gate.fast_check_escalation` | gate | `scripts/governance/fast-check.ps1` | `common_distributable` | `progressive` | `advisory` | `balanced` | Intended to reduce local friction while preserving escalation to full verification. |
| `gate.tracked_files_scope` | gate | `scripts/governance/check-tracked-files.ps1`, `.governance/tracked-files-policy.json` | `common_distributable` | `hard` | `enforce` | `balanced` | Protects commit scope and prevents accidental inclusion of unrelated files. |
| `gate.update_trigger_review` | gate | `scripts/governance/check-update-triggers.ps1`, `config/update-trigger-policy.json` | `source_only` | `progressive` | `observe` | `balanced` | This is the main policy evolution trigger surface; some triggers are intentionally still in observe. |
| `gate.gate_noise_budget` | gate | `config/update-trigger-policy.json` (`gate_noise_budget_breach`) | `source_only` | `progressive` | `observe` | `balanced` | Critical anti-bloat control for preventing governance cost inflation. |
| `gate.control_retirement_backlog` | gate | `scripts/governance/check-control-retirement-candidates.ps1`, `config/control-retirement-candidates.json` | `source_only` | `progressive` | `observe` | `balanced` | Makes retirement backlog measurable and alerts when decision windows expire. |
| `evidence.change_evidence_template` | evidence_metrics | `docs/change-evidence/*`, `docs/change-evidence/template.md` | `common_distributable` | `hard` | `enforce` | `balanced` | Evidence must remain auditable and replay-ready. |
| `metrics.token_efficiency_trend` | evidence_metrics | `docs/governance/token-efficiency-trend-loop.md`, `.governance/token-efficiency-history.jsonl` | `common_distributable` | `progressive` | `observe` | `balanced` | Tracks governance cost quality ratio and should inform downgrade decisions. |
| `metrics.recurring_review_output` | evidence_metrics | `scripts/governance/run-recurring-review.ps1`, `docs/governance/metrics-auto.md` | `source_only` | `hard` | `enforce` | `balanced` | Weekly review is the main observability aggregator for policy tuning. |
| `distribution.custom_file_mapping` | distribution | `config/project-custom-files.json`, `config/targets.json` | `source_only` | `hard` | `enforce` | `balanced` | Distribution mapping must stay exact or rollout drift appears immediately. |
| `distribution.rollout_phase` | distribution | `config/rule-rollout.json` | `source_only` | `progressive` | `observe` | `too_loose_candidate` | Current rollout phase coverage is still sparse relative to the number of active controls. |
| `distribution.install_safe` | distribution | `scripts/install.ps1 -Mode safe` | `source_only` | `hard` | `enforce` | `balanced` | Safe install is the canonical distribution path and rollback boundary. |
| `review.weekly_trigger_loop` | review_evolution | `scripts/governance/run-recurring-review.ps1` | `source_only` | `hard` | `enforce` | `balanced` | Weekly loop already exists and should become the main policy adjustment input. |
| `review.monthly_policy_review` | review_evolution | `scripts/governance/run-monthly-policy-review.ps1` | `source_only` | `progressive` | `observe` | `balanced` | Good anchor for promotion and retirement decisions; needs stronger control-plane framing. |
| `review.noise_budget_baseline` | review_evolution | `docs/governance/governance-noise-budget.md` | `source_only` | `progressive` | `observe` | `balanced` | Establishes per-control friction budget and keeps promotion tied to stable signal quality. |
| `review.cross_repo_compatibility` | review_evolution | `scripts/governance/check-cross-repo-compatibility.ps1` | `repo_specific_distributable` | `hard` | `enforce` | `balanced` | Prevents source-side changes from being redistributed without downstream compatibility confidence. |

## Initial Findings

### Areas already strong
- Hard-gate backbone is explicit and stable.
- Distribution source-of-truth is centralized in config plus install pipeline.
- Evidence, recurring review, and update-trigger mechanisms already exist.

### Likely “too strict” candidates
- None should be declared immediately without metric evidence.
- The most likely candidates will come from repeated suggestion noise, duplicate side checks, or costly observe-only checks that never mature.

### Likely “too loose” candidates
- `distribution.rollout_phase`
  - Current rollout metadata covers fewer control surfaces than the active governance stack now uses.
- `runtime.agent_runtime_profile`
  - Runtime policy exists, but observability of its effect is still weak.

### Likely duplication candidates
- Rule guidance duplicated across `AGENTS/CLAUDE/GEMINI/source mirrors`.
- Some adjunct governance checks may overlap with signals already visible in recurring review.

### Likely “not observable” candidates
- Runtime profile adoption and effect.
- Per-control friction deltas at target-repo level.

## Source-Only vs Distributable Boundary

### Source-only by default
- Rule source-of-truth mirrors
- Hard-gate orchestration
- Distribution mapping and install coordination
- Monthly/weekly source-side tuning scripts

### Common-distributable by default
- Clarification policy
- Proactive suggestion policy
- Subagent trigger policy
- Tracked-files policy
- Evidence and token-efficiency support artifacts

### Repo-specific distributable by default
- Runtime profiles that depend on repo capabilities
- Compatibility checks tied to a subset of repos

## First Follow-up Actions
1. Add machine-readable registry entries for every item in this inventory.
2. Extend recurring review output with per-control noise and staleness summary.
3. Expand rollout metadata beyond current sparse `rule-rollout.json` usage.
4. Start a duplicate-audit against `AGENTS/CLAUDE/GEMINI/source mirrors`.
