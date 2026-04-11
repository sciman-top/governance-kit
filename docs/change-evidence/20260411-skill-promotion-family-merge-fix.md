issue_id=skill-promotion-family-merge-fix-20260411
当前落点=E:/CODE/governance-kit/source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1
目标归宿=source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1 + source/project/_common/custom/.governance/skill-promotion-policy.json
风险等级=medium
执行模式=direct_fix

任务理解快照=目标: 避免同类签名重复晋升多个 custom-auto 技能; 非目标: 清理所有历史 imports 变更; 验收: mojibake 只保留一个 auto 技能且 smoke 不再晋升
依据=用户反馈 overrides 出现 4 个自定义技能且作用重复，怀疑创建逻辑缺陷
根因=脚本按完整 issue_signature 分组，`...-a/-b/-c/-d` 被当作不同问题；且未过滤 smoke 签名

修复动作=新增签名族归并函数 `Get-SignatureFamily`，默认规则 `^(.*-\d{8})-[a-z]$`
修复动作=新增排除函数 `Test-SignatureExcluded`，默认排除 `autopilot-utf8-smoke`
修复动作=registry 增加 `signature_variants` 字段，技能内容写入 variants
修复动作=策略模板新增 `collapse_suffix_pattern` 与 `exclude_signature_patterns`

命令=governance-kit install safe; governance-kit promote-skill-candidates -AsJson; skills-manager doctor --strict; skills-manager 构建生效
关键输出=promote 结果 grouped_signature_count=1, promoted_count=1, issue_signature=pwsh-encoding-mojibake-loop-20260411
关键输出=skills-manager overrides 仅保留 custom-auto-pwsh-encoding-mojibake-l-a9b049cd + custom-windows-encoding-guard
关键输出=skills-manager 构建生效通过（Result: PASS with WARN）

清理动作=删除 skills-manager/overrides 下旧目录 custom-auto-autopilot-utf8-smoke-20260411, custom-auto-pwsh-encoding-mojibake-l-7453de8b, custom-auto-pwsh-encoding-mojibake-l-d3bde4eb
回滚动作=git -C E:/CODE/governance-kit checkout -- source/project/_common/custom/scripts/governance/promote-skill-candidates.ps1 source/project/_common/custom/.governance/skill-promotion-policy.json
回滚动作=git -C E:/CODE/skills-manager checkout -- overrides .governance/skill-candidates

learning_points_3=1) 自动晋升应基于问题族而非原始签名 2) smoke 事件必须显式过滤 3) registry 不存在会导致重复再生成
open_questions=是否将旧目录自动回收逻辑内建到 promote 脚本（当前仍为外层清理）
