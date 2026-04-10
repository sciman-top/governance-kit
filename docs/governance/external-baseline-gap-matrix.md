# 外部基线对标与差距矩阵（governance-kit）

更新时间：2026-04-11  
适用范围：`E:/CODE/governance-kit` 与当前目标仓（`ClassroomToolkit`、`skills-manager`、`governance-kit`）  
状态：Draft v1（用于 `observe -> enforce` 迁移执行）

## 1. 目标与非目标
- 目标：将当前“高成熟 observe 阶段”收敛为“可审计的 enforce 阶段”。
- 目标：将外部主流基线映射到本仓已有门禁、策略、分发与证据链路。
- 非目标：一次性引入所有新工具并立即强制阻断。

## 2. 外部基线对标矩阵
| 领域 | 外部基线 | 当前状态 | 差距判定 | 本仓落地动作 |
|---|---|---|---|---|
| 分支保护与必过检查 | GitHub Protected Branch + Required Status Checks | 已有 `.github/workflows/quality-gates.yml` + hooks + `verify/doctor` | 部分达成 | 核心门禁改为“缺失即失败”，仅保留有限 `gate_na` 白名单 |
| 供应链分级 | SLSA（当前公开规范已到 1.2 体系） | 已有 release/profile/verify 机制 | 部分达成 | 建立 `SLSA-level-target` 与证据映射字段 |
| 开源安全评分 | OpenSSF Scorecard | 未见仓内持续评分入口 | 未达成 | 增加周期扫描并汇总入 doctor/metrics |
| SBOM 标准化 | SPDX / CycloneDX | 有供应链检查入口，但未固化统一 SBOM 合规门禁 | 部分达成 | 统一 SBOM 格式（建议 CycloneDX）+ schema 校验 |
| 安全开发框架 | NIST SSDF (SP 800-218) | policy-as-code 已存在 | 部分达成 | 新增 `SSDF -> repo action` 映射清单并定期复核 |
| 可观测性基线 | OpenTelemetry（logs/metrics/traces） | 策略中 observability=required | 部分达成 | 增加“最小可观测字段”自动检查 |
| 渐进发布 | Progressive Delivery | policy=recommended | 部分达成 | 在 release-profile 增加灰度/回滚验收字段 |
| 实践栈治理 | SDD/TDD/ATDD/Contract/Harness/Policy/Hook | `check-practice-stack` 已 `PASS` 且三仓 100 分 | 达成（observe） | 进入 enforce 试点并观察误报率 |

## 3. 当前能力快照（本仓）
- `check-practice-stack`：`status=PASS`，`average_score=100`，覆盖 3 个仓。
- `doctor -AsJson`：`health=GREEN`。
- `verify.ps1`：目标映射校验已覆盖多仓分发（当前 133 项映射验证通过）。
- hooks：`pre-commit/pre-push` 已接入阻断式 verify（按 staged/outgoing 范围执行）。

## 4. 两周迁移计划（2026-04-11 ~ 2026-04-24）

### 4.1 Week 1（2026-04-11 ~ 2026-04-17）：补齐基线映射，不立刻阻断
1. 新增 `SSDF/SLSA/SBOM/Scorecard` 的策略字段与证据字段（先 `warn/advisory`）。
2. 在 `scripts/quality` 或 `scripts/governance` 增加占位检查脚本与统一输出格式。
3. 在 `docs/governance/metrics-template.md` 扩展对应指标项（可空值但必须有字段）。
4. 在 1 个仓（建议 `governance-kit`）运行 3 次周期验证，统计误报率。

验收标准：
1. 新增字段均能被 `verify-kit + validate-config + doctor` 正常读取。
2. 新检查“可运行、可产证据、可被聚合”，但不阻断发布。
3. 输出一份误报/漏报记录（至少 3 次样本）。

### 4.2 Week 2（2026-04-18 ~ 2026-04-24）：从 observe 切换到 enforce（试点）
1. 将核心门禁从“存在则跑”提升为“缺失即失败”（限试点仓）。
2. 把 `SLSA/SBOM/Scorecard/SSDF` 中至少 2 条切换为阻断级。
3. 对 `gate_na` 增加到期时间与回收计划；过期未回收则阻断。
4. 保持回滚入口不变：`scripts/restore.ps1 + backups/<timestamp>/`。

验收标准：
1. 试点仓在连续 3 个周期内通过率 >= 95%。
2. 高严重误报为 0，阻断后可在单次修复周期内恢复。
3. 形成可复制模板并推广到其余目标仓。

## 5. enforce 迁移检查清单（可直接执行）
1. 运行门禁基线：`powershell -File scripts/verify-kit.ps1`
2. 运行测试门禁：`powershell -File tests/governance-kit.optimization.tests.ps1`
3. 运行契约门禁：`powershell -File scripts/validate-config.ps1; powershell -File scripts/verify.ps1`
4. 运行热点门禁：`powershell -File scripts/doctor.ps1`
5. 运行实践栈：`powershell -File scripts/governance/check-practice-stack.ps1 -RepoRoot . -AsJson`
6. 运行周期触发器：`powershell -File scripts/governance/check-update-triggers.ps1 -RepoRoot .`
7. 若任一步失败：先修根因，再按固定顺序重跑整链路。

## 6. 风险与回滚
- 风险1：阻断门槛提升导致短期失败率上升。  
  - 缓解：先单仓试点，保留 observe 窗口与 waiver 到期管理。
- 风险2：新增检查引入误报。  
  - 缓解：先 advisory 采样，再升级为 enforce。
- 回滚：恢复策略文件与脚本到上一个已验证版本，执行 `scripts/restore.ps1` 并重跑四段门禁。

## 7. 参考基线（官方链接）
- GitHub Protected Branches: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- SLSA: https://slsa.dev/spec/v1.0/whats-new
- OpenSSF Scorecard: https://github.com/ossf/scorecard
- NIST SSDF SP 800-218: https://csrc.nist.gov/pubs/sp/800/218/final
- SPDX: https://spdx.dev/use/specifications/
- CycloneDX: https://cyclonedx.org/specification/overview/
- OpenTelemetry Spec: https://opentelemetry.io/docs/specs/otel/
