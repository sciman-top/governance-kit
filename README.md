# governance-kit

中文 | [English](README.en.md)

`governance-kit` 是一个面向多仓治理的唯一源目录（source-of-truth）仓库，用来维护全局/项目级规则，并按配置安全分发到目标仓。

它解决的不是“怎么写某一条规则”，而是“如何让规则、模板、钩子、CI、证据和回滚机制在多个仓库里持续一致地落地”。

## 仓库定位

- 统一维护全局规则源：`source/global/*`
- 统一维护项目级规则源：`source/project/<RepoName>/*`
- 通过 `config/*.json` 管理目标映射、灰度策略、白名单和定制文件
- 通过 `scripts/*.ps1` 完成安装、校验、回灌、审计、回滚和闭环执行

## 适用场景

- 需要给多个仓库分发统一的 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`
- 需要把治理模板、hooks、CI 入口、证据模板和 Git 配置一起标准化
- 需要在“试改目标仓 -> 回灌唯一源 -> 再分发复验”的流程里保持可追溯
- 需要强制固定门禁顺序：`build -> test -> contract/invariant -> hotspot`

## 核心能力

- 一键接入新仓：自动补齐配置、模板、hooks 和规则分发
- 一键闭环执行：安装、分析、优化、回灌、再分发、doctor 复验
- 规则灰度治理：支持 observe / enforce、waiver 检查和 planned date
- 证据与回滚：所有关键操作都有备份目录、证据模板和恢复脚本
- 项目级定制文件分发：通过 `config/project-custom-files.json` 管理非三规则文件
- 真实仓门禁编排：脚本只负责编排与输出失败上下文，修复由当前 AI 会话代理接管

## 快速开始

推荐只使用一个对外入口：

```powershell
powershell -File E:\CODE\governance-kit\scripts\install-full-stack.ps1 -RepoPath E:\CODE\NewRepo -Mode safe
```

预演模式：

```powershell
powershell -File E:\CODE\governance-kit\scripts\install-full-stack.ps1 -RepoPath E:\CODE\NewRepo -Mode plan
```

## 标准工作流

### 1. 接入或重装目标仓

```powershell
powershell -File E:\CODE\governance-kit\scripts\install-full-stack.ps1 -RepoPath E:\CODE\TargetRepo -Mode safe
```

默认流程：

`bootstrap-repo -> run-project-governance-cycle -> target-autopilot dry-run -> doctor`

### 2. 仅执行项目级规则闭环

```powershell
powershell -File E:\CODE\governance-kit\scripts\run-project-governance-cycle.ps1 -RepoPath E:\CODE\TargetRepo -RepoName TargetRepo -Mode safe
```

### 3. 仅回灌目标仓项目规则到唯一源

```powershell
powershell -File E:\CODE\governance-kit\scripts\backflow-project-rules.ps1 -RepoPath E:\CODE\TargetRepo -RepoName TargetRepo -Mode safe
```

## 关键目录

- `source/global/`: 全局用户级规则源
- `source/project/`: 项目级规则源与仓库定制分发内容
- `source/template/project/`: 新仓默认项目级模板
- `config/targets.json`: `source -> target` 分发映射
- `config/project-rule-policy.json`: 项目级规则白名单、自治边界和阻断策略
- `config/project-custom-files.json`: 项目级定制文件清单
- `scripts/`: 安装、校验、回灌、审计、回滚、门禁编排脚本
- `tests/`: 回归和防退化测试
- `docs/change-evidence/`: 变更证据
- `backups/`: 运行时备份快照，仅作为本地回滚证据，不应推送到远端

## 推荐命令

健康检查：

```powershell
powershell -File scripts\doctor.ps1
```

一致性校验：

```powershell
powershell -File scripts\verify.ps1
```

配置结构校验：

```powershell
powershell -File scripts\validate-config.ps1
```

治理仓完整性校验：

```powershell
powershell -File scripts\verify-kit.ps1
```

## 固定门禁顺序

本仓库固定使用以下顺序，不能跳序：

1. `build`: `powershell -File scripts/verify-kit.ps1`
2. `test`: `powershell -File tests/governance-kit.optimization.tests.ps1`
3. `contract/invariant`: `powershell -File scripts/validate-config.ps1` 然后 `powershell -File scripts/verify.ps1`
4. `hotspot`: `powershell -File scripts/doctor.ps1`

如果仅纯文档/注释/排版调整且脚本门禁客观不适用，必须按仓库规则记录 `gate_na`，并提供替代验证证据。

## 不应推送到远端的内容

以下内容属于本地运行态、IDE/agent 专用配置或临时产物，不应进入 Git 历史：

- `backups/`: 安装、回灌、清理操作生成的备份快照
- `.locks/`: 运行中的锁目录
- `.codex/`、`.claude/`、`.gemini/`: agent 本地配置或缓存
- `.vscode/`、`.idea/` 等 IDE 专用配置
- `*.log`、`*.tmp`、`*.bak`、`tmp/`、`temp/`、`logs/` 等临时/调试残留

如果这些内容已经被 Git 跟踪，除了补 `.gitignore` 外，还需要把它们从 Git 索引中移除。

## 协作与安全

- 贡献说明：[`CONTRIBUTING.md`](CONTRIBUTING.md)
- 安全披露：[`SECURITY.md`](SECURITY.md)
- 变更历史：[`CHANGELOG.md`](CHANGELOG.md)
- PR 模板：[`.github/pull_request_template.md`](.github/pull_request_template.md)

## 相关文档

- [`docs/governance/agent-remediation-contract.md`](docs/governance/agent-remediation-contract.md)
- [`docs/governance/oneclick-target-state-matrix.md`](docs/governance/oneclick-target-state-matrix.md)
- [`docs/governance/rule-release-process.md`](docs/governance/rule-release-process.md)
- [`docs/governance-readiness.md`](docs/governance-readiness.md)

## 许可证

本项目采用 [`MIT`](LICENSE) 许可证。
