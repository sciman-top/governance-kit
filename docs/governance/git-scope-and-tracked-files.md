# Git Scope And Tracked Files Runbook

## Scope
- Complements `C.11 Git 提交与推送边界（“全部”定义）`.

## What “All” Means
- “all” means only:
  - task-related changes
  - version-managed files
  - files allowed by tracked-files policy and `.gitignore`

## Pre-Commit Checks
1. Run tracked-files classifier:
   - `powershell -File scripts/governance/check-tracked-files.ps1 -Scope pending -AsJson`
2. Read `test_file_suggestions`:
   - `suggested_action=ignore`: do not commit
   - `suggested_action=track`: allowed to commit
   - `suggested_action=review_required`: classify before commit
3. Isolate unrelated changes before any `git add -A`.

## Push Boundary
- `push` only sends existing commit history.
- File inclusion decisions must be completed before `git commit`.

## Default Exclusions
- IDE/agent local configs
- temp/log/backup/cache/runtime artifacts
- unrelated untracked files

## Policy Block
- If `.governance/tracked-files-policy.json` enables `block_on_test_file_review_required=true`,
  presence of `review_required` blocks commit/push.
