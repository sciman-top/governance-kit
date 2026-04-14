# 20260414 skills-manager doctor strict 性能日志敏感性修复

- 规则 ID: skills-manager-doctor-strict-perf-20260414
- 风险等级: 中
- issue_id: skills-manager-doctor-strict-perf-sensitivity

## 1) 问题
- 现象: `skills.ps1 doctor --strict --threshold-ms 8000` 会被历史 `build.log` 的性能异常（例如 `sync_mcp`）阻断。
- 影响: contract/invariant 门禁存在“历史样本噪声导致当前任务失败”的风险。

## 2) 根因
- `src/Commands/Doctor.ps1` 中 strict 判定条件把 `performance.anomalies` 与配置风险同级阻断：
  - `strict && (risks || performance.anomalies)`。

## 3) 修复
- 文件：
  - `E:/CODE/skills-manager/src/Commands/Doctor.ps1`
  - `E:/CODE/skills-manager/src/Commands/Utils.ps1`
- 改动：
  - 新增参数 `--strict-perf`（默认 `false`）。
  - `--strict` 默认仅对配置风险阻断；性能异常仅告警。
  - 仅当同时指定 `--strict --strict-perf` 时，性能异常才参与阻断。
  - 帮助文本新增 `--strict-perf` 说明。
  - 重新构建生成 `E:/CODE/skills-manager/skills.ps1`。

## 4) 验证命令与结果
- 构建：
  - `powershell -File E:/CODE/skills-manager/build.ps1`
  - 结果: 通过
- 行为验证（注入 `sync_mcp` 异常样本）：
  - `powershell -File skills.ps1 doctor --strict --threshold-ms 8000`
    - 结果: 通过（仅告警，退出码 0）
  - `powershell -File skills.ps1 doctor --strict --strict-perf --threshold-ms 8000`
    - 结果: 阻断（退出码 2）
- 门禁复验（skills-manager）：
  - `build -> 发现 -> doctor --strict --threshold-ms 8000 -> 构建生效`
  - 结果: 全通过

## 5) 回滚
- `git -C E:/CODE/skills-manager restore src/Commands/Doctor.ps1 src/Commands/Utils.ps1 skills.ps1`

## 6) learning_points_3
- strict 门禁应优先覆盖“当前变更强相关风险”，历史趋势更适合作为告警信号。
- 性能阻断建议显式开关化，避免与配置风险耦合。
- 规则仓协作场景下，需同时保留“默认稳态”与“严格压测”两种门禁模式。
