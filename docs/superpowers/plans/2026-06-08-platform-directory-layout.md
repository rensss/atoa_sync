# 平台目录布局实施计划

> **给执行代理：** 必须使用 `superpowers:subagent-driven-development`（推荐）或
> `superpowers:executing-plans`，按任务逐项执行。所有步骤使用复选框跟踪。

**目标：** 将所有活跃 macOS 和 Android 项目文件拆分到各自平台目录，并移除废弃
Python 接收端。

**架构：** 仓库根目录保留共享产品元数据和发布产物。每个平台目录都可独立构建；
Android Web 原型归属 `android/prototype/`，Swift package 完全归属 `macos/`。

**技术栈：** Java/Android SDK 命令行工具、Swift 6/SwiftPM、Bash、静态
HTML/CSS/JavaScript。

---

### 任务 1：移动平台拥有的文件

**文件：**

- 移动：`Package.swift` 到 `macos/Package.swift`
- 移动：`script/build_and_run.sh` 到 `macos/build_and_run.sh`
- 移动：`index.html`、`app.js`、`styles.css`、`assets/` 和 `design-qa.md` 到
  `android/prototype/`
- 删除：`receiver/`

- [x] **步骤 1：移动 Android 浏览器原型**

创建 `android/prototype/`，把 HTML、CSS、JavaScript、图片资产和 QA 报告移入其中，
并保持相对资产 URL 不变。

- [x] **步骤 2：移动 macOS package 文件**

把 Swift package manifest 和应用打包脚本移入 `macos/`。

- [x] **步骤 3：移除 Python 接收端**

删除已跟踪的 Python 接收端源码、测试、文档和上传占位文件，因为原生 macOS 接收端
已取代它。

### 任务 2：修复构建和文档路径

**文件：**

- 修改：`macos/Package.swift`
- 修改：`macos/build_and_run.sh`
- 修改：`macos/README.md`
- 修改：`android/README.md`
- 修改：`.gitignore`
- 新建：`README.md`

- [x] **步骤 1：让 Swift package 自包含**

将 `macos/Package.swift` 中的 target 路径改为 `Sources/...` 和 `Tests/...`。

- [x] **步骤 2：更新 macOS 打包路径**

将脚本 package 目录设为 `macos/`，仓库目录设为其父目录，版本输入设为仓库
`VERSION`，图标输入设为 `macos/Resources/AppIcon.icns`，输出设为仓库 `dist/`。

- [x] **步骤 3：更新活跃文档**

记录使用 `--package-path macos` 的根目录命令，引导 Android 用户使用原生 macOS
接收端，并增加根项目地图。

- [x] **步骤 4：更新忽略规则**

移除 Python 接收端规则，并忽略 `macos/` 内的 SwiftPM 输出。

### 任务 3：验证两个平台

**文件：**

- 仅验证

- [x] **步骤 1：运行 Android 单元测试**

运行 `./android/run_tests.sh`，要求退出码为 0。

- [x] **步骤 2：构建 Android APK**

运行 `./android/build.sh`，要求 APK 签名验证成功。

- [x] **步骤 3：运行 macOS 单元测试**

运行 `swift test --package-path macos`，要求所有测试通过。

- [x] **步骤 4：构建 macOS executable**

运行 `swift build --package-path macos`，要求退出码为 0。

- [x] **步骤 5：审计路径和仓库状态**

搜索活跃文件中的过期路径，检查 `git diff --check`，并验证最终根目录布局。
