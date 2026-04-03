# Agent Remediation Contract

## Purpose
- Define the handoff contract between governance scripts and the outer AI session agent.
- Keep scripts as gate orchestrators only.
- Keep remediation in the current AI conversation session, not inside script-level model CLI calls.

## Mandatory Rule
- Do not call `codex exec`, `claude ...`, `gemini ...`, or any model CLI from governance scripts for automatic remediation.
- When a gate step fails, scripts must output structured failure context and exit non-zero.
- The outer AI session agent reads failure context, applies minimal safe fix, and reruns the required command.

## Failure Context JSON
- Marker prefix: `[FAILURE_CONTEXT_JSON]`
- Required fields:
- `failed_step`
- `command`
- `exit_code`
- `log_path`
- `repo_path`
- `gate_order`
- `retry_command`
- `policy_snapshot`
- `remediation_owner`
- `timestamp`

## Execution Semantics
- Fixed gate order remains: `build -> test -> contract/invariant -> hotspot`.
- Script output is evidence, not autonomous decision to patch code via nested model CLI.
- Outer AI session agent must preserve contract compatibility and avoid weakening validation checks.

## Evidence Requirements
- Record in evidence doc:
- `basis`
- `commands`
- `key_output`
- `rollback_action`
- `failure_context_json` snapshot

## Contract Check Command
- Validate contract fields before outer-AI remediation:
- `powershell -File scripts/validate-failure-context.ps1 -LogPath <log-file-path>`
