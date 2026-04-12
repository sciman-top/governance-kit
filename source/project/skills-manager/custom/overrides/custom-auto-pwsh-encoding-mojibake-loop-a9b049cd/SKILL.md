---
name: custom-auto-pwsh-encoding-mojibake-loop-a9b049cd
description: Incident bridge for UTF-8/PowerShell mojibake loop; delegates to custom-windows-encoding-guard and adds powershell->pwsh session wrapper.
---

1. Run `scripts/bootstrap.ps1 -AsJson` at session start in Windows terminals.
2. This bootstrap first executes `custom-windows-encoding-guard/scripts/bootstrap.ps1` to enforce UTF-8 (`OutputEncoding/InputEncoding/ConsoleEncoding/*:Encoding`).
3. Then it installs a session wrapper (`function powershell { & pwsh @Args }`) to reduce accidental Windows PowerShell 5.1 invocation.
4. Use this skill as compatibility bridge for historical signature variants of `pwsh-encoding-mojibake-loop-*`; do not create duplicate UTF-8 guard skills.

source_repos: E:/CODE/skills-manager
signature_variants: pwsh-encoding-mojibake-loop-20260411-a, pwsh-encoding-mojibake-loop-20260411-b, pwsh-encoding-mojibake-loop-20260411-c, pwsh-encoding-mojibake-loop-20260411-d
canonical_guard_skill: custom-windows-encoding-guard
