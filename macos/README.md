# Android Sync for macOS

这是 Android Sync 的原生 macOS 14+ 接收端和媒体库。

界面默认使用简体中文。可通过主窗口工具栏中的齿轮按钮打开设置，并在简体中文和
英文之间切换。

## 运行

```bash
./macos/build_and_run.sh
```

打包后的应用写入：

```text
dist/Android Sync.app
```

只运行测试、不打开应用：

```bash
swift test --package-path macos
```

## 首次启动

1. 选择接收文件夹。
2. 如果 macOS 弹出提示，允许传入网络连接。
3. 复制应用中显示的上传地址。
4. 在 Android 应用中把该地址设为目标 URL。

选择文件夹后，应用会自动开始接收。关闭主窗口后，接收端仍会在菜单栏中运行。
通过菜单栏中的 **退出 Android Sync** 停止进程。

## 存储兼容性

macOS 应用保留现有接收端布局：

```text
photos/YYYY-MM/
videos/YYYY-MM/
files/YYYY-MM/
uploads.jsonl
```

文件先流式写入临时 `.part` 文件，只有完整 `Content-Length` 到达后才移动到最终
位置。媒体字节不会被转码或压缩。应用会保留 Android Sync 时间戳、稳定 ID、MIME
类型、来源 IP、JSONL 历史和 `.metadata.json` sidecar。

选择既有 Python 接收端目录时，会自动导入其中的 `uploads.jsonl` 历史。

## 接收端点

- `GET /`
- `GET /health`
- `GET /manifest.json`
- `PUT /uploads/<filename>`

接收端接受 loopback、IPv4 私有/链路本地地址，以及 IPv6 链路本地或唯一本地地址。
当前没有认证令牌，只应在可信局域网内使用。

## 文件管理

主窗口提供分类筛选、搜索、网格/列表布局、Quick Look、在 Finder 中显示、元数据
检查、重命名、多选和移到废纸篓。选中一个文件后按空格打开 Quick Look；再次按
空格关闭。删除项目会保留 manifest tombstone，避免 Android 应用再次上传同一媒体。

## 版本信息

设置中包含“关于”区域，显示应用版本和构建号：

- 发布版本来自仓库根目录的 `VERSION` 文件，并打包为
  `CFBundleShortVersionString`。
- 构建号来自当前 Git 提交计数，并打包为 `CFBundleVersion`。
- 如果源码不在 Git 工作树中构建，打包脚本会使用正 UTC 时间戳作为构建号。
