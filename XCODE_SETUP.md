# Xcode 项目创建指南

## 🎯 当前状态

✅ **项目目录已准备完成！**

所有源代码文件和配置文件已复制到 `AtoASync/` 目录：

```
AtoASync/
├── Sources/                    # ✅ 17 个 Swift 源文件已复制
│   ├── AtoASyncApp.swift
│   ├── Models/ (4 个文件)
│   ├── Services/ (6 个文件)
│   ├── ViewModels/ (1 个文件)
│   └── Views/ (5 个文件)
├── Assets.xcassets/            # ✅ 资源文件已创建
├── Info.plist                  # ✅ 配置文件已创建
└── AtoASync.entitlements       # ✅ 权限文件已创建
```

---

## 🚀 方法 1: 使用 Xcode GUI 创建（推荐）

### 步骤 1: 创建新项目

1. **打开 Xcode**（应该已经打开）

2. **选择 "Create a new Xcode project"** 或 **File → New → Project**

3. **选择模板**：
   
   - 平台：**macOS**
   - 模板：**App**
   - 点击 **Next**

### 步骤 2: 配置项目

填写以下信息：

| 字段                      | 值                         |
| ----------------------- | ------------------------- |
| Product Name            | `AtoASync`                |
| Team                    | 选择你的团队（或留空）               |
| Organization Identifier | `com.atoa`                |
| Bundle Identifier       | `com.atoa.AtoASync`（自动生成） |
| Interface               | **SwiftUI**               |
| Language                | **Swift**                 |
| Use Core Data           | ❌ **不勾选**                 |
| Include Tests           | ✅ 可选                      |

点击 **Next**

### 步骤 3: 选择保存位置

⚠️ **重要**：选择 `/Users/ios_k/Desktop/PProject/atoa_sync` 作为保存位置

- 系统会提示该目录已存在 `AtoASync` 文件夹
- 选择 **Merge** 或允许合并

点击 **Create**

### 步骤 4: 清理自动生成的文件

Xcode 会自动生成一些文件，我们需要替换它们：

1. **删除以下自动生成的文件**：
   
   - ❌ 删除 `AtoASyncApp.swift`（我们有自己的版本）
   - ❌ 删除 `ContentView.swift`（我们有自己的版本）
   - ❌ 删除 `Assets.xcassets`（我们有自己的版本）

2. **添加我们的源代码**：
   
   - 从 Finder 打开 `AtoASync/Sources`
   - 将 `Sources` 文件夹拖拽到 Xcode 项目导航栏
   - 确保勾选：
     - ✅ **Copy items if needed**
     - ✅ **Create groups**
     - ✅ **Add to targets: AtoASync**

3. **添加资源文件**：
   
   - 将 `AtoASync/Assets.xcassets` 拖入项目
   - 同样勾选上述选项

### 步骤 5: 配置项目设置

#### 5.1 配置 Info.plist

1. 选择项目 → **Target "AtoASync"** → **Info** 标签页
2. 将 **Custom macOS Application Target Properties** 设置为使用我们的 `Info.plist`：
   - 或者在 **Build Settings** 中搜索 `INFOPLIST_FILE`
   - 设置为 `AtoASync/Info.plist`

#### 5.2 配置 Entitlements

1. 选择项目 → **Target "AtoASync"** → **Signing & Capabilities**

2. 点击 **+ Capability** → 添加 **App Sandbox**

3. 在 App Sandbox 下勾选：
   
   - ✅ **User Selected File (Read/Write)**
   - ✅ **Downloads Folder (Read/Write)**
   - ✅ **Network: Outgoing Connections**

4. 设置 Code Sign Entitlements：
   
   - 在 **Build Settings** 中搜索 `CODE_SIGN_ENTITLEMENTS`
   - 设置为 `AtoASync/AtoASync.entitlements`

#### 5.3 配置架构

1. 在 **Build Settings** 中搜索 `ARCHS`
2. 确保 **Architectures** 设置为：
   - `Standard Architectures (Apple Silicon, Intel)`
   - 或 `$(ARCHS_STANDARD)`

#### 5.4 配置部署目标

1. 在 **General** 标签页
2. 将 **Minimum Deployments** 设置为 **macOS 12.0**

### 步骤 6: 构建项目

1. 选择运行目标：**My Mac**
2. 按 **⌘B** 构建项目
3. 如果有错误，查看错误信息并修复

### 步骤 7: 运行应用

1. 按 **⌘R** 运行应用
2. 如果提示权限，允许访问文件和网络
3. 享受你的应用！🎉

---

## 💻 方法 2: 使用脚本创建（实验性）

如果你想尝试更自动化的方法，可以使用以下命令：

```bash
cd /Users/ios_k/Desktop/PProject/atoa_sync
./setup_project.sh
```

然后在 Xcode 中打开生成的 `.xcodeproj` 文件。

---

## 🔧 配置检查清单

创建项目后，请确认以下配置：

### General 标签页

- [ ] Product Name: `AtoASync`
- [ ] Bundle Identifier: `com.atoa.AtoASync`
- [ ] Version: `1.0.0`
- [ ] Build: `1`
- [ ] Minimum Deployments: `macOS 12.0`

### Signing & Capabilities 标签页

- [ ] Automatically manage signing: ✅
- [ ] Team: 已选择
- [ ] App Sandbox: ✅
  - [ ] User Selected File: ✅
  - [ ] Downloads Folder: ✅
  - [ ] Network Outgoing: ✅

### Build Settings 标签页

- [ ] Info.plist File: `AtoASync/Info.plist`
- [ ] Code Sign Entitlements: `AtoASync/AtoASync.entitlements`
- [ ] Architectures: `Standard Architectures`
- [ ] Swift Language Version: `Swift 5`

### 项目文件

- [ ] 已添加 `Sources/` 目录（17 个 Swift 文件）
- [ ] 已添加 `Assets.xcassets`
- [ ] 已配置 `Info.plist`
- [ ] 已配置 `AtoASync.entitlements`

---

## 🐛 常见问题

### Q1: 编译错误 "No such module"

**解决方法**：

- 确保所有 Swift 文件都添加到了 Target
- 右键点击文件 → **Get Info** → **Target Membership** → 勾选 `AtoASync`

### Q2: Info.plist 找不到

**解决方法**：

1. 选择项目 → **Build Settings**
2. 搜索 `INFOPLIST_FILE`
3. 设置为 `AtoASync/Info.plist`
4. 确保该文件存在且路径正确

### Q3: 权限错误

**解决方法**：

- 确保已添加 App Sandbox capability
- 确保 Entitlements 文件路径正确
- 在 **Build Settings** 中设置 `CODE_SIGN_ENTITLEMENTS`

### Q4: 架构不匹配

**解决方法**：

- 在 **Build Settings** 搜索 `ARCHS`
- 设置为 `$(ARCHS_STANDARD)` 或 `arm64 x86_64`

### Q5: Swift 版本错误

**解决方法**：

- 在 **Build Settings** 搜索 `SWIFT_VERSION`
- 设置为 `5.0` 或更高

---

## 📚 参考文档

- [QUICK_START.md](QUICK_START.md) - 5 分钟快速上手
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - 详细配置指南
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - 项目结构说明

---

## 🎉 完成

按照上述步骤操作后，你应该能够成功创建并运行 AtoASync 项目！

如果遇到问题，请查看文档或联系支持。

**祝开发顺利！** 🚀
