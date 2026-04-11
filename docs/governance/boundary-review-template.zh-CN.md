# 边界评审模板

用于新增或调整分发组件时，判断其应归属：

- `global-user`
- `project`
- `shared-template`

## 1. 基本信息

- 组件名称：
- Source 路径：
- Target 路径：
- 变更类型：新增 / 调整 / 重分类 / 下线
- 关联 repo：

## 2. 任务理解快照

- 目标：
- 非目标：
- 验收标准：
- 关键假设（已确认 / 未确认）：

## 3. 边界判定问题

1. 是否依赖 repo 路径、repo 名称、repo 目录结构？
   - Yes / No
2. 是否依赖 repo 脚本、CI、门禁、证据、发布、回滚？
   - Yes / No
3. 是否只能在目标仓内部执行后才有意义？
   - Yes / No
4. 是否会因不同 repo 而需要不同内容、值或 rollout？
   - Yes / No
5. 目标路径是否为允许的用户级入口（`.codex/.claude/.gemini` 主规则文件）？
   - Yes / No
6. Source 是否位于 `source/project/_common/`？
   - Yes / No
7. 它表达的是“统一语义”还是“仓内执行动作”？
   - 统一语义 / 仓内执行动作

## 4. 判定结果

- 推荐 `boundary_class`：
- 判定理由：
- 是否存在歧义：
- 若存在歧义，默认回退类：

## 5. 典型归类口径

- 满足任一 repo 依赖信号：`project`
- 不依赖 repo，且落点为用户目录入口文件：`global-user`
- 位于 `_common`，并分发到仓内目录：`shared-template`

## 6. 风险与回滚

- 风险等级：低 / 中 / 高
- 可能的职责漂移：
- 回滚入口：
- 回滚动作：

## 7. 验证

- 校验命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-boundary-classification.ps1
```

- 如需 JSON：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/governance/check-boundary-classification.ps1 -AsJson
```

## 8. 结论模板

```text
结论：归类为 <global-user/project/shared-template>
原因：<一句话说明“是否依赖 repo 上下文 + 最终落点”>
下一步：<更新 targets/policy/source，并执行 boundary classification check>
```
