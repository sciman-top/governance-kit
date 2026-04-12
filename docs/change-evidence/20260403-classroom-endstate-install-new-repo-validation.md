规则ID=R1/R2/R4/R6/R8 + E3/E4
影响模块=scripts/{add-repo.ps1,run-endstate-onboarding.ps1,verify-kit.ps1,lib/common.ps1}, config/{project-custom-files.json,targets.json}, source/project/ClassroomToolkit/custom/*, README.md
当前落点=E:/CODE/repo-governance-hub
目标归宿=repo-governance-hub installer can bootstrap ClassroomToolkit custom governance stack into new repos
迁移批次=2026-04-03-classroom-endstate-installer-hardening
风险等级=Medium(config + installer behavior change, validated on sandbox repo)
执行命令=see_command_list_below
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/add-repo.ps1 -RepoPath E:/CODE/sandbox/ClassroomToolkit -Mode safe
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-extras.ps1 -Mode safe
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/sandbox/ClassroomToolkit/scripts/governance/check-evidence-completeness.ps1 -Mode all -Threshold 98
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/sandbox/ClassroomToolkit/scripts/governance/backfill-evidence-template-fields.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/sandbox/ClassroomToolkit/scripts/governance/check-evidence-completeness.ps1 -Mode all -Threshold 98
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/sandbox/ClassroomToolkit/scripts/governance/run-endstate-loop.ps1 -Profile quick -Configuration Debug -EvidenceMode all
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-endstate-onboarding.ps1 -RepoPath E:/CODE/sandbox/ClassroomToolkit -Mode plan -EvidenceMode all
验证证据=see_evidence_list_below
- Source sync completed: ClassroomToolkit custom governance scripts/workflows copied to source/project/ClassroomToolkit/custom.
- add-repo enhancement: now auto-registers custom targets from project-custom-files.json.
- policy fix: Is-ProjectRuleSource now excludes source/project/<repo>/custom/*, avoiding false disallowed-target failures.
- onboarding entry added: run-endstate-onboarding.ps1 provides one-command convergence pipeline for new/old repos.
- repo-governance-hub health: validate-config PASS, verify PASS(ok=29), doctor HEALTH=GREEN.
- new repo install evidence:
  immediate evidence(all) check FAIL in E:/CODE/sandbox/ClassroomToolkit (overall_coverage=58.38).
  after running backfill script, evidence(all) PASS (overall_coverage=100).
  run-endstate-loop -EvidenceMode all PASS; doctor score=100 with reports:
  E:/CODE/sandbox/ClassroomToolkit/docs/governance/reports/endstate-20260403-013551.{md,json}
- conclusion: installer provides convergent path to endstate; immediate endstate depends on legacy debt and requires backfill/recovery loop.
回滚动作=see_rollback_list_below
- Revert repo-governance-hub changes in:
  scripts/add-repo.ps1
  scripts/run-endstate-onboarding.ps1
  scripts/verify-kit.ps1
  scripts/lib/common.ps1
  README.md
  config/project-custom-files.json
  config/targets.json
  source/project/ClassroomToolkit/custom/*
- Remove sandbox registration if needed:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/remove-repo.ps1 -RepoPath E:/CODE/sandbox/ClassroomToolkit
- Restore previous snapshot via repo-governance-hub backups and rerun:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
