# JSON Contract Schema v1.0

## Scope
- `scripts/status.ps1 -AsJson`
- `scripts/rollout-status.ps1 -AsJson`
- `scripts/doctor.ps1 -AsJson`

## Compatibility Policy
- Required field: `schema_version`.
- Current version: `1.0`.
- Backward compatibility rule:
  - Adding optional fields is allowed in `1.x`.
  - Renaming/removing required fields requires major bump (`2.0`).
  - Consumers must reject unknown major versions.

## status.ps1
- Required fields:
  - `schema_version` (string)
  - `repositories` (number)
  - `targets` (number)
  - `repos` (array)
  - `global_home_targets` (number)
  - `missing_repositories` (number)
  - `orphan_targets` (number)
  - `rollout` (object or null)
  - `warnings` (array)

## rollout-status.ps1
- Required fields:
  - `schema_version` (string)
  - `default_phase` (string)
  - `default_block_expired_waiver` (boolean)
  - `observe` (number)
  - `enforce` (number)
  - `observe_overdue` (number)
  - `repos` (array)
  - `warnings` (array)

## doctor.ps1
- Required fields:
  - `schema_version` (string)
  - `generated_at` (string, `yyyy-MM-dd HH:mm:ss`)
  - `health` (string: `GREEN` or `RED`)
  - `failed_steps` (array)
  - `skipped_steps` (array)
  - `steps` (array)

## Validation
- Local validation command:
```powershell
powershell -File E:\CODE\governance-kit\scripts\verify-json-contract.ps1
```
