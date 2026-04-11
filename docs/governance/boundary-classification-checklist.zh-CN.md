# 边界判级清单（Global User vs Project vs Shared Template）

## 目标

用统一的 Yes/No 规则，在新增或调整 `config/targets.json` 条目时，快速判断应归属：

- `global-user`
- `project`
- `shared-template`

并保证“全局与项目级 1+1>2、无重叠、无缺失”。

## 三层职责速记

- `global-user`：只放用户目录入口文件，只表达跨仓恒定语义，不承载仓内执行动作。
- `project`：只要依赖 repo 事实、repo 路径、repo 流程、repo 回滚，就归项目级。
- `shared-template`：很多仓可复用，但仍然落在仓内目录的能力包；它不是用户级。

一句话口径：

- 判断标准先看“是否依赖仓上下文”，不是先看“能否复用”。

## 10 条 Yes/No 判定

按顺序判断，命中即停止：

1. 是否依赖仓库路径、仓库根目录或仓库命名？
   - Yes -> `project`
2. 是否依赖仓库脚本、工作流、门禁、回滚、证据路径？
   - Yes -> `project`
3. 是否安装后必须在某个 repo 内执行才有意义？
   - Yes -> `project`
4. 是否会因不同 repo 而需要不同值或不同内容？
   - Yes -> `project`
5. 是否属于 `source/project/*/custom/*` 源产物？
   - Yes -> `project`（若源位于 `source/project/_common/custom/*` 则 `shared-template`）
6. 是否只表达跨仓通用协作语义，不依赖任何 repo 事实？
   - Yes -> 继续第 7 条
7. 目标路径是否是允许的用户级入口（`.codex/.claude/.gemini` 对应主规则文件）？
   - Yes -> `global-user`
   - No -> `project`（防止“语义全局但落点错误”）
8. 是否是 `source/project/_common/*` 的复用模板源？
   - Yes -> `shared-template`
9. 是否无法证明为纯全局语义？
   - Yes -> `project`（默认保守，优先保证仓内可审计与可回滚）
10. 是否存在跨层冲突风险（全局文件承载项目执行语义）？
   - Yes -> 回退到 `project` 或 `shared-template`

## 4 个关键判定问题

新增任何组件时，先问这 4 个问题：

1. 它脱离具体 repo 后还能成立吗？
   - 不能 -> `project` / `shared-template`
2. 它最终落在用户目录还是仓目录？
   - 用户目录才可能是 `global-user`
3. 它表达的是统一语义，还是仓内执行动作？
   - 仓内执行动作 -> `project` / `shared-template`
4. 它是单仓专属，还是多仓复用？
   - 多仓复用但仍落仓内 -> `shared-template`

## 常见误判

- “很多仓都用，所以应放全局”
  - 错。多仓复用但落在仓内，仍是 `shared-template`。
- “它是治理能力，所以应放全局”
  - 错。治理能力分“统一语义”和“仓内落地”两层。
- “模板文档不执行，所以能放全局”
  - 错。服务于仓内发布、门禁、证据、回滚的模板，仍然是项目级。

## 默认回退规则

当证据不足、归类模糊、存在跨层责任漂移风险时：

- 默认回退到 `project`
- 若源位于 `source/project/_common/` 且目标仍为仓内路径，则回退到 `shared-template`

原因：

- 宁可保守地留在仓内，也不要错误上提到 `global-user`，以免破坏审计、回滚和职责边界。

## 自动校验命令

执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-boundary-classification.ps1
```

JSON 输出：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-boundary-classification.ps1 -AsJson
```

显示全部条目（含 PASS）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-boundary-classification.ps1 -ShowPassItems
```

## 脚本判定规则来源

- 策略文件：`config/boundary-classification-policy.json`
- 主数据：`config/targets.json`
- Repo 根列表：`config/repositories.json`
- 公共判级函数：`scripts/lib/common.ps1`

## 违规信号说明（reason_codes）

- `missing_boundary_class`: 条目缺少 `boundary_class`
- `invalid_boundary_class`: `boundary_class` 不在允许值集合
- `boundary_class_mismatch`: 与 source 层级推导值不一致
- `cross_layer_mapping_violation`: source/target 跨层映射违规
- `global_target_not_whitelisted`: 标记为全局但目标不在允许用户级路径

## 推荐接入

在你现有 `contract/invariant` 阶段增加该检查：

```powershell
powershell -File scripts/validate-config.ps1;
powershell -File scripts/verify.ps1;
powershell -File scripts/governance/check-boundary-classification.ps1
```

这样可以在“新增 target 映射”时即时阻断边界漂移。
