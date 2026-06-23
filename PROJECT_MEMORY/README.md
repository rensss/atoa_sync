# 项目记忆

本目录是 Android Sync 的长期技术记忆。它把已经验证的仓库状态与计划、假设和
历史背景分开记录。

## 阅读顺序

1. `00_PROJECT_STATUS.md`
2. `HANDOFF.md`
3. `01_ARCHITECTURE.md`
4. `02_RISK_REGISTER.md`
5. `03_REFACTOR_ROADMAP.md`
6. `04_DECISION_LOG.md`
7. `milestones/`、`batches/` 和 `freezes/` 中的相关文件

## 目录职责

- `00_PROJECT_STATUS.md`：当前基线、验证状态、开放事项和验证记录。
- `HANDOFF.md`：短交接，帮助下一位维护者快速继续。
- `01_ARCHITECTURE.md`：系统上下文、平台边界、协议、存储和并发模型。
- `02_RISK_REGISTER.md`：风险状态、控制措施和关闭证据。
- `03_REFACTOR_ROADMAP.md`：阶段路线图、范围边界和验收要求。
- `04_DECISION_LOG.md`：追加式 ADR 决策记录。
- `batches/`：非平凡实施批次记录。
- `milestones/`：路线图阶段的进入/退出标准和证据。
- `freezes/`：历史冻结基线。

## 更新规则

- 只写能从仓库或已记录命令验证的事实。
- 在相关位置记录日期、分支、提交和验证证据。
- 明确区分计划中、进行中、受阻和已完成的工作。
- 不重写历史 ADR 或冻结记录；需要变化时追加 supersede 记录。
- 保持 `HANDOFF.md` 足够短，便于每次任务开始时阅读。
