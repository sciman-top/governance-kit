# CLAUDE.md — Generic Repo Baseline (governance-kit template)
**Template Version**: 1.0
**Last Updated**: 2026-04-03

## 1. Reading Guide
- This file is the project-level execution baseline for repositories without a repo-scoped rule set.
- Resolve conflicts by: runtime facts/code > project file > global file > temporary context.
- Keep structure: `1 / A / B / C / D`.

## A. Baseline
### A.1 Objectives
- Reliability first: no crash, no long freeze, external dependency failures must degrade safely.
- Preserve compatibility unless explicitly authorized to break contracts.
- Minimize changes; prioritize root-cause fixes over superficial patches.

### A.2 Execution
- Default behavior: execute continuously to completion.
- Do not pause for routine confirmation; ask only for true blockers, irreversible risk, or repeated self-repair failure.
- Keep every change traceable: rationale -> command -> evidence -> rollback.

### A.3 Engineering Quality
- Coding target: best-practice end state that is testable, maintainable, and observable.
- Prevent overdesign/over-optimization: no speculative abstractions or premature tuning without evidence.
- Preserve gate order semantics: `build -> test -> contract/invariant -> hotspot`.

## B. Platform Notes
- Use non-interactive, scriptable commands.
- Prefer deterministic checks and machine-readable output when available.

## C. Repo Adaptation Contract
### C.1 Landing and Ownership
- Before edits, declare: module boundary -> current landing -> target landing.

### C.2 Gate Commands
- Determine repository-native commands first, then execute in fixed order:
- build
- test
- contract/invariant
- hotspot

### C.3 N/A Policy
- `platform_na`: command unavailable due to platform/runtime limits.
- `gate_na`: gate objectively unavailable (missing script/tooling or doc-only change).
- Required fields: `reason`, `alternative_verification`, `evidence_link`, `expires_at`.

## D. Maintenance Checklist
- Keep this file focused on repo execution semantics, not platform internals.
- Ensure every change has verification evidence and rollback instructions.
- Re-validate gates after significant workflow updates.
