# Evidence And Rollback Runbook

## Scope
- Applies to repo-level governance changes in this repository.
- Complements `C.5 证据与回滚` minimal rules in main rule files.

## Evidence Path And Naming
- Directory: `docs/change-evidence/`
- Recommended filename: `YYYYMMDD-topic.md`

## Minimum Evidence Fields
- rule_id
- risk_level
- target_destination
- task_snapshot (goal / non-goal / acceptance / key assumptions)
- commands
- key_output
- rollback_action
- open_questions

## Rollback Entrypoints
- Primary: `powershell -File scripts/restore.ps1`
- Backup path: `backups/<timestamp>/`
- File-level rollback (when applicable): `git restore <paths>`

## Execution Template
1. Record reason and target destination.
2. Run gates in fixed order:
   - `build -> test -> contract/invariant -> hotspot`
3. Save key outputs and exception notes.
4. Record exact rollback command before finishing.

## Notes
- `platform_na` / `gate_na` must include:
  - reason
  - alternative_verification
  - evidence_link
  - expires_at
