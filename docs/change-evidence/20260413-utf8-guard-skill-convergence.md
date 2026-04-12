# 2026-04-13 UTF-8 Guard Skill Convergence

## goal
- 将 `pwsh-encoding-mojibake-loop` 相关 auto 技能并回 canonical 技能 `custom-windows-encoding-guard`。
- 消除对 `custom-auto-pwsh-encoding-mojibake-*-a9b049cd` 的运行时依赖与文档引用。

## root_cause
- 同一问题族存在“canonical guard + incident auto skill”双轨，造成命名困惑与维护分叉。
- 对该问题族而言，长期保留 hash 命名的 auto 技能不再带来额外价值。

## changes
- 删除 source 与目标仓中的 bridge 技能目录：
  - `source/project/skills-manager/custom/overrides/custom-auto-pwsh-encoding-mojibake-loop-a9b049cd/*`
  - `E:/CODE/skills-manager/overrides/custom-auto-pwsh-encoding-mojibake-loop-a9b049cd/*`
- 将运行手册中的技能名统一为 `custom-windows-encoding-guard`。
- 将 `skills-manager` 的 `promotion-registry` 对应条目 `skill_name` 指向 `custom-windows-encoding-guard`。
- 项目级协作契约与 AGENTS 条款更新为“默认并回 canonical，禁止平行防乱码技能”。
- 更新 `project-custom-files` 与 `targets` 映射，移除已删除技能分发项。

## verification
- `powershell -File scripts/verify-kit.ps1` -> pass
- `powershell -File tests/repo-governance-hub.optimization.tests.ps1` -> pass
- `powershell -File scripts/validate-config.ps1` -> pass
- `powershell -File scripts/verify.ps1` -> pass
- `powershell -File scripts/doctor.ps1` -> pass (`HEALTH=GREEN`)
- `powershell -File E:/CODE/skills-manager/scripts/prebuild-check.ps1` -> pass (warn-only dirty tree)

## decision_note
- hash 后缀机制仍保留给“通用 auto 命名去冲突”场景；但本问题族已收敛到 canonical guard，运行态不再需要该 auto 名称。
