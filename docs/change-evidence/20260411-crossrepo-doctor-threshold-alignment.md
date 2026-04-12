issue_id=crossrepo-doctor-threshold-alignment-20260411
当前落点=E:/CODE/repo-governance-hub + E:/CODE/skills-manager
目标归宿=source/project/skills-manager/*（规则） + skills-manager/src/Commands/Doctor.ps1（根因代码）
风险等级=medium
执行模式=direct_fix
clarification_mode=none

任务理解快照=目标: 自动执行跨仓协作修复闭环; 非目标: 清理历史脏工作区; 验收: 两仓门禁链路通过且协作口径一致; 关键假设: skills-manager 性能阻断属于可复现阈值口径问题
术语解释点=source of truth: 应在规则/策略真实归宿仓先修复再分发; 本次示例为 repo-governance-hub 的 source/project/skills-manager/*
可观测信号=现象: skills-manager `doctor --strict` 因 build_agent 阈值触发失败; 假设: 7000ms 专属阈值过紧; 验证: 调整后重跑门禁; 预期: contract/invariant 通过

依据=用户要求“按建议自动执行”，并按跨仓协作策略先归因后修复
命令=repo-governance-hub: verify-kit/test/validate-config/verify/doctor; install.ps1 -Mode safe
命令=skills-manager: build.ps1; skills.ps1 发现; skills.ps1 doctor --strict --threshold-ms 8000; skills.ps1 构建生效
关键输出=repo-governance-hub verify done ok=187 fail=0; doctor HEALTH=GREEN
关键输出=skills-manager doctor 最终输出 `Your system is ready for skills-manager.`
关键输出=skills-manager 构建生效完成且 prebuild-check Result: PASS with WARN

变更文件=source/project/skills-manager/AGENTS.md
变更文件=source/project/skills-manager/CLAUDE.md
变更文件=source/project/skills-manager/GEMINI.md
变更文件=E:/CODE/skills-manager/src/Commands/Doctor.ps1

根因与修复=初次仅改门禁命令参数仍失败，因 Doctor 内部 build_agent 阈值硬编码 7000ms 覆盖全局阈值。最终将专属阈值调整为 8000ms，并同步规则门禁口径。
回滚动作=git -C E:/CODE/repo-governance-hub checkout -- source/project/skills-manager/AGENTS.md source/project/skills-manager/CLAUDE.md source/project/skills-manager/GEMINI.md
回滚动作=git -C E:/CODE/skills-manager checkout -- src/Commands/Doctor.ps1 skills.ps1

learning_points_3=1) 跨仓门禁失败需先区分规则口径与实现阈值两层 2) `--threshold-ms` 不会覆盖指标专属阈值 3) 先改 source 再分发可避免目标仓漂移
reusable_checklist=1) 先跑两仓门禁定位失败层 2) 判断 source of truth 并先修规则 3) 若仍失败再修目标仓根因代码 4) 重跑完整门禁链并留证据
open_questions=是否将 build_agent 专属阈值改为配置项而非硬编码
decision_score=0.80
hard_guard_hits=none
reason_codes=trace_grading_backfill
