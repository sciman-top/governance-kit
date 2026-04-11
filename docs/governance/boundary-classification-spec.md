# Boundary and Classification Specification

## Purpose

This document defines how to classify every governance target into one of three buckets:

- Global user-level
- Project-level
- Shared template

The goal is to preserve the boundary between global user-level and project-level concerns so that both layers work together without overlap or gaps.

## Non-goals

- Do not use symbolic links as the default distribution mechanism.
- Do not move repo-specific execution logic into user-level files.
- Do not flatten project differences into a single universal rule set.

## Core Principle

The correct classification is based on dependency and responsibility, not on convenience.

- If a file describes how the agent should behave across all repos and does not depend on repo-specific execution, it may be global user-level.
- If a file depends on a specific repo, path, script, workflow, evidence path, or rollback path, it is project-level.
- If a file is reusable across repos but remains an internal source artifact, it is a shared template.

## Definitions

### Global user-level

A global user-level target is a small, stable file that defines universal CLI entry behavior and shared collaboration rules.

It must satisfy all of the following:

- Not depend on any repo path
- Not depend on any repo script
- Not depend on repo-specific evidence or rollback flows
- Not define repo execution behavior
- Remain stable across repositories and target states

### Project-level

A project-level target is a file whose meaning changes with the repository it is installed into.

It must be classified as project-level if it does any of the following:

- References a repo path or repo root
- Defines repo-specific scripts, workflows, policies, or gates
- Controls repo-specific evidence, release, rollback, or validation
- Must vary across repos
- Must execute within a repo context after installation

### Shared template

A shared template is a reusable source artifact that may feed multiple repos, but is not itself the final user-level rule.

It should be kept in the repository source tree and distributed as needed.

It must not be elevated to global user-level unless it independently satisfies the global criteria.

## Decision Rule

Use the following priority order:

1. If it depends on a repo context, classify it as project-level.
2. Else if it only defines cross-repo collaboration behavior, classify it as global user-level.
3. Else if it is reusable but still a source artifact, classify it as a shared template.

If a candidate file matches multiple buckets, choose the most specific bucket:

- Repo dependence beats generic collaboration
- Execution beats explanation
- Project-specific behavior beats global wording

## Decision Tree

Ask these questions in order:

1. Does the target reference any repo path, repo script, repo workflow, repo evidence, or repo rollback flow?
   - Yes: project-level
   - No: continue
2. Does the target define only universal collaboration rules or CLI entry behavior?
   - Yes: global user-level
   - No: continue
3. Is the target a reusable internal source artifact rather than a final installation target?
   - Yes: shared template
   - No: project-level by default

## Typical Classifications

### Global user-level candidates

These are the kinds of files that may be global user-level when they are repo-agnostic and stable:

- CLI entry protocol files
- Universal collaboration rule files
- Cross-repo behavior constraints
- Shared response and task-framing templates, when they do not contain repo-specific logic

### Project-level candidates

These must remain project-level when installed into a target repo:

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` for a specific repo
- `scripts/*`
- `.github/workflows/*`
- `.governance/*`
- `docs/runbooks/*`
- repo-specific plugins, skills, overrides, and policy files

### Shared template candidates

These should stay as shared templates in the source tree:

- Evidence templates
- Metrics templates
- Release templates
- Task snapshot templates
- Policy mother files that are later specialized per repo

## Boundary Tests

Before promoting a file to global user-level, confirm all of the following:

- It still works if every repo path is removed
- It still works if every repo script is removed
- It still makes sense if no repo-specific evidence exists
- It still makes sense if no repo rollback path exists
- It does not need different values in different repos

If any answer is no, keep it out of global user-level.

Before keeping a file project-level, confirm at least one of the following:

- It must execute inside a specific repo
- It must be versioned with repo changes
- It must be validated against repo-specific gates
- It must preserve repo-specific evidence or rollback behavior

If none of these are true, it may belong in global user-level or in a shared template bucket.

## Enforcement Requirements

The repository must enforce the boundary at multiple points.

The current enforcement chain is:

- `scripts/install.ps1`
- `scripts/validate-config.ps1`
- `scripts/verify.ps1`

### 1. Source layout

- Global source files belong under `source/global/`.
- Repo source files belong under `source/project/<RepoName>/`.
- Reusable but non-global source files belong under `source/project/_common/`.

### 2. Distribution mapping

- `config/targets.json` is the authoritative distribution map.
- `config/project-rule-policy.json` constrains project-rule placement and behavior.
- Each target entry should declare `boundary_class` with one of:
  - `global-user`
  - `project`
  - `shared-template`
- `project-rule-policy.defaults.enforce_boundary_class=true` enables strict blocking on missing or mismatched `boundary_class`.
- Distribution must never be done by hand outside the mapping tables.

### 3. Install-time checks

Before install or sync:

- Verify that user-level targets are limited to the allowed small set.
- Verify that project-level targets are sourced from the correct repo source tree.
- Reject ambiguous targets unless they are explicitly classified.

### 4. Post-install checks

After install or sync:

- Verify that the user-level files are present only in the allowed CLI locations.
- Verify that repo-specific files exist only under the target repo root.
- Verify that no file has crossed layers in a way that changes its responsibility.

## New Target Repo Onboarding

Every new target repo must start with the boundary model already in place.

The onboarding sequence must ensure:

1. Global user-level entry files are installed first.
2. Repo-level AGENTS/CLAUDE/GEMINI files are installed next.
3. Repo-specific scripts, workflows, and governance policies are installed after that.
4. The repo passes boundary validation before being considered ready.

This prevents a new repo from beginning life with mixed responsibilities.

## Reclassification Checklist

Use this checklist whenever a file is added, removed, or optimized:

- Does it depend on repo-specific paths?
- Does it depend on repo-specific scripts or workflows?
- Does it define execution rather than policy?
- Does it need to change independently in different repos?
- Can it still stand alone if removed from all repo contexts?

Classification outcome:

- `yes` to any repo-specific dependency: project-level
- `yes` only to repo-agnostic collaboration behavior: global user-level
- `yes` only to reuse without direct installation: shared template

## Recommended Default Policy

- Keep global user-level targets minimal.
- Keep project-level targets comprehensive for repo execution.
- Keep shared templates as source artifacts, not user-level installs.
- Prefer copy-based distribution over symlink-based sharing.

## Current Repository Interpretation

For this repository, the current user-level targets are intentionally small and limited to the three CLI entry files:

- `C:/Users/sciman/.codex/AGENTS.md`
- `C:/Users/sciman/.claude/CLAUDE.md`
- `C:/Users/sciman/.gemini/GEMINI.md`

The rest of the installed targets should remain repo-level or shared-template artifacts as defined by the distribution map.

## Summary

The correct test is not "can this be shared?" but "does sharing it change its responsibility?"

If sharing a file would blur responsibility between global user-level and project-level behavior, keep it project-level or keep it as a shared template in the source tree.
