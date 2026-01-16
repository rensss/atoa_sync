# AtoA Sync - 安卓到 Mac 文件同步工具

<div align="center">

![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Architecture](https://img.shields.io/badge/Architecture-Universal-purple.svg)

Mac 原生应用，使用 Swift + SwiftUI 开发，实现安卓设备到 Mac 的智能文件同步

</div>

## ✨ 特性

- 🔌 **设备连接** - 支持 USB 连接安卓设备，自动检测设备信息
- 📁 **智能扫描** - 递归扫描设备和本地文件，支持大量文件处理
- 🔍 **差异比对** - 自动比对文件差异（新增、修改、删除），支持哈希比对
- ⚡️ **增量同步** - 只同步变化的文件，节省时间和流量
- 🎯 **精准控制** - 用户可选择需要同步的文件和目录
- 🚀 **实时进度** - 显示同步进度、速度和剩余时间
- ⚙️ **冲突处理** - 支持覆盖、跳过、重命名等多种冲突解决方案
- 📊 **任务管理** - 查看同步历史和任务状态
- 📝 **日志系统** - 完整的操作日志记录和导出
- 🎨 **原生界面** - 使用 SwiftUI 构建，界面美观流畅
- 🔐 **安全可靠** - 沙盒环境运行，保护用户隐私
- 💻 **全架构支持** - 兼容 Intel 和 Apple Silicon (M 系列) 芯片

## 📸 截图

_（待添加应用截图）_

## 🚀 快速开始

### 系统要求

- macOS 12.0 (Monterey) 或更高版本
- Xcode 13.0 或更高版本
- Android SDK Platform Tools (ADB)

### 安装

#### 1. 安装 ADB

使用 Homebrew 安装（推荐）：

```bash
brew install android-platform-tools
```

或[手动下载](https://developer.android.com/studio/releases/platform-tools)

#### 2. 克隆项目

```bash
git clone https://github.com/yourusername/atoa_sync.git
cd atoa_sync
```

#### 3. 使用 Xcode 打开

详细的项目配置步骤请查看 [SETUP_GUIDE.md](SETUP_GUIDE.md)

### 使用方法

1. **连接设备**
   - 在安卓设备上启用 USB 调试
   - 使用 USB 连接设备到 Mac
   - 在设备上授权 USB 调试

2. **扫描文件**
   - 在应用中点击"刷新设备"
   - 选择目标保存路径
   - 点击"扫描文件"

3. **查看差异**
   - 扫描完成后查看文件差异
   - 使用过滤器筛选文件类型
   - 使用搜索框查找特定文件

4. **开始同步**
   - 勾选要同步的文件
   - 选择冲突处理方式
   - 点击"开始同步"

## 📖 文档

- [项目结构说明](PROJECT_STRUCTURE.md) - 详细的代码结构和架构说明
- [安装配置指南](SETUP_GUIDE.md) - 完整的安装和配置步骤
- [常见问题](SETUP_GUIDE.md#常见问题) - 遇到问题？查看这里

## 🛠 技术栈

- **语言**: Swift 5.5+
- **UI 框架**: SwiftUI
- **并发处理**: async/await, DispatchQueue
- **文件操作**: FileManager, Process
- **数据持久化**: JSON, Codable
- **安全**: CryptoKit (SHA-256)
- **设备通信**: ADB (Android Debug Bridge)

## 🏗 架构

### MVVM + Service Layer

```
┌─────────────────┐
│   Views         │  SwiftUI 视图层
│   (SwiftUI)     │
└────────┬────────┘
         │
┌────────▼────────┐
│   ViewModels    │  视图模型层
│ (ObservableObj) │
└────────┬────────┘
         │
┌────────▼────────┐
│   Services      │  服务层
│  (Managers)     │
└────────┬────────┘
         │
┌────────▼────────┐
│   Models        │  数据模型层
│  (Structures)   │
└─────────────────┘
```

### 核心模块

- **ADBManager**: 设备连接和通信
- **FileScanner**: 文件系统扫描
- **DiffEngine**: 差异比对算法
- **SyncManager**: 同步任务管理
- **ConfigManager**: 配置和缓存管理
- **LogManager**: 日志记录系统

## 🤝 贡献

欢迎贡献代码、报告问题或提出新功能建议！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📋 待实现功能

- [ ] Wi-Fi 连接支持
- [ ] 断点续传
- [ ] 多线程并行传输优化
- [ ] 文件预览功能
- [ ] 自动同步计划任务
- [ ] 双向同步支持
- [ ] 排除规则配置（.gitignore 风格）

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- Android Debug Bridge (ADB) - Google
- SwiftUI - Apple
- 所有贡献者和支持者

## 📧 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [Issue](https://github.com/rensss/atoa_sync/issues)
- 发送邮件至: vipp@duck.com

---

<div align="center">

**如果这个项目对你有帮助，请给它一个 ⭐️**

Made with ❤️ using Swift and SwiftUI

</div>
