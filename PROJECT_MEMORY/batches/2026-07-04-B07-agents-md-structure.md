# B07：AGENTS.md 结构与内容优化

日期：2026-07-04

## 目标

优化统一代理入口 `AGENTS.md` 的结构与内容：消除与 `PROJECT_MEMORY/README.md`
的重复描述，沉淀提交/分支引用规范，并把既有语言约定与事实来源层级升为明文规则。

## 范围

- `AGENTS.md`，四处改动：
  1. 开头新增“事实来源分层”段，厘清 `AGENTS.md`、源码/Git、`PROJECT_MEMORY/`
     三者各自的事实来源角色。
  2. 将“PROJECT_MEMORY 文档结构”节的逐文件清单收敛为一段指向
     `PROJECT_MEMORY/README.md` 的说明，消除与 README 的重复。
  3. 在“PROJECT_MEMORY 更新规则”新增提交/分支引用规范（须 `git rev-parse` 核对、
     指针为快照、同名分支只记 tip）。
  4. 在“工作准则”新增文档语言约定（默认中文，代码符号/命令/提交标识保留原文）。
- `00_PROJECT_STATUS.md` 与 `HANDOFF.md`：记录本批次。

## 非目标

- 不修改应用源码、构建脚本或运行时行为。
- 不改动 `PROJECT_MEMORY/README.md` 的既有内容（它仍是目录职责的事实来源）。
- 不改变启动顺序、验证命令清单或完成标准的语义。
- 不新增或关闭产品风险，也不改变受保护 ADR。

## 风险和决策

- 相关决策：ADR-007（批次治理式演进）。
- 本批次只修改文档，不触及风险登记中的并发、网络、存储、生命周期、媒体解码或
  删除行为。

## 不变量

- `AGENTS.md` 的启动顺序、验证命令清单和完成标准语义保持不变。
- `PROJECT_MEMORY/README.md` 仍是核心文件与子目录职责的事实来源。
- 新增的语言约定与 B05 已确立的中文文档实践一致，不改变既有文档语言。
- 收敛重复描述后，AGENTS.md 未丢失任何原有约束，仅移除与 README 重复的清单。

## 验证

```bash
git diff --check
rg -n "PROJECT_MEMORY 文档结构" AGENTS.md
rg -n "PROJECT_MEMORY/README.md" AGENTS.md
rg -n "git rev-parse|默认使用中文|事实来源分层" AGENTS.md
```

`git diff --check` 通过。对“PROJECT_MEMORY 文档结构”的扫描无输出，确认重复清单已
移除；`PROJECT_MEMORY/README.md` 与三条新增规则的扫描均命中，确认改动在位。未运行
平台测试，因为本批次只修改 Markdown 文档。

## 回滚

回滚本批次对 `AGENTS.md` 及两份记录文档的改动即可恢复先前结构。不影响应用源码、
构建产物或用户数据。

## 结果

- 提交：待本批次落盘后回填。
- 结果：`AGENTS.md` 消除与 README 的重复、明确事实来源层级，并将提交/分支引用规范
  与文档语言约定升为明文规则。
- 后续：为路线图 Phase 2/Phase 3 补建 M2/M3 里程碑文件（承接 macOS 最终视觉/交互
  QA 退出标准），此项仍超出本批次范围。
