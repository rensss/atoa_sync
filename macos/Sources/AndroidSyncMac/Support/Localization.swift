import AndroidSyncCore
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static let `default`: AppLanguage = .simplifiedChinese
    static let defaultsKey = "appLanguage"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func load(from defaults: UserDefaults) -> AppLanguage {
        guard
            let rawValue = defaults.string(forKey: defaultsKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return .default
        }
        return language
    }

    func save(to defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}

enum AppStringKey: String, CaseIterable {
    case settings
    case language
    case categoryAll
    case categoryPhotos
    case categoryVideos
    case categoryFiles
    case categoryRecent
    case categoryDeleted
    case kindPhoto
    case kindVideo
    case kindFile
    case dateAny
    case dateToday
    case dateSevenDays
    case dateThirtyDays
    case sortNewest
    case sortOldest
    case sortFilename
    case sortSize
    case receiveFolderRequired
    case receiverPaused
    case startingReceiver
    case readyToReceive
    case receiverUnavailable
    case receiverRunning
    case receiverStarting
    case receiverError
    case folderRequired
    case portFormat
    case copyAddress
    case pause
    case start
    case pauseReceiving
    case startReceiving
    case copyUploadAddress
    case openAndroidSync
    case openReceiveFolder
    case quitAndroidSync
    case searchFilenames
    case noReceivedFiles
    case receivedFilesDescription
    case noSearchResults
    case noSearchResultsDescription
    case quickLook
    case showInFinder
    case finder
    case moveToTrash
    case noSelection
    case selectionDescription
    case rename
    case renameEllipsis
    case renameFile
    case filename
    case cancel
    case ok
    case metadataType
    case metadataSize
    case metadataReceived
    case metadataCaptured
    case metadataSource
    case metadataSyncID
    case metadataLocation
    case chooseReceiveFolder
    case onboardingDescription
    case chooseFolder
    case chooseFolderEllipsis
    case chooseReceiveFolderEllipsis
    case receivePanelTitle
    case receiving
    case receivingFilesFormat
    case uploadFailedFormat
    case folder
    case notSelected
    case chooseEllipsis
    case port
    case portRestartDescription
    case general
    case startup
    case launchAtLogin
    case security
    case securityDescription
    case about
    case version
    case build
    case date
    case sort
    case inspector
    case layout
    case receivingSummaryFormat
    case todayReceived
    case itemsCountFormat
    case completedLingerFormat
}

enum AppStrings {
    private static let table: [AppLanguage: [AppStringKey: String]] = [
        .simplifiedChinese: [
            .settings: "设置",
            .language: "语言",
            .categoryAll: "全部项目",
            .categoryPhotos: "照片",
            .categoryVideos: "视频",
            .categoryFiles: "其他文件",
            .categoryRecent: "最近接收",
            .categoryDeleted: "已删除",
            .kindPhoto: "照片",
            .kindVideo: "视频",
            .kindFile: "文件",
            .dateAny: "不限日期",
            .dateToday: "今天",
            .dateSevenDays: "最近 7 天",
            .dateThirtyDays: "最近 30 天",
            .sortNewest: "最新优先",
            .sortOldest: "最早优先",
            .sortFilename: "文件名",
            .sortSize: "最大优先",
            .receiveFolderRequired: "需要选择接收文件夹",
            .receiverPaused: "接收已暂停",
            .startingReceiver: "正在启动接收服务…",
            .readyToReceive: "可以接收文件",
            .receiverUnavailable: "接收服务不可用",
            .receiverRunning: "接收服务运行中",
            .receiverStarting: "接收服务正在启动",
            .receiverError: "接收服务错误",
            .folderRequired: "需要选择文件夹",
            .portFormat: "端口 %d",
            .copyAddress: "复制地址",
            .pause: "暂停",
            .start: "启动",
            .pauseReceiving: "暂停接收",
            .startReceiving: "开始接收",
            .copyUploadAddress: "复制上传地址",
            .openAndroidSync: "打开 Android Sync",
            .openReceiveFolder: "打开接收文件夹",
            .quitAndroidSync: "退出 Android Sync",
            .searchFilenames: "搜索文件名",
            .noReceivedFiles: "暂无接收文件",
            .receivedFilesDescription: "从 Android 发送的文件会显示在这里。",
            .noSearchResults: "没有搜索结果",
            .noSearchResultsDescription: "没有文件符合当前搜索条件。",
            .quickLook: "快速查看",
            .showInFinder: "在访达中显示",
            .finder: "访达",
            .moveToTrash: "移到废纸篓",
            .noSelection: "未选择项目",
            .selectionDescription: "选择一个项目以查看其元数据。",
            .rename: "重命名",
            .renameEllipsis: "重命名…",
            .renameFile: "重命名文件",
            .filename: "文件名",
            .cancel: "取消",
            .ok: "确定",
            .metadataType: "类型",
            .metadataSize: "大小",
            .metadataReceived: "接收时间",
            .metadataCaptured: "拍摄时间",
            .metadataSource: "来源",
            .metadataSyncID: "同步 ID",
            .metadataLocation: "位置",
            .chooseReceiveFolder: "选择接收文件夹",
            .onboardingDescription: "Android Sync 需要一个文件夹来保存原始照片、视频、元数据和接收记录。",
            .chooseFolder: "选择文件夹",
            .chooseFolderEllipsis: "选择文件夹…",
            .chooseReceiveFolderEllipsis: "选择接收文件夹…",
            .receivePanelTitle: "选择 Android Sync 保存接收文件的位置",
            .receiving: "接收",
            .receivingFilesFormat: "正在接收 %d 个文件",
            .uploadFailedFormat: "%@ 接收失败：%@",
            .folder: "文件夹",
            .notSelected: "未选择",
            .chooseEllipsis: "选择…",
            .port: "端口",
            .portRestartDescription: "更改端口会重新启动接收服务。",
            .general: "通用",
            .startup: "启动",
            .launchAtLogin: "登录时启动 Android Sync",
            .security: "安全",
            .securityDescription: "仅接受来自本机和局域网私有地址的上传。当前未使用身份验证令牌。",
            .about: "关于",
            .version: "版本",
            .build: "构建号",
            .date: "日期",
            .sort: "排序",
            .inspector: "检查器",
            .layout: "布局",
            .receivingSummaryFormat: "接收中 %d 个文件 · 预计 %@",
            .todayReceived: "今天已接收",
            .itemsCountFormat: "%d 项",
            .completedLingerFormat: "已完成 %d 项",
        ],
        .english: [
            .settings: "Settings",
            .language: "Language",
            .categoryAll: "All Items",
            .categoryPhotos: "Photos",
            .categoryVideos: "Videos",
            .categoryFiles: "Other Files",
            .categoryRecent: "Recently Received",
            .categoryDeleted: "Deleted",
            .kindPhoto: "Photo",
            .kindVideo: "Video",
            .kindFile: "File",
            .dateAny: "Any Date",
            .dateToday: "Today",
            .dateSevenDays: "Last 7 Days",
            .dateThirtyDays: "Last 30 Days",
            .sortNewest: "Newest First",
            .sortOldest: "Oldest First",
            .sortFilename: "Filename",
            .sortSize: "Largest First",
            .receiveFolderRequired: "Receive folder required",
            .receiverPaused: "Receiver paused",
            .startingReceiver: "Starting receiver…",
            .readyToReceive: "Ready to receive",
            .receiverUnavailable: "Receiver unavailable",
            .receiverRunning: "Receiver Running",
            .receiverStarting: "Receiver Starting",
            .receiverError: "Receiver Error",
            .folderRequired: "Folder Required",
            .portFormat: "Port %d",
            .copyAddress: "Copy Address",
            .pause: "Pause",
            .start: "Start",
            .pauseReceiving: "Pause Receiving",
            .startReceiving: "Start Receiving",
            .copyUploadAddress: "Copy Upload Address",
            .openAndroidSync: "Open Android Sync",
            .openReceiveFolder: "Open Receive Folder",
            .quitAndroidSync: "Quit Android Sync",
            .searchFilenames: "Search filenames",
            .noReceivedFiles: "No Received Files",
            .receivedFilesDescription: "Files sent from Android will appear here.",
            .noSearchResults: "No Search Results",
            .noSearchResultsDescription: "No files match the current search.",
            .quickLook: "Quick Look",
            .showInFinder: "Show in Finder",
            .finder: "Finder",
            .moveToTrash: "Move to Trash",
            .noSelection: "No Selection",
            .selectionDescription: "Select one item to see its metadata.",
            .rename: "Rename",
            .renameEllipsis: "Rename…",
            .renameFile: "Rename File",
            .filename: "Filename",
            .cancel: "Cancel",
            .ok: "OK",
            .metadataType: "Type",
            .metadataSize: "Size",
            .metadataReceived: "Received",
            .metadataCaptured: "Captured",
            .metadataSource: "Source",
            .metadataSyncID: "Sync ID",
            .metadataLocation: "Location",
            .chooseReceiveFolder: "Choose a Receive Folder",
            .onboardingDescription: "Android Sync needs a folder for original photos, videos, metadata, and receive history.",
            .chooseFolder: "Choose Folder",
            .chooseFolderEllipsis: "Choose Folder…",
            .chooseReceiveFolderEllipsis: "Choose Receive Folder…",
            .receivePanelTitle: "Choose where Android Sync stores received files",
            .receiving: "Receiving",
            .receivingFilesFormat: "Receiving %d file(s)",
            .uploadFailedFormat: "Failed to receive %@: %@",
            .folder: "Folder",
            .notSelected: "Not selected",
            .chooseEllipsis: "Choose…",
            .port: "Port",
            .portRestartDescription: "Changing the port restarts the receiver.",
            .general: "General",
            .startup: "Startup",
            .launchAtLogin: "Launch Android Sync at login",
            .security: "Security",
            .securityDescription: "Uploads are accepted only from loopback and private local-network addresses. No authentication token is used.",
            .about: "About",
            .version: "Version",
            .build: "Build",
            .date: "Date",
            .sort: "Sort",
            .inspector: "Inspector",
            .layout: "Layout",
            .receivingSummaryFormat: "Receiving %d files · about %@",
            .todayReceived: "Received today",
            .itemsCountFormat: "%d items",
            .completedLingerFormat: "Completed %d items",
        ],
    ]

    static func text(_ key: AppStringKey, language: AppLanguage) -> String {
        table[language]?[key]
            ?? table[AppLanguage.default]?[key]
            ?? key.rawValue
    }

    static func hasTranslation(
        _ key: AppStringKey,
        language: AppLanguage
    ) -> Bool {
        table[language]?[key] != nil
    }

    static func tableKeys(for language: AppLanguage) -> Set<AppStringKey> {
        Set(table[language, default: [:]].keys)
    }

    static func format(
        _ key: AppStringKey,
        language: AppLanguage,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: text(key, language: language),
            arguments: arguments
        )
    }
}

extension UploadKind {
    func title(using language: AppLanguage) -> String {
        let key: AppStringKey
        switch self {
        case .photo: key = .kindPhoto
        case .video: key = .kindVideo
        case .file: key = .kindFile
        }
        return AppStrings.text(key, language: language)
    }
}

enum AppFormatters {
    static func contentType(
        _ contentType: String?,
        kind: UploadKind,
        language: AppLanguage
    ) -> String {
        let normalized = contentType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            return kind.title(using: language)
        }
        return normalized
    }

    static func byteCountStyle(
        language: AppLanguage
    ) -> ByteCountFormatStyle {
        ByteCountFormatStyle(style: .file)
            .locale(language.locale)
    }

    static func byteCount(_ byteCount: Int64, language: AppLanguage) -> String {
        byteCount.formatted(byteCountStyle(language: language))
    }

    static func dateStyle(language: AppLanguage) -> Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened)
            .locale(language.locale)
    }

    static func dateOnlyStyle(language: AppLanguage) -> Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(language.locale)
    }

    static func date(_ date: Date, language: AppLanguage) -> String {
        date.formatted(dateStyle(language: language))
    }

    static func dateOnly(_ date: Date, language: AppLanguage) -> String {
        date.formatted(dateOnlyStyle(language: language))
    }
}
