# AtoA Sync - 项目结构说明

## 项目概述
AtoA Sync 是一款 macOS 原生应用，使用 Swift + SwiftUI 开发，实现安卓设备到 Mac 的文件同步功能。支持自动差异比对、用户选择同步文件，并完全兼容 Intel 和 Apple Silicon (M 系列) 芯片。

## 目录结构

```
atoa_sync/
├── Sources/
│   ├── AtoASyncApp.swift              # 应用主入口
│   ├── Models/                         # 数据模型
│   │   ├── FileInfo.swift             # 文件信息模型
│   │   ├── DeviceInfo.swift           # 设备信息模型
│   │   ├── DiffResult.swift           # 差异比对结果模型
│   │   └── SyncTask.swift             # 同步任务模型
│   ├── Services/                       # 核心服务
│   │   ├── ADBManager.swift           # ADB 管理器（设备连接）
│   │   ├── FileScanner.swift          # 文件扫描服务
│   │   ├── DiffEngine.swift           # 差异比对引擎
│   │   ├── SyncManager.swift          # 同步管理器
│   │   ├── ConfigManager.swift        # 配置管理
│   │   └── LogManager.swift           # 日志管理
│   ├── ViewModels/                     # 视图模型
│   │   └── MainViewModel.swift        # 主视图模型
│   └── Views/                          # SwiftUI 视图
│       ├── ContentView.swift          # 主视图
│       ├── SyncView.swift             # 同步界面
│       ├── TasksView.swift            # 任务管理界面
│       ├── LogsView.swift             # 日志界面
│       └── SettingsView.swift         # 设置界面
├── Resources/                          # 资源文件
│   └── Info.plist                     # 应用配置
├── PROJECT_STRUCTURE.md               # 本文件
├── SETUP_GUIDE.md                     # 安装配置指南
└── README.md                          # 项目说明

## 核心模块说明

### 1. Models（数据模型）
- **FileInfo**: 文件信息，包含路径、大小、修改时间、哈希值等
- **DeviceInfo**: 设备信息，包含序列号、名称、型号、连接状态等
- **DiffResult**: 差异比对结果，包含新增、修改、删除的文件列表
- **SyncTask**: 同步任务信息，包含进度、状态、速度等

### 2. Services（核心服务）
- **ADBManager**: 通过 ADB 与安卓设备通信，获取设备列表和文件信息
- **FileScanner**: 扫描本地和远程文件系统，获取文件列表
- **DiffEngine**: 比对设备端和本地文件的差异
- **SyncManager**: 管理文件同步任务，处理冲突、进度追踪等
- **ConfigManager**: 管理应用配置和缓存
- **LogManager**: 记录和管理应用日志

### 3. ViewModels（视图模型）
- **MainViewModel**: 主视图的业务逻辑，连接 UI 和服务层

### 4. Views（用户界面）
- **ContentView**: 主窗口，包含侧边栏和内容区域
- **SyncView**: 文件同步界面，显示差异比对结果
- **TasksView**: 同步任务管理界面
- **LogsView**: 日志查看界面
- **SettingsView**: 应用设置界面

## 技术栈

- **语言**: Swift 5.5+
- **UI 框架**: SwiftUI (macOS 12.0+)
- **并发**: async/await, DispatchQueue
- **文件操作**: FileManager, Process
- **数据持久化**: JSON, UserDefaults
- **安全**: CryptoKit (SHA-256)
- **设备通信**: ADB (Android Debug Bridge)

## 架构设计

### MVVM 架构
```
View (SwiftUI) 
  ↓
ViewModel (ObservableObject)
  ↓
Service Layer (Managers)
  ↓
Data Models
```

### 数据流
```
用户操作 → ViewModel → Service → 数据处理 → 更新 ViewModel → 刷新 UI
```

### 异步处理
- 所有耗时操作（文件扫描、比对、同步）使用 async/await
- UI 更新通过 @MainActor 确保在主线程执行
- 使用 DispatchQueue 进行后台任务处理

## 功能特性

### ✅ 已实现功能
1. **设备管理**
   - USB 连接检测
   - 设备信息获取
   - 多设备支持

2. **文件扫描**
   - 递归扫描目录
   - 文件属性获取（大小、修改时间）
   - 可选哈希计算

3. **差异比对**
   - 自动比对文件差异
   - 支持按大小、时间、哈希比对
   - 文件分类（新增、修改、删除、未改变）

4. **文件同步**
   - 增量同步
   - 进度追踪
   - 速度统计
   - 冲突处理（覆盖、跳过、重命名）

5. **用户界面**
   - 设备列表
   - 文件树展示
   - 差异结果过滤
   - 任务管理
   - 日志查看
   - 设置管理

6. **配置管理**
   - 保存用户配置
   - 缓存同步记录
   - 自动加载上次配置

7. **日志系统**
   - 分级日志记录
   - 日志过滤
   - 日志导出

### 🔄 待优化功能
1. Wi-Fi 连接支持
2. 断点续传
3. 多线程并行传输
4. 文件预览
5. 同步计划任务

## 构建要求

### 系统要求
- macOS 12.0 (Monterey) 或更高版本
- Xcode 13.0 或更高版本

### 依赖项
- Android SDK Platform Tools (ADB)
- 无第三方 Swift Package 依赖

### 架构支持
- Intel (x86_64)
- Apple Silicon (arm64)
- Universal Binary

## 开发规范

### 代码风格
- 使用 Swift 标准命名规范
- 类名使用大驼峰（PascalCase）
- 变量和方法使用小驼峰（camelCase）
- 常量使用全大写（SCREAMING_SNAKE_CASE）

### 注释要求
- 公共 API 必须添加文档注释
- 复杂逻辑需要添加解释注释
- TODO 和 FIXME 需要注明负责人

### 错误处理
- 使用 Result 类型处理可恢复错误
- 使用 throw 处理不可恢复错误
- 自定义错误类型继承 LocalizedError

### 测试
- 单元测试覆盖核心业务逻辑
- UI 测试覆盖关键用户流程

## 许可证
根据项目 LICENSE 文件的规定

## 贡献指南
请参考项目根目录的 CONTRIBUTING.md（待创建）
