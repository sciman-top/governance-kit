规则ID=GK-20260406-precommit-pending-and-outgoing-judgement
规则版本=3.82
兼容窗口(观察期/强制期)=observe->enforce（本次为安全分发与现网判定，不改变外部契约）
影响模块=scripts/governance/check-tracked-files.ps1; scripts/run-project-governance-cycle.ps1; source/project/_common/custom/scripts/governance/check-tracked-files.ps1
当前落点=E:/CODE/governance-kit（source of truth）
目标归宿=E:/CODE/governance-kit、E:/CODE/skills-manager、E:/CODE/ClassroomToolkit
迁移批次=2026-04-06
风险等级=MEDIUM
是否豁免(Waiver)=否
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/governance-kit/scripts/governance/check-tracked-files.ps1 -RepoPath <repo> -PolicyPath <repo>/.governance/tracked-files-policy.json -Scope pending -AsJson
- powershell -NoProfile -ExecutionPolicy Bypass -File E:/CODE/governance-kit/scripts/governance/check-tracked-files.ps1 -RepoPath <repo> -PolicyPath <repo>/.governance/tracked-files-policy.json -Scope outgoing -AsJson
- git -C <repo> rev-list --count @{u}..HEAD
验证证据=
- install(safe) 结果：copied=2 backup=2 skipped=62，Verify done. ok=64 fail=0
- backup root：E:/CODE/governance-kit/backups/20260406-224629
- 三仓 pending 判定：blocked=false, pending_count=0, must_ignore_hits=0, review_required_hits=0
- 三仓 outgoing 判定：blocked=false, outgoing_count=0
- 三仓 outgoing commit 复核：
  - E:/CODE/governance-kit: 0
  - E:/CODE/skills-manager: 0
  - E:/CODE/ClassroomToolkit: 0
- 本次口径结论：当前无“应提交”文件；当前无“应推送”提交。
供应链安全扫描=gate_na; reason=本次仅治理脚本逻辑与分发判定，不新增三方依赖/制品；alternative_verification=install+verify+tracked-files 双范围判定；evidence_link=docs/change-evidence/20260406-pending-outgoing-precommit-judgement-and-distribution.md; expires_at=2026-04-20
发布后验证(指标/阈值/窗口)=
- 指标：pending_count, outgoing_count, blocked
- 阈值：pending_count=0 且 outgoing_count=0 且 blocked=false
- 窗口：本次分发后即时验证（2026-04-06）
数据变更治理(迁移/回填/回滚)=无结构化数据变更；N/A
回滚动作=
- 使用脚本回滚：powershell -NoProfile -ExecutionPolicy Bypass -File scripts/restore.ps1
- 或按备份快照回滚：E:/CODE/governance-kit/backups/20260406-224629
- 若仅回滚本次关键文件：
  - source/project/_common/custom/scripts/governance/check-tracked-files.ps1
  - scripts/governance/check-tracked-files.ps1
  - scripts/run-project-governance-cycle.ps1
