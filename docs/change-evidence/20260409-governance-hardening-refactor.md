规则ID=GK-20260409-hardening-refactor
规则版本=3.83
兼容窗口(观察期/强制期)=observe->enforce(未改变契约)
影响模块=scripts/lib/common.ps1;scripts/install.ps1;scripts/verify.ps1;scripts/run-project-governance-cycle.ps1;scripts/governance/run-target-autopilot.ps1;scripts/suggest-release-profile.ps1;scripts/verify-release-profile.ps1;tests/repo-governance-hub.optimization.tests.ps1
当前落点=E:/CODE/repo-governance-hub/scripts/*
目标归宿=E:/CODE/repo-governance-hub/source/project/_common/custom/scripts/governance/run-target-autopilot.ps1 + 仓内脚本公共能力统一
迁移批次=batch-1(common helper+cache), batch-2(callsite refactor), batch-3(gate verification)
风险等级=中
是否豁免(Waiver)=否
豁免责任人=N/A
豁免到期=N/A
豁免回收计划=N/A
执行命令=codex --version; codex --help; codex status; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=build/test/contract/hotspot 全绿; verify done ok=106 fail=0; doctor HEALTH=GREEN
供应链安全扫描=N/A(本次未引入新依赖)
发布后验证(指标/阈值/窗口)=install/verify/doctor运行时长对比(本次tests约90.8s->81.1~87.8s, 受环境波动)
数据变更治理(迁移/回填/回滚)=无结构化数据迁移; 仅脚本重构与缓存
回滚动作=git checkout -- scripts/lib/common.ps1 scripts/install.ps1 scripts/verify.ps1 scripts/run-project-governance-cycle.ps1 scripts/governance/run-target-autopilot.ps1 scripts/suggest-release-profile.ps1 scripts/verify-release-profile.ps1 tests/repo-governance-hub.optimization.tests.ps1 source/project/_common/custom/scripts/governance/run-target-autopilot.ps1

issue_id=GK-20260409-hardening-refactor
attempt_count=1
clarification_mode=direct_fix
clarification_scenario=bugfix
clarification_questions=[]
clarification_answers=[]
任务理解快照=目标:正确性/鲁棒性+性能+去冗余+可维护性; 非目标:不改变外部契约与门禁语义; 验收:build->test->contract/invariant->hotspot通过
术语解释点=JSON缓存(按文件mtime失效); 哈希缓存(按长度+mtime失效); Clarification Tracker(触发式澄清状态机)
可观测信号=verify-targets差异计数fail=1时阻断; 回灌+同步后恢复ok=106
排障路径=先修StrictMode变量初始化异常->再修source/target分发一致性差异
未确认假设与纠偏结论=假设分发一致性自动满足(未确认)->经verify发现skills-manager差异后执行同步纠偏
learning_points_3=1) StrictMode下未初始化script变量读取会抛错; 2) 公共函数去重要同步source与targets; 3) 先门禁再重构可快速定位真实阻塞
reusable_checklist=先跑基线门禁->做小步重构->补测试->按固定顺序复验->处理分发一致性差异
open_questions=是否将scripts/governance/run-target-autopilot.ps1完全改为从source生成，避免手工回灌

追加审查=2026-04-10 broad hardening review
追加落点=E:/CODE/repo-governance-hub/scripts/lib/common.ps1;E:/CODE/repo-governance-hub/tests/repo-governance-hub.optimization.tests.ps1
追加目标归宿=公共缓存 helper 稳健性增强，保持现有脚本外部契约不变
追加改动=新增 Get-FileCacheStamp; JSON cache 与 hash cache 统一按 length+LastWriteTimeUtcTicks 失效; 补充 JSON cache 更新回归测试
追加风险等级=低(内部 helper 行为收紧，外部命令/参数/输出契约不变)
追加验证命令=PowerShell AST parse all ps1/psm1; git diff --check; powershell -File scripts/verify-kit.ps1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
追加验证证据=parse_ok files=86; diff_check=no whitespace errors(LF->CRLF warning only); tests all pass(~101s); Config validation passed repositories=3 targets=106 rolloutRepos=1; Verify done ok=106 fail=0; doctor HEALTH=GREEN
追加回滚动作=git checkout -- scripts/lib/common.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md
追加可观测信号=修改 JSON 文件后 Read-JsonFile -UseCache 返回新 value; 修改文件内容后 Get-FileSha256 返回新 hash
追加排障路径=先全仓 AST parse 排除语法错误->运行新增/既有测试->按固定门禁顺序复验
追加未确认假设与纠偏结论=PSScriptAnalyzer 本机未安装，未作为强门禁；以 AST parse + 全量回归 + 固定门禁替代
追加learning_points_3=1) 缓存失效条件应包含长度和mtime以减少同tick旧读风险; 2) 性能优化必须保留回归测试证明缓存正确; 3) 广泛重构应收敛到低风险公共 helper 切片

追加审查2=2026-04-10 clarification helper hardening
追加落点2=E:/CODE/repo-governance-hub/scripts/lib/common.ps1;E:/CODE/repo-governance-hub/tests/repo-governance-hub.optimization.tests.ps1
追加目标归宿2=澄清状态机公共 helper 异常路径前置校验，保持正常流程契约不变
追加改动2=非法 RequestedScenario 不再原样透传，回落到 bugfix/fallback; clarification context 复用 Read-JsonFile; Invoke-ClarificationTracker 增加 tracker script、PowerShell command、空输出、非法 JSON 校验
追加风险等级2=低(仅收紧异常路径，正常 bugfix/requirement/plan/acceptance 场景不变)
追加验证命令2=PowerShell AST parse all ps1/psm1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
追加验证证据2=parse_ok files=86; tests all pass(~98s incremental/~146s full gate chain); repo-governance-hub integrity OK; Config validation passed repositories=3 targets=106 rolloutRepos=1; Verify done ok=106 fail=0; doctor HEALTH=GREEN
追加回滚动作2=git checkout -- scripts/lib/common.ps1 tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md
追加可观测信号2=Resolve-EffectiveClarificationScenario invalid scenario returns scenario=bugfix source=fallback; missing tracker helper throws before child process invocation
追加排障路径2=先审查 tracker 调用点->补异常路径测试->跑全量回归->跑固定门禁
追加learning_points_3_2=1) 公共 helper 应在边界处给出清晰错误，避免下游 ValidateSet 才失败; 2) 配置/上下文 JSON 读取应复用统一读入函数; 3) 异常路径收紧必须配套测试，避免误改正常契约

追加审查3=2026-04-10 clarification tracker edge-path regression hardening
追加落点3=E:/CODE/repo-governance-hub/tests/repo-governance-hub.optimization.tests.ps1
追加目标归宿3=将 Invoke-ClarificationTracker 的边界校验行为固化为回归测试，防止后续重构回退
追加改动3=新增 missing PowerShell command 与 tracker invalid JSON 两条异常路径测试
追加风险等级3=低(仅测试增强，不改变运行逻辑)
追加验证命令3=PowerShell AST parse all ps1/psm1; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
追加验证证据3=parse_ok files=86; tests all pass(~107s incremental/~119s full gate chain); repo-governance-hub integrity OK; Config validation passed repositories=3 targets=106 rolloutRepos=1; Verify done ok=106 fail=0; doctor HEALTH=GREEN
追加回滚动作3=git checkout -- tests/repo-governance-hub.optimization.tests.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md
追加可观测信号3=Invoke-ClarificationTracker with missing command throws; fake tracker output malformed JSON throws
追加learning_points_3_3=1) 异常路径没有回归用例时最容易在“优化重构”中被破坏; 2) 先写失败路径测试再重构可减少隐藏回归; 3) 治理脚本应优先可诊断性而非静默容错

追加审查5=2026-04-10 codex runtime risk-balance rollback (workspace-write + network enabled)
追加落点5=E:/CODE/repo-governance-hub/source/project/_common/custom/.codex/config.toml
追加目标归宿5=维持联网能力的同时恢复沙箱边界，降低 danger-full-access 风险
追加改动5=sandbox_mode: danger-full-access -> workspace-write; network_access 保持 true
追加分发5=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe (copied=3 .codex/config.toml)
追加验证证据5=repo-governance-hub/ClassroomToolkit/skills-manager 三仓 .codex/config.toml 均为 workspace-write + network_access=true; install post-gate passed; doctor HEALTH=GREEN
追加风险等级5=中低(仍存在 Windows 沙箱辅助进程拦截概率，但权限边界优于 danger-full-access)
追加回滚动作5=若需恢复 danger-full-access，修改 source/project/_common/custom/.codex/config.toml 后重跑 scripts/install.ps1 -Mode safe

追加审查6=2026-04-10 set-codex-runtime-policy helper unification
追加落点6=E:/CODE/repo-governance-hub/scripts/set-codex-runtime-policy.ps1
追加目标归宿6=减少重复 JSON 解析逻辑并统一读写边界
追加改动6=改用 Read-JsonFile 读取 codex-runtime-policy.json；写回改为 Set-Content -LiteralPath
追加验证证据6=parse_ok files=86; tests all pass(~104s); verify-kit/config/verify/doctor 全绿
追加风险等级6=低(行为不变，主要是实现统一化)
追加回滚动作6=git checkout -- scripts/set-codex-runtime-policy.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查7=2026-04-10 validate-config/install JSON-read unification
追加落点7=E:/CODE/repo-governance-hub/scripts/validate-config.ps1;E:/CODE/repo-governance-hub/scripts/install.ps1
追加目标归宿7=继续去冗余：统一配置读取入口，减少散落 Get-Content|ConvertFrom-Json 与路径写回歧义
追加改动7=validate-config 新增 Read-RequiredJsonConfig/Read-OptionalJsonConfig 并替换多处 JSON 读取；install.Get-FullCycleRepos 改用 Read-JsonArray
追加验证证据7=parse_ok files=86; tests all pass(~102~103s); verify-kit/config/verify/doctor 全绿(HEALTH=GREEN, verify ok=106 fail=0)
追加风险等级7=低(不改校验语义，仅实现层统一)
追加回滚动作7=git checkout -- scripts/validate-config.ps1 scripts/install.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查8=2026-04-10 validate-config numeric-range helper modularization
追加落点8=E:/CODE/repo-governance-hub/scripts/validate-config.ps1
追加目标归宿8=进一步降低重复分支复杂度，保持报错文案与语义一致
追加改动8=新增 Validate-IntInRange helper；替换 project-rule-policy.defaults 的 clarification_* 与 clarification-policy 的整型范围校验重复逻辑
追加验证证据8=parse_ok files=86; tests all pass(~105s); verify-kit/config/verify/doctor 全绿(HEALTH=GREEN, verify ok=106 fail=0)
追加风险等级8=低(实现重构，不改规则判定条件)
追加回滚动作8=git checkout -- scripts/validate-config.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查4=2026-04-10 codex runtime network enable and windows sandbox-helper frequency mitigation
追加落点4=E:/CODE/repo-governance-hub/source/project/_common/custom/.codex/config.toml
追加目标归宿4=统一分发到全部目标仓，默认启用网络并降低 Windows 沙箱辅助进程介入频率
追加改动4=sandbox_mode: workspace-write -> danger-full-access; sandbox_workspace_write.network_access: false -> true
追加分发4=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install.ps1 -Mode safe (copied=3 to repo-governance-hub/ClassroomToolkit/skills-manager .codex/config.toml)
追加验证命令4=目标仓读取 .codex/config.toml; install 内置 post-gate (build->test->contract/invariant->hotspot)
追加验证证据4=三个目标仓 .codex/config.toml 均为 sandbox_mode=danger-full-access + network_access=true; post-gate passed; doctor HEALTH=GREEN
追加风险等级4=中(关闭沙箱隔离会提升执行权限风险，需要依赖审批策略与仓内门禁兜底)
追加回滚动作4=将 source/project/_common/custom/.codex/config.toml 恢复为 sandbox_mode=workspace-write + network_access=false 后重跑 scripts/install.ps1 -Mode safe
追加可观测信号4=目标仓编码时“Windows 沙箱辅助进程拦截”出现频率应显著下降；网络请求在目标仓可直接执行

gate_na=PSScriptAnalyzer
reason=本机未安装 PSScriptAnalyzer 模块
alternative_verification=PowerShell AST parse all ps1/psm1 + tests/repo-governance-hub.optimization.tests.ps1 + fixed gates
evidence_link=docs/change-evidence/20260409-governance-hardening-refactor.md
expires_at=2026-05-10

platform_na=codex status
reason=非交互环境返回"stdin is not a terminal"
alternative_verification=记录codex --version/codex --help + active_rule_path=E:/CODE/repo-governance-hub/AGENTS.md
_evidence_link=docs/change-evidence/20260409-governance-hardening-refactor.md
expires_at=2026-05-09

追加审查9=2026-04-10 validate-config boolean-check de-dup (behavior preserving)
追加落点9=E:/CODE/repo-governance-hub/scripts/validate-config.ps1
追加目标归宿9=收敛布尔/必填字符串重复校验逻辑，降低后续维护变更面
追加改动9=新增 Validate-BooleanValue/Validate-RequiredBooleanProperty/Validate-OptionalBooleanProperty/Validate-RequiredNonEmptyStringProperty；替换 defaults、clarification-policy、codex-runtime-policy、release-distribution-policy 与 project-rule-policy.repos 段重复分支
追加验证命令9=PowerShell AST parse scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据9=validate-config parse ok; Config validation passed repositories=3 targets=106 rolloutRepos=1; optimization tests all pass(~113s); verify-kit pass; verify ok=106 fail=0; doctor HEALTH=GREEN
追加风险等级9=低(仅实现层去重，保留原报错文案与门禁语义)
追加回滚动作9=git checkout -- scripts/validate-config.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查10=2026-04-10 status/rollout-status JSON read-path unification
追加落点10=E:/CODE/repo-governance-hub/scripts/status.ps1;E:/CODE/repo-governance-hub/scripts/rollout-status.ps1
追加目标归宿10=统一配置读取路径到 common helper，降低重复解析与提升一致性
追加改动10=status.ps1 的 rollout/codex-runtime-policy 读取改为 Read-JsonFile；rollout-status.ps1 的 rollout 读取改为 Read-JsonFile
追加验证命令10=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/status.ps1 -AsJson; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/rollout-status.ps1 -AsJson; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据10=status/rollout-status AsJson 均 exit 0；optimization tests all pass(~105s)；verify-kit pass；Config validation passed repositories=3 targets=106 rolloutRepos=1；verify ok=106 fail=0；doctor HEALTH=GREEN
追加风险等级10=低(行为不变，读取入口统一)
追加回滚动作10=git checkout -- scripts/status.ps1 scripts/rollout-status.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查11=2026-04-10 install targets parse-path unification
追加落点11=E:/CODE/repo-governance-hub/scripts/install.ps1
追加目标归宿11=统一 targets.json 读取入口并减少脚本内重复解析分支
追加改动11=install.ps1 中 targets 读取由 Get-Content|ConvertFrom-Json + 手动数组归一化 改为 Read-JsonArray
追加验证命令11=powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据11=optimization tests all pass(~111s)；verify-kit pass；Config validation passed repositories=3 targets=106 rolloutRepos=1；verify ok=106 fail=0；doctor HEALTH=GREEN
追加风险等级11=低(行为不变，读取逻辑统一)
追加回滚动作11=git checkout -- scripts/install.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查12=2026-04-10 rollout/restore/waiver read-path unification + set-rollout new-entry bugfix
追加落点12=E:/CODE/repo-governance-hub/scripts/set-rollout.ps1;E:/CODE/repo-governance-hub/scripts/restore.ps1;E:/CODE/repo-governance-hub/scripts/check-waivers.ps1
追加目标归宿12=统一 JSON 读取入口并修复 set-rollout 在新条目场景的属性写入异常
追加改动12=set-rollout/check-waivers 读取 rollout 改为 Read-JsonFile；restore 读取 targets 改为 Read-JsonArray；set-rollout 新增 Set-ObjectPropertyValue，修复 -Mode plan 新增 repo 时 phase 等属性赋值报错
追加验证命令12=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-waivers.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/set-rollout.ps1 -RepoPath E:/CODE/repo-governance-hub -Mode plan -Phase observe; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据12=check-waivers exit 0(files=0 expired=0 blocked=0)；set-rollout plan 由失败转为成功([PLAN] ADD rollout entry)；optimization tests all pass(~107s)；verify-kit pass；Config validation passed repositories=3 targets=106 rolloutRepos=1；verify ok=106 fail=0；doctor HEALTH=GREEN
追加风险等级12=低(读取统一+明确 bugfix，未改变门禁语义)
追加回滚动作12=git checkout -- scripts/set-rollout.ps1 scripts/restore.ps1 scripts/check-waivers.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查13=2026-04-10 verify targets read-path unification
追加落点13=E:/CODE/repo-governance-hub/scripts/verify.ps1
追加目标归宿13=统一 verify/install/restore 的 targets.json 读取实现，降低重复逻辑
追加改动13=verify.ps1 将 targets 读取从 Get-Content|ConvertFrom-Json + 手动归一化 改为 Read-JsonArray
追加验证命令13=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据13=verify ok=106 fail=0；optimization tests all pass(~105s)；doctor HEALTH=GREEN
追加风险等级13=低(行为不变，减少重复解析分支)
追加回滚动作13=git checkout -- scripts/verify.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查14=2026-04-10 add/remove/regression JSON read-path unification
追加落点14=E:/CODE/repo-governance-hub/scripts/add-repo.ps1;E:/CODE/repo-governance-hub/scripts/remove-repo.ps1;E:/CODE/repo-governance-hub/scripts/run-real-repo-regression.ps1
追加目标归宿14=统一低风险脚本的 JSON 读取实现，减少散落 ConvertFrom-Json 分支
追加改动14=add-repo/remove-repo/run-real-repo-regression 改用 Read-JsonFile/Read-JsonArray；保持原错误口径
追加验证命令14=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/add-repo.ps1 -RepoPath E:/CODE/repo-governance-hub -Mode plan; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/remove-repo.ps1 -RepoPath E:/CODE/repo-governance-hub -Mode plan; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-real-repo-regression.ps1 -Mode plan; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1
追加验证证据14=三脚本 plan smoke 均通过；optimization tests all pass(~105s)；verify-kit pass
追加风险等级14=低(行为不变，读入路径统一)
追加回滚动作14=git checkout -- scripts/add-repo.ps1 scripts/remove-repo.ps1 scripts/run-real-repo-regression.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查15=2026-04-10 check-update-triggers JSON read-path unification + source sync fix
追加落点15=E:/CODE/repo-governance-hub/scripts/governance/check-update-triggers.ps1;E:/CODE/repo-governance-hub/source/project/repo-governance-hub/custom/scripts/governance/check-update-triggers.ps1
追加目标归宿15=统一治理触发器脚本 JSON 读取并维持 source/target 一致性
追加改动15=check-update-triggers 对 update-trigger-policy/release-distribution-policy/repositories/release-profile 读取改用 Read-JsonFile/Read-JsonArray；出现 verify DIFF 后已按本仓回灌策略同步 source 镜像文件
追加验证命令15=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-update-triggers.ps1 -AsJson; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据15=check-update-triggers 输出 AsJson(status=ALERT, exit=1, 为业务告警非脚本错误)；optimization tests all pass(~100s)；verify 最终 ok=106 fail=0；doctor HEALTH=GREEN
追加风险等级15=低(实现统一+已完成 source of truth 同步)
追加回滚动作15=git checkout -- scripts/governance/check-update-triggers.ps1 source/project/repo-governance-hub/custom/scripts/governance/check-update-triggers.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查16=2026-04-10 doctor clarification-observability JSON read-path unification
追加落点16=E:/CODE/repo-governance-hub/scripts/doctor.ps1
追加目标归宿16=统一 doctor 对 repositories/clarification state 的 JSON 读取路径，同时保留 common 缺失时兼容回退
追加改动16=Get-ClarificationObservability 中优先使用 Read-JsonArray/Read-JsonFile，fallback 继续使用原始 ConvertFrom-Json 逻辑
追加验证命令16=powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据16=optimization tests all pass(~103s)；verify-kit pass；Config validation passed repositories=3 targets=106 rolloutRepos=1；verify ok=106 fail=0；doctor HEALTH=GREEN
追加风险等级16=低(行为不变，兼容路径保留)
追加回滚动作16=git checkout -- scripts/doctor.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md

追加审查17=2026-04-10 audit/orphan JSON read-path unification
追加落点17=E:/CODE/repo-governance-hub/scripts/check-orphan-custom-sources.ps1;E:/CODE/repo-governance-hub/scripts/audit-governance-readiness.ps1
追加目标归宿17=统一治理审计链路配置读取，减少散落 ConvertFrom-Json 分支
追加改动17=check-orphan-custom-sources 的 project-custom-files 读取改为 Read-JsonFile；audit-governance-readiness 的 project-custom/baseline 读取改为 Read-JsonFile
追加验证命令17=powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-orphan-custom-sources.ps1 -AsJson; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/audit-governance-readiness.ps1 -AsJson; powershell -NoProfile -ExecutionPolicy Bypass -File tests/repo-governance-hub.optimization.tests.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-kit.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-config.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1
追加验证证据17=smoke 命令均 exit 0；optimization tests all pass(~104s)；verify-kit pass；Config validation passed repositories=3 targets=106 rolloutRepos=1；verify ok=106 fail=0；doctor HEALTH=GREEN
追加风险等级17=低(行为不变，读取路径统一)
追加回滚动作17=git checkout -- scripts/check-orphan-custom-sources.ps1 scripts/audit-governance-readiness.ps1 docs/change-evidence/20260409-governance-hardening-refactor.md
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
