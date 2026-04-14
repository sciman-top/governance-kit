# Skill Creation Gate Checklist (skills-manager overrides path)

## Canonical Path
- New skill source of truth must be created under:
  - `source/project/repo-governance-hub/custom/overrides/<skill-name>/SKILL.md`
- Do not treat repository-root `.agents/skills/*` as canonical creation path in this repo.

## Hard Gates for `create` Action
- Policy source: `.governance/skill-promotion-policy.json`, `.governance/skill-lifecycle-policy.json`
- Required conditions:
  1. `require_user_ack=true` and explicit ack provided (`SKILL_PROMOTION_ACK=YES`).
  2. `require_trigger_eval_for_create=true` and trigger eval summary passes thresholds.
  3. New skill family must be unique (no duplicate family in registry/overrides).
  4. `create_min_unique_repos` satisfied (current default: `>=2` repos).
  5. If policy blocks missing eval/adversarial metrics, missing data blocks creation.

## Trigger Eval Thresholds (current defaults)
- validation pass rate >= `0.7`
- validation false-trigger rate <= `0.2`
- adversarial validation thresholds follow policy fields when enabled:
  - pass rate >= `0.6`
  - false-trigger rate <= `0.35`

## Recommended Execution Flow
1. Register/refresh trigger-eval runs.
2. Run `check-skill-trigger-evals.ps1 -AsJson`.
3. Run `promote-skill-candidates.ps1 -AsJson` and confirm create is not blocked.
4. If create blocked by ack/eval/family gate, do not force-create; fix gate input first.
5. After creation, run governance gates and record evidence.

## Evidence Fields
- `issue_id`
- `policy_path`
- `trigger_eval_summary_path`
- `trigger_eval_summary_status`
- `trigger_eval_pass`
- `blocked_create_count`
- `reason_codes`
- `user_ack_env_var`
- `user_ack_received_value`
