issue_id=skill-promotion-dedup-hardening-20260411
当前落点=E:/CODE/governance-kit/source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1
目标归宿=source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1 + source/project/_common/custom/.governance/skill-promotion-policy.json
风险等级=medium
执行模式=direct_fix

问题=同类签名被拆成多个 auto 技能，导致 overrides 重复膨胀；用户无清晰可见的创建摘要
根因=按原始 issue_signature 逐条分组，未做 family 聚合；registry 未做 family 压实；缺少计划/结果摘要

修复动作=新增 family 聚合与排除过滤（默认过滤 autopilot-utf8-smoke）
修复动作=registry 启动即做 family 压实（同类签名合并）
修复动作=自动清理 legacy custom-auto 目录（同 family 非 canonical 命名）
修复动作=新增 summary 输出到 .governance/skill-candidates/last-promotion-summary.json
修复动作=新增可选确认门槛策略 require_user_ack + env ack

策略新增字段=summary_relative_path, write_summary_file, require_user_ack, user_ack_env_var, user_ack_expected_value
命令=governance-kit install.ps1 -Mode safe; skills-manager promote-skill-candidates -AsJson; skills-manager doctor --strict
关键输出=grouped_signature_count=1, promoted_count=0, cleanup_removed_count=0（稳定状态下无新增无清理）
关键输出=overrides 仅保留 custom-auto-pwsh-encoding-mojibake-l-a9b049cd + custom-windows-encoding-guard
关键输出=skills-manager doctor --strict 通过

回滚动作=git -C E:/CODE/governance-kit checkout -- source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1 source/project/_common/custom/.governance/skill-promotion-policy.json
回滚动作=git -C E:/CODE/skills-manager checkout -- scripts/governance/promote-skill-candidates.ps1 .governance/skill-promotion-policy.json .governance/skill-candidates

learning_points_3=1) 同类问题必须以 family 为主键 2) 自动创建必须伴随可见 summary 3) registry 缺失/分裂会放大重复创建风险
