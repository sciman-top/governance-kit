规则ID=R2/R4/R8
规则版本=9.38
兼容窗口(观察期/强制期)=observe -> enforce
影响模块=source/global,source/template,scripts/governance,scripts/validate-config
当前落点=repo-governance-hub
目标归宿=触发式澄清协议模板化 + 治理循环入口联动
迁移批次=phase2
风险等级=medium
issue_id=repo-governance-hub-clarification-mode-phase2
attempt_count=1
clarification_mode(off|required|resolved)=resolved
clarification_questions=N/A
clarification_answers=N/A
final_acceptance_examples=run-project-governance-cycle emits CLARIFICATION_REQUIRED after repeated failures
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-project-governance-cycle.ps1 -RepoRoot E:/CODE/repo-governance-hub -GovernanceRoot E:/CODE/repo-governance-hub -Mode plan -IssueId demo-cycle
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/run-target-autopilot.ps1 -RepoRoot E:/CODE/repo-governance-hub -GovernanceRoot E:/CODE/repo-governance-hub -DryRun -IssueId demo-target
验证证据=
- validation passed
- governance wrapper accepts IssueId and forwards
- target autopilot outputs issue_id and supports clarification tracker
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=doctor clarification observability remains available
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=
- revert source/global and source/template clarification protocol sections
- revert issue-tracker integration in scripts/governance/run-project-governance-cycle.ps1 and scripts/run-project-governance-cycle.ps1
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
