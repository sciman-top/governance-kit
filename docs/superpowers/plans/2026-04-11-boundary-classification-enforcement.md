# Boundary Classification Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce a stable boundary model that classifies governance targets as global user-level, project-level, or shared template, and blocks distribution drift during install and validation.

**Architecture:** Add boundary classification helpers in the shared PowerShell library, define a small policy surface for allowed global user-level targets, and wire validation into install and verification paths. Keep the implementation path-based and conservative so it can fail closed when a target is ambiguous.

**Tech Stack:** PowerShell, JSON config, existing governance install/verify scripts, lightweight integration tests.

---

### Task 1: Add shared boundary classification helpers

**Files:**
- Modify: `scripts/lib/common.ps1`

- [ ] **Step 1: Add boundary helper functions**

```powershell
function Get-BoundaryTargetClassification {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target
  )

  $src = ([string]$Source -replace '\\', '/')
  $dst = ([string]$Target -replace '\\', '/')

  if ($dst -match '^C:/Users/[^/]+/\.(codex|claude|gemini)/') {
    return 'global-user'
  }

  if ($src.StartsWith('source/global/', [System.StringComparison]::OrdinalIgnoreCase)) {
    return 'global-user'
  }

  if ($src.StartsWith('source/project/', [System.StringComparison]::OrdinalIgnoreCase)) {
    return 'project'
  }

  return 'shared-template'
}

function Test-AllowedGlobalUserTarget {
  param([Parameter(Mandatory = $true)][string]$Target)

  $dst = ([string]$Target -replace '\\', '/')
  return ($dst -match '^C:/Users/[^/]+/\.(codex|claude|gemini)/(AGENTS|CLAUDE|GEMINI)\.md$')
}
```

- [ ] **Step 2: Keep the helper conservative**

```powershell
function Get-BoundaryTargetClassification {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target
  )

  $src = ([string]$Source -replace '\\', '/')
  $dst = ([string]$Target -replace '\\', '/')

  if ($dst -match '^C:/Users/[^/]+/\.(codex|claude|gemini)/') {
    return 'global-user'
  }

  if ($src.StartsWith('source/global/', [System.StringComparison]::OrdinalIgnoreCase)) {
    return 'global-user'
  }

  if ($src.StartsWith('source/project/', [System.StringComparison]::OrdinalIgnoreCase)) {
    return 'project'
  }

  return 'shared-template'
}
```

- [ ] **Step 3: Run a syntax-only check**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -SkipConfigValidation`
Expected: no parser errors in `scripts/lib/common.ps1`.

### Task 2: Enforce global-user target whitelist during validation

**Files:**
- Modify: `scripts/validate-config.ps1`

- [ ] **Step 1: Validate that only approved user-level targets exist**

```powershell
foreach ($item in $targets) {
  if ($null -eq $item -or [string]::IsNullOrWhiteSpace([string]$item.source) -or [string]::IsNullOrWhiteSpace([string]$item.target)) {
    Write-Host "[CFG] invalid entry (missing source/target)"
    $cfgFail++
    continue
  }

  $classification = Get-BoundaryTargetClassification -Source ([string]$item.source) -Target ([string]$item.target)
  if ($classification -eq 'global-user' -and -not (Test-AllowedGlobalUserTarget -Target ([string]$item.target))) {
    Write-Host "[CFG] disallowed global-user target: $($item.source) -> $($item.target)"
    $cfgFail++
  }
}
```

- [ ] **Step 2: Make ambiguous targets fail closed**

```powershell
if ($classification -eq 'shared-template') {
  Write-Host "[CFG] ambiguous target classification requires explicit source placement: $($item.source) -> $($item.target)"
  $cfgFail++
}
```

- [ ] **Step 3: Run the config validator**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-config.ps1`
Expected: pass with the current target map.

### Task 3: Enforce boundary checks during install and verify

**Files:**
- Modify: `scripts/install.ps1`
- Modify: `scripts/verify.ps1`

- [ ] **Step 1: Block non-whitelisted user-level targets before copy**

```powershell
foreach ($item in $targets) {
  $classification = Get-BoundaryTargetClassification -Source ([string]$item.source) -Target ([string]$item.target)
  if ($classification -eq 'global-user' -and -not (Test-AllowedGlobalUserTarget -Target ([string]$item.target))) {
    throw "Disallowed global-user target: $($item.source) -> $($item.target)"
  }
}
```

- [ ] **Step 2: Ensure verify fails on boundary drift**

```powershell
if ($classification -eq 'global-user' -and -not (Test-AllowedGlobalUserTarget -Target $item.target)) {
  Write-Host "[BOUNDARY] invalid global-user target: $($item.source) -> $dst"
  $fail++
}
```

- [ ] **Step 3: Keep post-install verification unchanged for content equality**

```powershell
if (Test-FileContentEqual -PathA $src -PathB $dst) {
  Write-Host "[OK]   $($item.source) == $dst"
  $ok++
} else {
  Write-Host "[DIFF] $($item.source) != $dst"
  $fail++
}
```

- [ ] **Step 4: Run install and verify against the current workspace**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install.ps1 -Mode plan -ShowScope`
Expected: boundary checks pass and the scope remains unchanged.

### Task 4: Add focused regression coverage

**Files:**
- Modify: `tests\repo-governance-hub.optimization.tests.ps1`

- [ ] **Step 1: Add a test for allowed global-user targets**

```powershell
it "allows only the three CLI global user targets" {
  $allowed = @(
    "C:/Users/sciman/.codex/AGENTS.md",
    "C:/Users/sciman/.claude/CLAUDE.md",
    "C:/Users/sciman/.gemini/GEMINI.md"
  )

  foreach ($target in $allowed) {
    (Test-AllowedGlobalUserTarget -Target $target) | should be $true
  }
}
```

- [ ] **Step 2: Add a test for rejecting an unexpected user-level file**

```powershell
it "rejects unexpected user-level files" {
  (Test-AllowedGlobalUserTarget -Target "C:/Users/sciman/.codex/README.md") | should be $false
}
```

- [ ] **Step 3: Run the focused test file**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\repo-governance-hub.optimization.tests.ps1`
Expected: pass.

### Task 5: Document the boundary policy

**Files:**
- Modify: `docs/governance/boundary-classification-spec.md`

- [ ] **Step 1: Add a short enforcement note**

```markdown
This policy is enforced by `scripts/validate-config.ps1`, `scripts/install.ps1`, and `scripts/verify.ps1`.
```

- [ ] **Step 2: Keep the doc aligned with the scripts**

```markdown
The only allowed global user-level install targets are:

- `C:/Users/sciman/.codex/AGENTS.md`
- `C:/Users/sciman/.claude/CLAUDE.md`
- `C:/Users/sciman/.gemini/GEMINI.md`
```

- [ ] **Step 3: Re-run the boundary validation chain**

Run:
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-config.ps1`
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1`
Expected: both pass.


