# Rule Index (Scenario Entry)

## Purpose
- Provide short navigation from main rule files to detailed runbooks.
- Keep main rule files focused on always-needed protocol.

## Scenario -> Entry Docs
- `plan / implementation`: `AGENTS|CLAUDE|GEMINI -> A.2, C.1-C.4`
- `verification / release checks`: [verification-entrypoints.md](./verification-entrypoints.md)
- `global-repo mapping and承接`: [global-repo-mapping.md](./global-repo-mapping.md)
- `repo-governance-hub x skills-manager 协作边界`: [collaboration-contract-repo-skills-manager.md](./collaboration-contract-repo-skills-manager.md)
- `standalone 发布与外部依赖边界`: [standalone-release-dependency-contract.md](./standalone-release-dependency-contract.md)
- `evidence and rollback details`: [evidence-and-rollback-runbook.md](./evidence-and-rollback-runbook.md)
- `backflow and source-of-truth`: [backflow-runbook.md](./backflow-runbook.md)
- `tracked files and commit scope`: [git-scope-and-tracked-files.md](./git-scope-and-tracked-files.md)
- `token 降本轻量执行清单`: [token-cost-lightweight-checklist.md](./token-cost-lightweight-checklist.md)
- `rule duplication audit`: [rule-duplication-audit-2026Q2.md](./rule-duplication-audit-2026Q2.md)
- `governance noise budget`: [governance-noise-budget.md](./governance-noise-budget.md)
- `control retirement candidates`: [control-retirement-candidates-2026Q2.md](./control-retirement-candidates-2026Q2.md)
- `teaching output protocol`: skill `governance-teaching-lite-output`
- `clarification protocol`: skill `governance-clarification-protocol`
- `skill creation gate`: [skill-creation-gate-checklist.md](./skill-creation-gate-checklist.md)

## Minimal Rule Body Policy
- Main rule files keep:
  - Decision chain and hard gate sequence.
  - Block conditions and N/A semantics.
  - Source-of-truth and rollback entrance.
- Long examples, templates, and operation details move to docs/skills.
