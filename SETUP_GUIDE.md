# AtoA Sync - 安装配置指南

## 目录
1. [环境准备](#环境准备)
2. [创建 Xcode 项目](#创建-xcode-项目)
3. [配置项目设置](#配置项目设置)
4. [添加源代码文件](#添加源代码文件)
5. [安装 ADB](#安装-adb)
6. [构建和运行](#构建和运行)
7. [打包发布](#打包发布)
8. [常见问题](#常见问题)

---

## 环境准备

### 1. 系统要求
- macOS 12.0 (Monterey) 或更高版本
- Xcode 13.0 或更高版本
- 至少 2GB 可用磁盘空间

### 2. 检查系统版本
```bash
sw_vers
```

### 3. 安装/更新 Xcode
从 Mac App Store 下载安装最新版本的 Xcode。

---

## 创建 Xcode 项目

### 步骤 1: 打开 Xcode
启动 Xcode，选择 "Create a new Xcode project"

### 步骤 2: 选择模板
1. 选择 **macOS** 标签页
2. 选择 **App** 模板
3. 点击 **Next**

### 步骤 3: 配置项目
- **Product Name**: `AtoASync`
- **Team**: 选择你的开发团队（个人账号也可以）
- **Organization Identifier**: `com.yourname` (使用你自己的标识符)
- **Bundle Identifier**: 自动生成为 `com.yourname.AtoASync`
- **Interface**: 选择 **SwiftUI**
- **Language**: 选择 **Swift**
- **勾选**: "Use Core Data" - **不勾选**
- **勾选**: "Include Tests" - **可选**

### 步骤 4: 保存位置
选择 `/Users/ios_k/Desktop/PProject/atoa_sync` 作为项目保存位置

---

## 配置项目设置

### 1. 配置 Target

#### 打开项目设置
在 Xcode 左侧导航栏选择项目文件（蓝色图标），然后选择 Target "AtoASync"

#### General 标签页设置
- **Minimum Deployments**: macOS 12.0
- **Deployment Target**: macOS 12.0 或更高

#### Signing & Capabilities 标签页设置
1. 勾选 "Automatically manage signing"
2. 选择你的开发团队

3. 添加权限（点击 "+ Capability" 按钮）：
   - **App Sandbox** - 已自动添加
   - 在 App Sandbox 下，勾选：
     - ✅ User Selected File (Read/Write)
     - ✅ Downloads Folder (Read/Write)
     - ✅ Network (Outgoing Connections) - 用于 Wi-Fi 连接

4. 添加文件访问权限：
   - 在 Info.plist 或 Info 标签页添加以下权限描述：
     - `NSDocumentsFolderUsageDescription`: "需要访问文档文件夹以同步文件"
     - `NSDesktopFolderUsageDescription`: "需要访问桌面文件夹以同步文件"
     - `NSDownloadsFolderUsageDescription`: "需要访问下载文件夹以同步文件"

#### Build Settings 标签页设置
1. 搜索 "Architectures"
2. 设置 **Architectures** 为 `Standard Architectures (Intel, Apple Silicon)` 或 `$(ARCHS_STANDARD)`
3. 搜索 "Swift Language Version"
4. 确保设置为 **Swift 5** 或更高

### 2. 配置 Info.plist

在 Info.plist 中添加以下键值：

```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>需要访问文档文件夹以同步文件</string>

<key>NSDesktopFolderUsageDescription</key>
<string>需要访问桌面文件夹以同步文件</string>

<key>NSDownloadsFolderUsageDescription</key>
<string>需要访问下载文件夹以同步文件</string>

<key>LSMinimumSystemVersion</key>
<string>12.0</string>

<key>NSHumanReadableCopyright</key>
<string>Copyright © 2026. All rights reserved.</string>
```

---

## 添加源代码文件

### 方法 1: 通过 Xcode 添加（推荐）

1. **删除默认文件**
   - 删除 Xcode 自动生成的 `ContentView.swift` 和 `AtoASyncApp.swift`（如果存在）

2. **添加 Sources 文件夹**
   - 右键点击项目导航栏中的 "AtoASync" 文件夹
   - 选择 "Add Files to AtoASync..."
   - 选择 `Sources` 文件夹
   - 确保勾选：
     - ✅ "Copy items if needed"
     - ✅ "Create groups"
     - ✅ Target "AtoASync"
   - 点击 "Add"

### 方法 2: 手动拖拽

1. 在 Finder 中打开 `atoa_sync/Sources` 文件夹
2. 将所有子文件夹（Models, Services, ViewModels, Views）和 `AtoASyncApp.swift` 拖拽到 Xcode 项目导航栏
3. 在弹出的对话框中：
   - ✅ "Copy items if needed"
   - ✅ "Create groups"
   - ✅ Target "AtoASync"

### 验证文件结构

确保 Xcode 项目导航栏中的结构如下：

```
AtoASync
├── AtoASyncApp.swift
├── Models
│   ├── FileInfo.swift
│   ├── DeviceInfo.swift
│   ├── DiffResult.swift
│   └── SyncTask.swift
├── Services
│   ├── ADBManager.swift
│   ├── FileScanner.swift
│   ├── DiffEngine.swift
│   ├── SyncManager.swift
│   ├── ConfigManager.swift
│   └── LogManager.swift
├── ViewModels
│   └── MainViewModel.swift
└── Views
    ├── ContentView.swift
    ├── SyncView.swift
    ├── TasksView.swift
    ├── LogsView.swift
    └── SettingsView.swift
```

---

## 安装 ADB

ADB (Android Debug Bridge) 是与安卓设备通信的必需工具。

### 方法 1: 使用 Homebrew（推荐）

```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 ADB
brew install android-platform-tools

# 验证安装
adb version
```

### 方法 2: 手动安装

1. 下载 Android SDK Platform Tools:
   - 访问: https://developer.android.com/studio/releases/platform-tools
   - 下载 macOS 版本

2. 解压并移动到合适位置:
```bash
# 解压下载的文件
unzip platform-tools-latest-darwin.zip

# 移动到用户目录
mv platform-tools ~/Android/sdk/

# 添加到 PATH
echo 'export PATH="$HOME/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 验证安装
adb version
```

### 验证 ADB 安装

```bash
adb version
# 应该输出类似：
# Android Debug Bridge version 1.x.x
```

---

## 构建和运行

### 1. 连接安卓设备

#### USB 连接
1. 在安卓设备上启用开发者选项和 USB 调试
2. 使用 USB 线连接设备到 Mac
3. 在设备上允许 USB 调试授权

#### 验证连接
```bash
adb devices
# 应该显示已连接的设备
```

### 2. 构建项目

在 Xcode 中：
1. 选择目标设备：**My Mac**
2. 选择菜单：**Product → Build** 或按 `⌘B`
3. 等待构建完成，确保没有错误

### 3. 运行应用

1. 点击 Xcode 左上角的运行按钮或按 `⌘R`
2. 应用启动后，你应该看到主界面
3. 点击"刷新设备"按钮，应该能看到已连接的安卓设备

### 4. 测试功能

1. **测试设备连接**
   - 查看侧边栏是否显示连接的设备
   - 查看设备信息是否正确

2. **测试文件扫描**
   - 选择目标路径
   - 点击"扫描文件"
   - 查看扫描进度

3. **测试差异比对**
   - 扫描完成后查看差异结果
   - 测试文件过滤和搜索功能

4. **测试文件同步**
   - 选择要同步的文件
   - 点击"开始同步"
   - 查看同步进度和速度

---

## 打包发布

### 1. 准备发布

#### 更新版本号
在 Xcode 中，选择 Target → General：
- **Version**: 1.0.0
- **Build**: 1

#### 配置发布构建
选择 **Product → Scheme → Edit Scheme**：
- 在 **Run** 标签页，将 **Build Configuration** 改为 **Release**

### 2. 创建 Archive

1. 选择菜单：**Product → Archive**
2. 等待 Archive 完成
3. Archive Organizer 窗口会自动打开

### 3. 导出应用

在 Archive Organizer 中：

#### 方法 1: 直接分发（不上架 App Store）
1. 点击 **Distribute App**
2. 选择 **Copy App**
3. 选择导出位置
4. 得到 `.app` 文件

#### 方法 2: 创建 DMG 安装包

使用命令行创建 DMG：

```bash
# 创建临时文件夹
mkdir -p dmg_temp
cp -R /path/to/AtoASync.app dmg_temp/

# 创建 DMG
hdiutil create -volname "AtoA Sync" -srcfolder dmg_temp -ov -format UDZO AtoASync.dmg

# 清理
rm -rf dmg_temp
```

### 4. Notarization（可选，推荐）

为了让应用能在其他 Mac 上顺利运行，建议进行 Apple 公证：

```bash
# 上传到 Apple 进行公证
xcrun notarytool submit AtoASync.dmg --apple-id your@email.com --password your-app-specific-password --team-id TEAM_ID

# 订书公证票据
xcrun stapler staple AtoASync.dmg
```

---

## 常见问题

### Q1: 编译错误 "Cannot find 'ADBManager' in scope"

**解决方法**:
- 确保所有 Swift 文件都已添加到项目的 Target
- 在 Xcode 右侧 File Inspector 中，确保文件的 Target Membership 勾选了 "AtoASync"

### Q2: ADB 未找到错误

**解决方法**:
```bash
# 检查 ADB 路径
which adb

# 如果找不到，重新安装或添加到 PATH
brew reinstall android-platform-tools
```

### Q3: 设备连接但无法检测

**解决方法**:
1. 检查 USB 调试是否开启
2. 重新授权 USB 调试
3. 尝试断开重连设备
4. 检查 ADB 连接：
```bash
adb kill-server
adb start-server
adb devices
```

### Q4: 文件同步失败

**可能原因**:
- 设备断开连接
- 目标路径权限不足
- 磁盘空间不足

**解决方法**:
- 检查设备连接状态
- 确保目标路径有写入权限
- 检查磁盘可用空间

### Q5: 应用无法在其他 Mac 上运行

**解决方法**:
- 确保使用 Universal Binary（支持 Intel 和 Apple Silicon）
- 进行 Apple Notarization
- 或让用户在安全性与隐私设置中允许运行

### Q6: 权限错误 "操作不允许"

**解决方法**:
- 在"系统偏好设置 → 安全性与隐私 → 隐私"中
- 添加应用到"文件和文件夹"权限列表
- 重启应用

### Q7: 构建错误 "Sandbox: rsync.samba"

**解决方法**:
- 在 Signing & Capabilities 中，App Sandbox 下
- 勾选 "User Selected File (Read/Write)"

---

## 性能优化建议

### 1. 大量文件处理
- 启用哈希比较时，大文件会较慢
- 对于大量小文件，禁用哈希比较可提升速度
- 使用文件类型过滤减少扫描范围

### 2. 网络传输优化
- USB 连接比 Wi-Fi 更快更稳定
- 调整最大并发传输数（设置中）

### 3. 缓存利用
- 应用会缓存上次同步记录
- 再次同步同一设备时会更快

---

## 联系和支持

如有问题，请查看：
- 项目 README.md
- 日志文件（应用内可导出）
- GitHub Issues（如果项目开源）

---

## 更新日志

### v1.0.0 (2026-01-16)
- ✅ 初始版本发布
- ✅ 支持 USB 设备连接
- ✅ 文件扫描和差异比对
- ✅ 增量文件同步
- ✅ Universal Binary 支持

---

祝使用愉快！🎉
