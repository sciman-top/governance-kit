规则ID=GK-RELEASE-POLICY-FREE-SIGNING-20260409-001
规则版本=3.83
兼容窗口(观察期/强制期)=observe
影响模块=templates/release-profile.template.json; scripts/suggest-release-profile.ps1; scripts/verify-release-profile.ps1; source/project/*/custom/.governance/release-profile.json; tests/repo-governance-hub.optimization.tests.ps1
当前落点=E:/CODE/repo-governance-hub
目标归宿=三目标仓 release-profile 策略统一：支持 installer/portable 与 online/offline 组合；禁止付费签名
迁移批次=2026-04-09-release-policy-matrix
风险等级=low
是否豁免(Waiver)=no
豁免责任人=
豁免到期=
豁免回收计划=
任务理解快照=目标: 发布可支持安装版/非安装版、离线包/非离线包并禁止付费签名; 非目标: 引入商业签名服务或破坏现有发布脚本; 验收标准: verify-release-profile 与 coverage 通过、全链路门禁 GREEN
术语解释点=distribution_forms/network_modes: 分别表达“安装形态”和“联网形态”的发布策略维度；常见误解是把 channel 当成全部维度，本次拆分为双维度避免语义混杂
可观测信号=release-profile 增加 policies.signing.allow_paid_signing=false; packaging 增加 distribution_forms + network_modes
排障路径=新增 suggest/verify 后测试失败 -> 修复 suggest-release-profile AsJson 转换缺陷 -> 调整 Pester 断言为布尔包含判断 -> 全量测试通过
未确认假设与纠偏结论=未确认: 新策略会否对无发布信号仓造成阻断; 纠偏: 对 release_enabled=false 仓默认 portable+online、channels=['none']，coverage 全通过
执行命令=powershell -File scripts/install.ps1 -Mode safe; powershell -File tests/repo-governance-hub.optimization.tests.ps1; powershell -File scripts/verify-release-profile.ps1 -RepoPath E:/CODE/ClassroomToolkit; powershell -File scripts/check-release-profile-coverage.ps1; powershell -File scripts/verify-kit.ps1; powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1; powershell -File scripts/doctor.ps1
验证证据=新增测试 verify-release-profile rejects paid signing mode + suggest-release-profile emits packaging forms and no-paid-signing policy 通过；release-profile coverage PASS；verify ok=106 fail=0；doctor HEALTH=GREEN
供应链安全扫描=N/A (policy/script/test/document changes)
发布后验证(指标/阈值/窗口)=每次 release-profile 变更后 coverage=PASS；付费签名策略违例应被 verify-release-profile 阻断
数据变更治理(迁移/回填/回滚)=无数据迁移；回滚为脚本/模板/profile 文本回退
回滚动作=git revert 本批策略与脚本变更；重新执行 install -Mode safe 恢复目标仓

learning_points_3=发布策略应拆分形态维度避免单字段过载; 免费约束需要脚本级硬校验而非仅文档约定; suggest 与 verify 必须配套测试避免策略漂移
reusable_checklist=模板加字段->suggest生成->verify强校验->profile回灌->安装分发->coverage+全门禁
open_questions=是否后续增加“free-signing mode allowlist”（如 sigstore-keyless/self-signed）的细化枚举
