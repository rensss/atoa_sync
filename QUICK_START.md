# AtoA Sync - 快速开始指南

## 🚀 5 分钟快速上手

这是一个最精简的快速开始指南，帮助你尽快运行项目。

---

## 步骤 1: 安装 ADB（2 分钟）

打开终端，运行：

```bash
brew install android-platform-tools
```

验证安装：
```bash
adb version
```

---

## 步骤 2: 创建 Xcode 项目（2 分钟）

1. **打开 Xcode** → **Create a new Xcode project**

2. **选择模板**：
   - 平台：**macOS**
   - 模板：**App**

3. **配置项目**：
   - Product Name: `AtoASync`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - 保存位置：选择 `atoa_sync` 文件夹

4. **配置目标**：
   - 选择项目 → Target → **General**
   - Minimum Deployments: **macOS 12.0**

5. **配置权限**：
   - 选择 **Signing & Capabilities**
   - 点击 **+ Capability** → 添加 **App Sandbox**
   - 勾选：
     - ✅ User Selected File (Read/Write)
     - ✅ Downloads Folder (Read/Write)
     - ✅ Network: Outgoing Connections

---

## 步骤 3: 添加源代码（1 分钟）

### 方法 A: 拖拽添加（推荐）

1. 删除 Xcode 自动生成的 `ContentView.swift` 和 `AtoASyncApp.swift`
2. 在 Finder 中打开 `Sources` 文件夹
3. 全选 `Sources` 下的所有文件和文件夹
4. 拖拽到 Xcode 项目导航栏
5. 在弹出窗口勾选：
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Target: AtoASync

### 方法 B: 使用菜单

1. 右键点击项目 → **Add Files to AtoASync...**
2. 选择 `Sources` 文件夹
3. 勾选相同的选项

---

## 步骤 4: 配置 Info.plist（30 秒）

在项目的 Info 标签页，添加以下权限描述：

| Key | Value |
|-----|-------|
| NSDocumentsFolderUsageDescription | 需要访问文档文件夹以同步文件 |
| NSDesktopFolderUsageDescription | 需要访问桌面文件夹以同步文件 |
| NSDownloadsFolderUsageDescription | 需要访问下载文件夹以同步文件 |

或复制 `Resources/Info.plist.example` 的内容到你的 Info.plist。

---

## 步骤 5: 连接设备并运行（30 秒）

### 准备安卓设备：

1. 在设备上：**设置** → **关于手机** → 连续点击 **版本号** 7 次（启用开发者选项）
2. **设置** → **开发者选项** → 启用 **USB 调试**
3. 用 USB 线连接设备到 Mac
4. 在设备上点击 **允许 USB 调试**

### 运行应用：

1. 在 Xcode 中选择 **My Mac** 作为运行目标
2. 按 **⌘R** 或点击运行按钮
3. 应用启动后，点击"刷新设备"
4. 看到你的设备了吗？🎉 成功！

---

## 🎯 现在做什么？

### 测试基本功能：

1. **扫描文件**
   - 点击"浏览"选择目标文件夹（比如桌面）
   - 点击"扫描文件"按钮
   - 等待扫描完成

2. **查看差异**
   - 查看新增/修改的文件列表
   - 尝试搜索和过滤功能

3. **同步文件**
   - 勾选要同步的文件
   - 点击"开始同步"
   - 查看实时进度

4. **查看日志**
   - 点击侧边栏的"日志"
   - 查看所有操作记录

---

## ❓ 遇到问题？

### Q: 看不到设备？

```bash
# 检查 ADB 连接
adb devices
```

应该看到你的设备。如果没有：
- 确认 USB 调试已开启
- 尝试更换 USB 线或端口
- 在设备上重新授权

### Q: 编译错误？

- 确认所有文件都添加到 Target
- 检查文件的 Target Membership
- 清理构建：**Product** → **Clean Build Folder**

### Q: 权限错误？

- 确认已添加 App Sandbox 权限
- 确认已添加 Info.plist 权限描述
- 在系统设置中授予应用文件访问权限

---

## 📚 更多信息

- 详细安装指南：[SETUP_GUIDE.md](SETUP_GUIDE.md)
- 项目结构说明：[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
- 实现总结：[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
- 完整 README：[README.md](README.md)

---

## 🎊 完成！

恭喜！你已经成功运行了 AtoA Sync。

现在你可以：
- ✅ 同步你的安卓文件到 Mac
- ✅ 查看文件差异
- ✅ 管理同步任务
- ✅ 自定义设置

享受使用吧！🚀

---

_如果这个指南有帮助，请给项目一个 ⭐️_
