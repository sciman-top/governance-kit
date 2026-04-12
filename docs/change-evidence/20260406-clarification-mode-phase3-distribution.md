规则ID=R2/R4/R8
规则版本=9.38
兼容窗口(观察期/强制期)=observe -> enforce
影响模块=source/project/_common/custom,source/project/ClassroomToolkit/custom,install/distribution
当前落点=repo-governance-hub
目标归宿=澄清模式入口脚本分发到目标仓
迁移批次=phase3
风险等级=medium
issue_id=repo-governance-hub-clarification-mode-phase3
attempt_count=1
clarification_mode(off|required|resolved)=resolved
clarification_questions=N/A
clarification_answers=N/A
final_acceptance_examples=target repos run-target-autopilot accepts -IssueId in dry-run
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1 -AsJson
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/ClassroomToolkit/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/ClassroomToolkit -GovernanceRoot E:/CODE/repo-governance-hub -DryRun -IssueId smoke-classroom
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/skills-manager/scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/skills-manager -GovernanceRoot E:/CODE/repo-governance-hub -DryRun -IssueId smoke-skills
验证证据=
- install safe: copied updated governance entry scripts to ClassroomToolkit and skills-manager
- doctor(asJson): health=GREEN and clarification observability fields present
- two target repo dry-runs show issue_id output
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=doctor clarification_trigger_count/open_items
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=
- restore previous versions of run-project-governance-cycle.ps1 / run-target-autopilot.ps1 in source/project/_common/custom and target repos
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
