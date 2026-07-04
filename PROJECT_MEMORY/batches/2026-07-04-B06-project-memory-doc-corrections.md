# B06：项目记忆文档订正

日期：2026-07-04

## 目标

修正项目记忆中与真实 Git 状态不一致的指针，并让批次记录符合自身模板要求，
使 `PROJECT_MEMORY/` 的文档可从仓库状态逐条验证。

## 范围

- `00_PROJECT_STATUS.md`：整理基线段的主线提交指针，补记 `main` 最近提交
  `5f6fd33`（B05 的后续记录提交），并消除同名分支 `codex/agent-governance`
  两处 SHA 的歧义（tip `a07593a`，其上集成合并提交 `23b09d5`）。
- `HANDOFF.md`：更新日期与“最新本地工作”，反映本批次。
- 为 `2026-06-11-B01`、`2026-06-22-B03`、`2026-06-22-B04` 三个批次记录补齐
  `PROJECT_MEMORY/batches/TEMPLATE.md` 与 `batches/README.md` 要求的“不变量”段。

## 非目标

- 不修改应用源码、构建脚本或运行时行为。
- 不新增或关闭产品风险，也不改变受保护 ADR。
- 不改写历史批次、里程碑或冻结记录的既有事实（版本号、提交号、验证结论保持原意）。
- 不补建 Phase 2/Phase 3 里程碑文件（作为后续事项，见下）。

## 风险和决策

- 相关决策：ADR-007（批次治理式演进）。
- 本批次只修改文档，不触及风险登记中的并发、网络、存储、生命周期、媒体解码或
  删除行为。

## 不变量

- 既有版本号、分支名、提交号、验证命令和验证结果的原意保持不变。
- 历史批次、里程碑和冻结记录仍作为历史证据，未被改写为新的实现状态。
- 补充的指针仅记录记录时的仓库快照；不宣称任何未验证的实现或验收状态。

## 验证

```bash
git diff --check
for r in main codex/agent-governance codex/stability-macos-ux; do git rev-parse --short "$r"; done
for f in PROJECT_MEMORY/batches/2026-*.md; do grep -q "^## 不变量" "$f" || echo "缺: $f"; done
```

`git diff --check` 通过。分支/HEAD 解析确认 `main` 位于 `5f6fd33`、
`codex/agent-governance` 位于 `a07593a`、`codex/stability-macos-ux` 位于 `cbf31db`，
与订正后的指针一致。不变量段扫描无输出，确认全部批次记录均含“不变量”段。未运行
平台测试，因为本批次只修改 `PROJECT_MEMORY/` 内的 Markdown 文档。

## 回滚

回滚本批次的 Markdown 改动即可恢复订正前的指针与批次记录结构。不影响应用源码、
构建产物或用户数据。

## 结果

- 提交：待本批次落盘后回填。
- 结果：主线提交与分支指针已与真实 Git 状态对齐；B01、B03、B04 批次记录补齐
  “不变量”段，五个批次记录现均符合模板。
- 后续：为路线图 Phase 2（macOS 接收端正确性）与 Phase 3（macOS UX）补建 M2/M3
  里程碑文件，承接尚未完成的 macOS 最终视觉/交互 QA 退出标准；此项超出本批次范围。
