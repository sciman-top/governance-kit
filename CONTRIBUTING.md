# Contributing to governance-kit

感谢你参与 `governance-kit`。

## Scope
本仓用于治理规则与分发自动化，不接收与治理无关的功能需求。

## Before You Start
1. 阅读仓库根 `AGENTS.md`（项目级规则）。
2. 先确认变更归宿是否在 `source/`、`config/`、`scripts/`、`tests/` 中。
3. 变更尽量小步提交，保持可验证、可回滚。

## Local Verification (Required Order)
按固定顺序执行：

```powershell
powershell -File scripts/verify-kit.ps1
powershell -File tests/governance-kit.optimization.tests.ps1
powershell -File scripts/validate-config.ps1
powershell -File scripts/verify.ps1
powershell -File scripts/doctor.ps1
```

如果仅文档变更且门禁脚本客观不适用，可记录 `gate_na`，并提供替代验证证据。

## Pull Request
1. 使用仓库内 PR 模板（`.github/pull_request_template.md`）。
2. 在 PR 中附上：变更目的、风险等级、验证命令与关键输出。
3. 涉及配置结构变更时，必须补充回滚说明。

## Commit Message
建议遵循仓内模板（`.gitmessage.txt`），提交内容聚焦单一目标。

## Security
请勿在仓库提交密钥、令牌、私有凭据。安全问题请走 [SECURITY.md](SECURITY.md) 私下渠道。
