# B05：中文文档和项目记忆治理

日期：2026-06-22

## 目标

将仓库级文档、平台 README、发布说明、历史计划/设计文档和 `PROJECT_MEMORY/`
统一整理为中文，并在 `AGENTS.md` 中明确项目记忆结构和更新规则。

## 范围

- 中文化 `AGENTS.md`、`CLAUDE.md`、根 README、平台 README、原型 QA、发布说明和
  当前 `docs/superpowers/` 英文历史文档。
- 删除冗余的根目录 `CHANGELOG.md` 和 `CONTRIBUTING.md`，将贡献/验证入口收敛到
  `AGENTS.md`，将长期变更和验收记录收敛到 `PROJECT_MEMORY/`。
- 重新梳理 `PROJECT_MEMORY/` 的核心文档、索引、模板、里程碑、批次和冻结记录。
- 在 `AGENTS.md` 中增加 `PROJECT_MEMORY/` 文档结构和更新规则。
- 保持既有提交号、验证结论、风险状态和 ADR 语义不变。

## 非目标

- 不修改应用源码、构建脚本或运行时行为。
- 不新增或关闭产品风险。
- 不改变受保护 ADR 的决策内容。
- 不运行平台构建或测试。

## 风险和决策

- 相关决策：ADR-007。
- 本批次只修改文档，不触及运行时风险登记中的并发、网络、存储、生命周期或媒体解码
  行为。

## 不变量

- 既有版本号、分支名、提交号、验证命令和验证结果保持原意不变。
- 历史批次、里程碑和冻结记录仍作为历史证据，不被改写为新的实现状态。
- `CLAUDE.md` 继续以 `AGENTS.md` 为唯一事实来源。

## 验证

```bash
git diff --check
rg -n "AGENT\\.md|AGENTS\\.md|CLAUDE\\.md|PROJECT_MEMORY|Documentation|Update Rules|Reading Order" -g '*.md'
```

`git diff --check` 通过。引用扫描确认活跃文档指向 `AGENTS.md` 和
`PROJECT_MEMORY/`；单数 `AGENT.md` 只出现在扫描命令和 B01 历史批次描述中。

未运行平台测试，因为本批次只改 Markdown 文档，不改变应用源码或运行时行为。

## 回滚

回滚本批次的 Markdown 改动即可恢复英文文档结构。不会影响应用源码、构建产物或用户
数据。

## 结果

- 提交：待提交。
- 结果：文档已统一中文化，冗余根目录文档已移除，`AGENTS.md` 已明确
  PROJECT_MEMORY 结构和更新规则。
- 后续：未来新增文档应默认使用中文；引用第三方命令、API 名称和代码符号时保留原文。
