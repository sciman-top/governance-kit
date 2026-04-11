# 全局用户级与项目级协同：最终建议结构表（A 方案，无软链接）

## 1) 最终建议结构表

| 层级 | Source of Truth（本仓） | 目标落点 | 分发方式 | 职责边界 |
|---|---|---|---|---|
| 全局用户级 | `source/global/*` | `~/.codex/AGENTS.md` `~/.claude/CLAUDE.md` `~/.gemini/GEMINI.md` | 复制分发（install/sync） | 只定义跨仓通用协作语义与入口约束，不含仓库私有路径/命令 |
| 项目级 | `source/project/<RepoName>/*` | `<RepoRoot>/AGENTS.md` `<RepoRoot>/CLAUDE.md` `<RepoRoot>/GEMINI.md` 及仓内治理文件 | 复制分发（install/sync） | 定义该仓 WHERE/HOW：门禁命令、证据路径、回滚入口、仓库策略 |
| 共享模板级 | `source/project/_common/*` | 分发到多个仓的项目级文件（仍是仓内文件） | 复制分发（install/sync） | 复用模板，不直接提升为全局用户级；仅作为项目级输入资产 |

## 2) 为什么不采用软链接（本方案结论）

- 不采用软链接作为默认最佳实践。
- 原因：
  - 跨平台稳定性与权限行为不一致（Windows/CI/容器环境差异大）。
  - 目标仓可移植性下降，迁移与打包时易出现悬挂链接。
  - 审计与回滚证据链更难定位真实内容来源。
- 结论：采用“集中源 + 显式映射 + 复制分发 + 强校验”的治理模型。

## 3) 边界与归类规范草案（判定标准）

### 3.1 硬判定

1. 只要依赖仓库上下文（repo path/script/workflow/evidence/rollback），必须归类为`项目级`。  
2. 只定义跨仓通用协作语义，且不依赖任何仓库上下文，才可归类为`全局用户级`。  
3. 可复用但仍作为源模板维护的资产，归类为`共享模板级`。  
4. 无法明确时，默认降级为`项目级`（宁可不提升到全局）。

### 3.2 判定树（执行顺序）

1. 是否引用 repo 路径、repo 脚本、repo 工作流、repo 证据/回滚？  
   - 是 -> `项目级`  
   - 否 -> 下一步  
2. 是否仅表达跨仓通用语义，不携带仓私有执行细节？  
   - 是 -> `全局用户级`  
   - 否 -> 下一步  
3. 是否为可复用模板源文件？  
   - 是 -> `共享模板级`  
   - 否 -> `项目级`

## 4) 强化/强制机制（已落地口径）

### 4.1 数据与配置约束

- `config/targets.json`：每条目标必须声明 `boundary_class`。  
- `boundary_class` 仅允许：`global-user | project | shared-template`。  
- `config/project-rule-policy.json`：`defaults.enforce_boundary_class=true`。

### 4.2 执行链强校验

- `scripts/install.ps1`：安装前校验边界映射与归类一致性，不合法即阻断。  
- `scripts/validate-config.ps1`：配置层校验 `boundary_class` 必填/合法/与 source 层级匹配。  
- `scripts/verify.ps1`：分发后验收目标落点与边界一致性。  
- `scripts/add-repo.ps1`：新增目标仓时默认带入边界分类字段，避免“先污染后治理”。

### 4.3 新目标仓“从第一天就正确”

新增仓时必须遵循：

1. 先装全局用户级入口文件；  
2. 再装该仓项目级 AGENTS/CLAUDE/GEMINI；  
3. 再装仓内治理脚本/工作流/策略；  
4. 最后通过 `build -> test -> contract/invariant -> hotspot` 后才视为可用。

## 5) 反重叠/反缺失清单（改动前必查）

- 本次改动是否把仓私有执行逻辑错误上提到全局？  
- 本次改动是否让全局与项目出现同义重复定义？  
- 本次改动是否让某一职责既不在全局也不在项目（功能缺失）？  
- 本次改动是否更新了 `targets/policy/verify` 三处一致性？  
- 本次改动是否保留证据与回滚入口？

以上任一项失败，则不得分发/安装到目标仓。
