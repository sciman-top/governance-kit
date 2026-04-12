# Skill Family Health Policy (P2-01)

## Goal
- Reduce duplicate skill families in active/approved states.
- Keep active skill health score above baseline.

## Policy
- `.governance/skill-family-health-policy.json`
- target states: `active`, `approved`
- max active family duplicates: `0`
- min health score for target states: `0.7`

## Gate
- `scripts/governance/check-skill-family-health.ps1`
- integrated into `scripts/verify.ps1`

## Weekly Fields
- `skill_family_health_status`
- `skill_family_active_family_duplicate_count`
- `skill_family_low_health_target_state_count`
- `skill_family_active_family_avg_health_score`
