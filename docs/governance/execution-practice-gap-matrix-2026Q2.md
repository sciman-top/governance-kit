# Execution Practice Gap Matrix (2026 Q2)

## Scope
- repo: `E:/CODE/repo-governance-hub`
- target repos: `ClassroomToolkit`, `skills-manager`, `repo-governance-hub`
- baseline date: `2026-04-13`

## Core Set
| practice | primary artifact | owner | mode | status | rollout entry criteria |
| --- | --- | --- | --- | --- | --- |
| sdd | `docs/PLANS.md`, evidence template | repo-governance-hub | enforce | done | spec template available + evidence template aligned |
| tdd | `tests/repo-governance-hub.optimization.tests.ps1` | repo-governance-hub | enforce | done | stable test profile + fail-fast regression guard |
| contract_testing | `scripts/validate-config.ps1`, `scripts/verify.ps1` | repo-governance-hub | enforce | done | contract/invariant gate scripts pass in fixed order |
| harness_engineering | `scripts/doctor.ps1`, `scripts/verify-kit.ps1` | repo-governance-hub | enforce | done | doctor + verify chain stable in three repos |
| policy_as_code | `.governance/*.json` + verify checks | repo-governance-hub | enforce | done | policy json validated + mapped to verify/doctor |
| observability | `run-recurring-review.ps1`, `metrics-auto.md` | repo-governance-hub | enforce | done | recurring review metrics populated and auditable |
| hooks_ci_gates | `hooks/*`, `.github/workflows/quality-gates.yml` | repo-governance-hub | enforce | done | pre-commit/pre-push + CI quality gates active |
| ssdf | `docs/governance/ssdf-mapping.md` | repo-governance-hub | enforce | done | ssdf mapping and external baseline checks pass |
| slsa | `.github/workflows/slsa.yml` | repo-governance-hub | observe | in_progress | provenance attestation pipeline verified in at least one repo |
| sbom | `.github/workflows/sbom.yml`, `run-supply-chain-checks.ps1` | repo-governance-hub | enforce | done | sbom workflow and supply-chain checks present |
| scorecard | `.github/workflows/scorecard.yml` | repo-governance-hub | enforce | done | scorecard workflow active and recurring review stable |

## Extended Set
| practice | primary artifact | owner | mode | status | rollout entry criteria |
| --- | --- | --- | --- | --- | --- |
| atdd_bdd | acceptance scenario docs/tests | repo-governance-hub | observe | planned | domain acceptance scenario catalog prepared |
| progressive_delivery | `config/rule-rollout.json`, promotion checks | repo-governance-hub | observe | in_progress | rollout observe window meets promotion policy |
| repository_rulesets | `.github/rulesets/default.json`, ruleset checks | repo-governance-hub | observe | done | ruleset policy/config/template validated without drift |

## Security Baseline Additions (P0 closeout)
| control | artifact | status |
| --- | --- | --- |
| code scanning | `.github/workflows/codeql.yml` | done |
| dependency review | `.github/workflows/dependency-review.yml` | done |
| code ownership | `.github/CODEOWNERS` | done |

## Phase Mapping
- Phase 0: matrix + rollout metadata completed in this document and `practice-stack-policy.json` metadata fields.
- Phase 1: high-value security baseline fill completed and distributed.
- Phase 2: completed for executable controls (SLO/error budget + gate latency delta reporting + gate noise budget trigger + dependency-review enforce drift check + SLSA provenance pipeline and placeholder guard all landed). Residual work is trend observation, not capability gap.

## Remaining Gaps (next auto iteration)
1. Verify two-cycle stability for the new gate noise budget trigger, then decide threshold tightening.
2. Verify two-cycle stability for dependency-review enforce drift alerts before tightening threshold/policy.
3. Verify SLSA provenance workflow signal quality in recurring review snapshots for two cycles.
