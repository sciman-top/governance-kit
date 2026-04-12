# Auto Rollback Drill (P1-04)

## Goal
- Verify rollback path continuously with measurable recovery time.

## Drill Entry
- `powershell -File scripts/governance/run-rollback-drill.ps1 -RepoRoot . -Mode safe -AsJson`

## What It Validates
- Temporary kit sandbox can execute `scripts/restore.ps1` successfully.
- Target file content is restored from snapshot.
- Recovery time is emitted as `recovery_ms`.

## Weekly Fields
- `rollback_drill_status`
- `rollback_drill_recovery_ms`

## Rollback
- Revert `run-rollback-drill` integration if drill logic regresses.
