规则ID=R2/R4/R6/R8 (契约化发布 + 真实仓库回归矩阵)
规则版本=3.79
兼容窗口(观察期/强制期)=observe / planned_enforce_date=2026-04-15
影响模块=
- scripts/verify-json-contract.ps1 (new)
- scripts/run-real-repo-regression.ps1 (new)
- config/real-repo-regression-matrix.json (new)
- scripts/status.ps1
- scripts/rollout-status.ps1
- scripts/doctor.ps1
- scripts/verify-kit.ps1
- tests/governance-kit.optimization.tests.ps1
- .github/workflows/governance-self-check.yml
- README.md
- docs/governance/json-contract-schema-v1.md (new)
- docs/governance/rule-release-process.md (new)
- docs/governance/rule-release-template.md (new)
当前落点=E:/CODE/governance-kit
目标归宿=JSON 合同稳定化、发布流程模板化、真实仓库回归矩阵化
迁移批次=2026-04-02-contract-release-matrix
风险等级=Medium (新增脚本+配置+工作流+测试)
是否豁免(Waiver)=No
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=
- powershell -File tests/governance-kit.optimization.tests.ps1
- powershell -File scripts/verify-kit.ps1
- powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1
- powershell -File scripts/verify-json-contract.ps1
- powershell -File scripts/run-real-repo-regression.ps1 -Mode smoke
- powershell -File scripts/doctor.ps1
- powershell -File scripts/install.ps1 -Mode safe
验证证据=
- JSON 合同校验脚本已可独立验证 status/rollout-status/doctor 的 schema_version 和必需字段。
- governance-self-check workflow 已增加 Verify JSON Contract 步骤。
- 真实仓库回归矩阵支持 plan/smoke/full，并在本机 smoke 实测通过（ClassroomToolkit/skills-manager/governance-kit）。
- AsJson 输出 schema_version 固化为 1.0 并有文档声明与兼容策略。
- 发布流程文档与模板已落地，可用于版本发布/回滚演练留痕。
- 优化测试集通过（41 条）。
- verify=ok=23 fail=0，doctor=HEALTH GREEN，install safe=skipped=23。
供应链安全扫描=N/A (无外部依赖新增)
发布后验证(指标/阈值/窗口)=observe 期持续到 2026-04-15；关注 JSON schema_version 稳定输出与矩阵 smoke 成功率
数据变更治理(迁移/回填/回滚)=N/A
回滚动作=
- git checkout -- scripts/verify-json-contract.ps1 scripts/run-real-repo-regression.ps1 config/real-repo-regression-matrix.json scripts/status.ps1 scripts/rollout-status.ps1 scripts/doctor.ps1 scripts/verify-kit.ps1 tests/governance-kit.optimization.tests.ps1 .github/workflows/governance-self-check.yml README.md docs/governance/json-contract-schema-v1.md docs/governance/rule-release-process.md docs/governance/rule-release-template.md
