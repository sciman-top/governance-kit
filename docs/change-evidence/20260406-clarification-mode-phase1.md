规则ID=R2/R4/R8
规则版本=9.38
兼容窗口(观察期/强制期)=observe -> enforce
影响模块=config,scripts/governance,scripts/doctor,templates,tests
当前落点=repo-governance-hub
目标归宿=outer-ai-session 自动触发澄清模式
迁移批次=phase1
风险等级=medium
issue_id=repo-governance-hub-clarification-mode-phase1
attempt_count=1
clarification_mode(off|required|resolved)=resolved
clarification_questions=N/A
clarification_answers=N/A
final_acceptance_examples=second failure triggers clarification_required=true
是否豁免(Waiver)=否
豁免责任人=
豁免到期=
豁免回收计划=
执行命令=
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1 -AsJson
- powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Path tests/clarification-mode.tests.ps1"
验证证据=
- validate-config: passed
- doctor(asJson): clarification observability fields generated; verify-targets existing failure remained
- pester: clarification-mode tests passed (3/3)
供应链安全扫描=N/A
发布后验证(指标/阈值/窗口)=doctor.clarification.trigger_count/open_items tracked
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=
- remove config/clarification-policy.json
- revert scripts/governance/track-issue-state.ps1 and run-target-autopilot integration
- revert validate-config/doctor/template field additions
