# Rule Duplication Audit (2026 Q2)

## Scope
- Repo: `E:/CODE/repo-governance-hub`
- Scan date: `2026-04-14`
- Rule scope:
  - `source/global/AGENTS.md`
  - `source/global/CLAUDE.md`
  - `source/global/GEMINI.md`
  - `source/project/**/AGENTS.md`
  - `source/project/**/CLAUDE.md`
  - `source/project/**/GEMINI.md`

## Baseline Command
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-rule-duplication.ps1 -RepoRoot . -AsJson`

## Baseline Result
- `scanned_file_count=12`
- `issue_count=0`
- `status=PASS`

## Detection Logic
- Duplicate heading in same rule doc (`duplicate_heading`)
- Adjacent identical non-empty lines (`duplicate_adjacent_line`)

## Governance Integration
- Trigger policy:
  - `config/update-trigger-policy.json -> triggers.rule_duplication_detected`
- Trigger execution:
  - `scripts/governance/check-update-triggers.ps1`
- Weekly summary and snapshot:
  - `scripts/governance/run-recurring-review.ps1`
  - `docs/governance/alerts-latest.md` (`rule_duplication_count`)

## Follow-up
1. Keep this baseline as reference for Phase 1 de-dup work.
2. If `rule_duplication_count > 0`, deduplicate in source rule files first, then sync to project mirrors.
3. After de-dup, rerun fixed gate order before distribution decisions.

