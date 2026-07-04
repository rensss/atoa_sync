# 代理工作说明

本文件是本仓库所有编码代理的统一入口。项目状态、架构约束、风险、
路线图和交接信息维护在 `PROJECT_MEMORY/` 中。

事实来源分层：本文件（`AGENTS.md`）是工作规则与启动流程的事实来源；仓库真实
状态以当前检出的源码、测试结果和 Git 历史为准；长期项目记忆以 `PROJECT_MEMORY/`
为准，其目录职责与结构说明见 `PROJECT_MEMORY/README.md`。

## 启动顺序

在制定计划或编辑文件前，必须按顺序读取：

1. `PROJECT_MEMORY/00_PROJECT_STATUS.md`
2. `PROJECT_MEMORY/HANDOFF.md`
3. `PROJECT_MEMORY/01_ARCHITECTURE.md`
4. `PROJECT_MEMORY/02_RISK_REGISTER.md`
5. `PROJECT_MEMORY/03_REFACTOR_ROADMAP.md`
6. `PROJECT_MEMORY/04_DECISION_LOG.md`
7. 相关平台 README，以及适用的里程碑、批次或冻结记录。

不能把计划文档当作完成证明。必须从当前检出的分支、源码、测试结果和 Git
历史确认真实状态。

## 项目概况

Android Sync 用于把 Android 设备上的照片和视频传输到 macOS，或传输到局域网
内兼容 HTTP/WebDAV 的目标。

## 仓库结构

- `android/`：无第三方依赖的 Android 应用、测试、构建脚本和浏览器 UI 原型。
- `macos/`：原生 Swift 接收端、媒体库、测试、资源和打包脚本。
- `docs/`：共享设计、计划和规格文档。
- `releases/`：版本化发布产物和历史发布说明。
- `PROJECT_MEMORY/`：可长期维护的项目记忆。
- `dist/` 和各平台构建目录：生成产物。

平台专属代码必须留在对应平台目录内。不要把 Android 或 macOS 实现文件重新放回
仓库根目录。

## PROJECT_MEMORY 结构

`PROJECT_MEMORY/` 只记录可验证的项目记忆，按用途分层。各核心文件与 `batches/`、
`milestones/`、`freezes/` 子目录的职责，以 `PROJECT_MEMORY/README.md` 为准，此处
不再重复，以免两处描述漂移。下面的更新规则约定"何时必须更新哪个文件"。

## PROJECT_MEMORY 更新规则

- 只写能从仓库、命令输出、分支、提交或明确人工检查中验证的事实。
- 引用提交或分支指针前，必须用 `git rev-parse` 等命令核对。指针是记录时的仓库
  快照；同名分支只记录其 tip，集成或合并提交单独标注，避免同一分支出现多个相互
  矛盾的 SHA。
- 涉及基线、版本、主分支、开放事项、验证状态或下一步时，必须更新
  `00_PROJECT_STATUS.md` 和 `HANDOFF.md`。
- 涉及架构边界、协议、存储布局、并发模型或平台职责时，必须更新
  `01_ARCHITECTURE.md`，必要时新增 ADR。
- 涉及并发、网络、存储、生命周期、媒体解码、manifest、删除或安全暴露时，
  必须检查 `02_RISK_REGISTER.md`，并在批次记录中列出相关风险 ID。
- 改变受保护决策必须先获得用户明确批准，再在 `04_DECISION_LOG.md` 追加一个
  supersede 旧决策的新 ADR；不要直接改写历史 ADR。
- 非平凡实现批次必须在 `PROJECT_MEMORY/batches/` 下记录，文件名使用
  `YYYY-MM-DD-BNN-short-name.md`。
- 路线图阶段达到进入或退出标准时，必须在 `PROJECT_MEMORY/milestones/` 记录
  证据，并引用验证提交或分支。
- 冻结记录是历史快照。不要编辑冻结记录来描述后续行为；需要变化时新增批次、
  里程碑证据或 ADR。
- 不要仅因计划存在、分支存在或代码已合并就宣称风险、阶段或里程碑关闭。关闭
  必须有可复现验证证据和提交引用。

## 工作准则

- 修改平台行为前，先读对应平台 README。
- 遵循现有代码模式和脚本；没有明确必要性时不要引入新的构建系统或依赖。
- 保持改动聚焦，不覆盖无关本地工作。
- 不手工编辑生成产物，也不要提交忽略文件、密钥、签名材料或本地配置。
- 命令、布局、配置或用户可见行为改变时，同步更新文档。
- 文档默认使用中文撰写；第三方命令、API 名称、代码符号、路径和提交/分支标识保留
  原文，不翻译。
- 每个实施批次应可单独审查、验证和回滚。

## 验证

按改动范围运行相关检查：

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh
```

开发过程中可以先运行最小充分检查；完成前应运行受影响平台的测试套件。无法运行
或跳过的检查必须明确说明，不能表述为已通过。

## 完成标准

开发任务只有同时满足以下条件才算完成：

- 请求的行为已经实现。
- 相关测试或构建通过；无法执行的检查已明确说明。
- 新风险、决策和非平凡批次已记录。
- 状态和交接文档反映当前仓库状态。
- 生成文件、密钥和本地配置未进入变更。
