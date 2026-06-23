# 架构

## 系统上下文

Android Sync 把 Android 设备上的媒体传输到原生 macOS 接收端，或传输到可信局域网
内兼容 HTTP/WebDAV 的目标。

```text
Android MediaStore
        |
        v
MediaStoreScanner -> SyncQueue -> HttpFileUploader
        |               ^               |
        |               |               | HTTP PUT
        |       RemoteManifestClient    v
        +---------- reconciliation  macOS ReceiverService
                                         |
                                         v
                                  LibraryRepository
                                         |
                 +-----------------------+----------------------+
                 v                       v                      v
          media directories       metadata sidecars      uploads.jsonl
```

## Android 边界

Android 应用使用 Java 编写，不引入第三方依赖，通过本地 Android SDK 工具直接构建。

- `MainActivity`：UI 组合、导航、扫描/上传编排和异步缩略图展示。
- `MediaStoreScanner`：从 Android `MediaStore` 读取照片和视频。
- `SyncQueue`：同步内存中的任务归属、状态转换、筛选、汇总和有界可见窗口。
- `RemoteManifestClient`：读取接收端历史并识别远端已经存储的媒体。
- `HttpFileUploader`：使用 HTTP `PUT` 和 Android Sync 元数据 header 流式上传媒体。

在进程生命周期内，队列是权威任务状态。UI 代码必须消费队列快照或有界窗口，不得
创建第二套可独立变更的任务模型。

## macOS 边界

macOS 应用是面向 macOS 14+ 的 Swift 6 package，分为：

- `AndroidSyncCore`：协议解析、网络访问策略、上传模型、文件策略、存储、manifest
  历史和接收端。
- `AndroidSyncMac`：SwiftUI/SwiftData 应用状态、视图、设置、目录访问、Quick Look
  和菜单栏生命周期。

`ReceiverService` 拥有 `NWListener` 和串行接收队列，最多接受 4 个并发连接。每个
连接把请求字节流写入由 repository 管理的临时存储。

`LibraryRepository` 是 actor，也是持久媒体库变更的唯一所有者。它负责校验尺寸、
选择存储路径、原子移动已完成临时文件、写入 sidecar 元数据，并追加 manifest
历史。

## 协议

受支持的原生接收端端点：

- `GET /`
- `GET /health`
- `GET /manifest.json`
- `PUT /uploads/<filename>`

上传 header 包含稳定 ID、尺寸、MIME 类型和可用的 Android 媒体时间戳。接收端按
原始内容存储，不进行转码。

## 存储模型

```text
<selected-root>/
|-- .incoming/*.part
|-- photos/YYYY-MM/
|-- videos/YYYY-MM/
|-- files/YYYY-MM/
`-- uploads.jsonl
```

每个已存储文件可拥有一个 `.metadata.json` sidecar。`uploads.jsonl` 是追加式事件
历史，用于构建当前 manifest，包括删除 tombstone。

## 并发模型

- Android 扫描、缩略图解码和上传必须留在主线程之外。UI 更新再回到 Android 主线程。
- `SyncQueue` 同步任务 map 访问。持有其 monitor 时绝不能执行长 I/O 或 bitmap 解码。
- macOS listener 和连接状态运行在一个串行 dispatch queue 上。
- macOS 存储变更通过 `LibraryRepository` actor 执行。
- SwiftUI 状态通过 `AppModel` 归属 main actor；接收端事件必须显式切换到 UI 状态。

## 所有权规则

- 平台代码留在所属平台目录。
- 核心网络和存储行为留在可测试的 `AndroidSyncCore`。
- SwiftUI 视图不直接变更文件，也不直接解析 HTTP。
- Android UI 代码不直接拥有持久接收端历史。
- 生成产物放在已忽略的构建目录或 `dist/`。
