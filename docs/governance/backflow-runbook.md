# Backflow Runbook

## Scope
- Covers temporary direct edits in target repos and mandatory backflow to source of truth.
- Complements `C.7 目标仓直改回灌策略`.

## Source Of Truth
- `E:/CODE/repo-governance-hub/source/project/repo-governance-hub/*`

## Mandatory Sequence
1. If temporary direct edits happen in target repo root files (`AGENTS/CLAUDE/GEMINI`), backflow on the same day.
2. Sync root changes into source tree.
3. Reinstall from source:
   - `powershell -File E:/CODE/repo-governance-hub/scripts/install.ps1 -Mode safe`
4. Re-run gates:
   - `build -> test -> contract/invariant -> hotspot`
5. Record evidence and rollback entry.

## Hard Constraints
- No second `sync/install` overwrite before `backflow + re-verify` completes.
- If only stopgap patch is applied, evidence must include recovery deadline and final destination.

## Suggested Commands
- Compare root vs source:
  - `powershell -File scripts/verify.ps1`
- Reinstall:
  - `powershell -File scripts/install.ps1 -Mode safe`
