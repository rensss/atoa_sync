import AndroidSyncCore
import AppKit
import Observation
import OSLog
import ServiceManagement
import SwiftData

enum LibraryCategory: String, CaseIterable, Identifiable {
    case all
    case photos
    case videos
    case files
    case recent
    case deleted

    var id: String { rawValue }

    func title(using language: AppLanguage) -> String {
        let key: AppStringKey
        switch self {
        case .all: key = .categoryAll
        case .photos: key = .categoryPhotos
        case .videos: key = .categoryVideos
        case .files: key = .categoryFiles
        case .recent: key = .categoryRecent
        case .deleted: key = .categoryDeleted
        }
        return AppStrings.text(key, language: language)
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .photos: "photo"
        case .videos: "film"
        case .files: "doc"
        case .recent: "clock"
        case .deleted: "trash"
        }
    }
}

enum LibraryLayout: String {
    case grid
    case list
}

enum LibraryDateFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    func title(using language: AppLanguage) -> String {
        let key: AppStringKey
        switch self {
        case .all: key = .dateAny
        case .today: key = .dateToday
        case .sevenDays: key = .dateSevenDays
        case .thirtyDays: key = .dateThirtyDays
        }
        return AppStrings.text(key, language: language)
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case filename
    case size

    var id: String { rawValue }

    func title(using language: AppLanguage) -> String {
        let key: AppStringKey
        switch self {
        case .newest: key = .sortNewest
        case .oldest: key = .sortOldest
        case .filename: key = .sortFilename
        case .size: key = .sortSize
        }
        return AppStrings.text(key, language: language)
    }
}

enum ReceiverStatus: Equatable {
    case needsDirectory
    case stopped
    case starting
    case running
    case failed(String)
}

struct ActiveUpload: Equatable, Identifiable {
    let id: UUID
    let filename: String
    let expectedSize: Int64
}

@MainActor
@Observable
final class AppModel {
    private let logger = Logger(
        subsystem: "com.androidsync.mac",
        category: "AppModel"
    )
    private let modelContext: ModelContext
    private let userDefaults: UserDefaults
    private let quickLookPreview: QuickLookPreview
    private var repository: LibraryRepository?
    private var receiverService: ReceiverService?
    private var scopedDirectoryURL: URL?
    private var launched = false
    private var transientUploadMessageTask: Task<Void, Never>?

    var items: [MediaItemEntity] = []
    var category: LibraryCategory = .all
    var layout: LibraryLayout = .grid
    var dateFilter: LibraryDateFilter = .all
    var sort: LibrarySort = .newest
    var searchText = ""
    var selectedIDs: Set<UUID> = []
    var inspectorPresented = false
    var status: ReceiverStatus = .needsDirectory
    var receiveDirectory: URL?
    var uploadURL = ""
    var language: AppLanguage {
        didSet {
            language.save(to: userDefaults)
        }
    }
    var port: UInt16 {
        didSet {
            userDefaults.set(Int(port), forKey: "receiverPort")
        }
    }
    var launchAtLogin: Bool
    var lastError: String?
    var activeUploads: [UUID: ActiveUpload] = [:]
    var transientUploadMessage: String?

    init(
        modelContainer: ModelContainer,
        userDefaults: UserDefaults = .standard,
        quickLookPreview: QuickLookPreview = .shared
    ) {
        modelContext = ModelContext(modelContainer)
        self.userDefaults = userDefaults
        self.quickLookPreview = quickLookPreview
        language = AppLanguage.load(from: userDefaults)
        let storedPort = userDefaults.integer(forKey: "receiverPort")
        port = storedPort == 0 ? 8765 : UInt16(clamping: storedPort)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func text(_ key: AppStringKey) -> String {
        AppStrings.text(key, language: language)
    }

    func format(_ key: AppStringKey, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            arguments: arguments
        )
    }

    func formatByteCount(_ byteCount: Int64) -> String {
        AppFormatters.byteCount(byteCount, language: language)
    }

    func formatDate(_ date: Date) -> String {
        AppFormatters.date(date, language: language)
    }

    func formatDateOnly(_ date: Date) -> String {
        AppFormatters.dateOnly(date, language: language)
    }

    var filteredItems: [MediaItemEntity] {
        Self.filterItems(
            items,
            category: category,
            dateFilter: dateFilter,
            sort: sort,
            searchText: searchText,
            now: Date(),
            calendar: Calendar.current
        )
    }

    static func filterItems(
        _ items: [MediaItemEntity],
        category: LibraryCategory,
        dateFilter: LibraryDateFilter,
        sort: LibrarySort,
        searchText: String,
        now: Date,
        calendar: Calendar
    ) -> [MediaItemEntity] {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfSevenDays = calendar.date(
            byAdding: .day,
            value: -6,
            to: startOfToday
        ) ?? startOfToday
        let startOfThirtyDays = calendar.date(
            byAdding: .day,
            value: -29,
            to: startOfToday
        ) ?? startOfToday
        let filtered = items.filter { item in
            let categoryMatches: Bool
            switch category {
            case .all:
                categoryMatches = !item.deleted
            case .photos:
                categoryMatches = !item.deleted && item.kind == .photo
            case .videos:
                categoryMatches = !item.deleted && item.kind == .video
            case .files:
                categoryMatches = !item.deleted && item.kind == .file
            case .recent:
                categoryMatches = !item.deleted
                    && item.receivedAt >= startOfToday
                    && item.receivedAt <= now
            case .deleted:
                categoryMatches = item.deleted
            }
            let dateMatches: Bool
            switch dateFilter {
            case .all:
                dateMatches = true
            case .today:
                dateMatches = item.receivedAt >= startOfToday
                    && item.receivedAt <= now
            case .sevenDays:
                dateMatches = item.receivedAt >= startOfSevenDays
                    && item.receivedAt <= now
            case .thirtyDays:
                dateMatches = item.receivedAt >= startOfThirtyDays
                    && item.receivedAt <= now
            }
            return categoryMatches && dateMatches
                && (searchText.isEmpty
                    || item.filename.localizedCaseInsensitiveContains(searchText))
        }
        switch sort {
        case .newest:
            return filtered.sorted { $0.receivedAt > $1.receivedAt }
        case .oldest:
            return filtered.sorted { $0.receivedAt < $1.receivedAt }
        case .filename:
            return filtered.sorted {
                $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
            }
        case .size:
            return filtered.sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    var selectedItem: MediaItemEntity? {
        guard selectedIDs.count == 1, let id = selectedIDs.first else {
            return nil
        }
        return items.first { $0.id == id }
    }

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    var menuBarSystemImage: String {
        switch status {
        case .running: "arrow.down.circle.fill"
        case .starting: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        case .needsDirectory: "folder.badge.questionmark"
        case .stopped: "arrow.down.circle"
        }
    }

    func launchIfNeeded() async {
        guard !launched else { return }
        launched = true
        do {
            if let url = try DirectoryBookmarkStore.resolve() {
                configure(directory: url)
                await startReceiver()
            } else {
                status = .needsDirectory
            }
        } catch {
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = text(.receivePanelTitle)
        panel.prompt = text(.chooseFolder)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try DirectoryBookmarkStore.save(url)
            configure(directory: url)
            Task { await startReceiver() }
        } catch {
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func toggleReceiver() {
        if isRunning {
            stopReceiver()
        } else {
            Task { await startReceiver() }
        }
    }

    func restartReceiver() {
        stopReceiver()
        rebuildReceiverService()
        Task { await startReceiver() }
    }

    func select(_ id: UUID, additive: Bool) {
        if additive {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
        } else {
            selectedIDs = [id]
        }
    }

    func preview(_ item: MediaItemEntity) {
        guard !item.deleted else { return }
        quickLookPreview.show(item.fileURL)
    }

    func toggleSelectedPreview() {
        guard let item = selectedItem, !item.deleted else { return }
        quickLookPreview.toggle(item.fileURL)
    }

    func reveal(_ item: MediaItemEntity) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    func renameSelected(to filename: String) async {
        guard let item = selectedItem, let repository else { return }
        do {
            _ = try await repository.rename(item.uploadRecord, to: filename)
            await reloadLibrary()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSelected() async {
        guard let repository else { return }
        let selected = items.filter { selectedIDs.contains($0.id) && !$0.deleted }
        do {
            for item in selected {
                try await repository.delete(item.uploadRecord) { url in
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
            }
            selectedIDs.removeAll()
            await reloadLibrary()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            lastError = error.localizedDescription
        }
    }

    func openReceiveDirectory() {
        guard let receiveDirectory else { return }
        NSWorkspace.shared.open(receiveDirectory)
    }

    private func configure(directory: URL) {
        receiverService?.stop()
        if let scopedDirectoryURL {
            scopedDirectoryURL.stopAccessingSecurityScopedResource()
        }
        _ = directory.startAccessingSecurityScopedResource()
        scopedDirectoryURL = directory
        receiveDirectory = directory
        let repository = LibraryRepository(rootURL: directory)
        self.repository = repository
        rebuildReceiverService()
        status = .stopped
        Task { await reloadLibrary() }
    }

    private func rebuildReceiverService() {
        guard let repository else {
            receiverService = nil
            return
        }
        receiverService = ReceiverService(
            repository: repository,
            port: port
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    private func startReceiver() async {
        guard receiveDirectory != nil else {
            status = .needsDirectory
            return
        }
        guard let receiverService else { return }
        status = .starting
        do {
            let actualPort = try await receiverService.start()
            uploadURL = "http://\(SystemNetworkInfo.localIPv4Address()):\(actualPort)/uploads/"
            status = .running
            lastError = nil
            logger.info("Receiver started on port \(actualPort, privacy: .public)")
        } catch {
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            logger.error("Receiver failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopReceiver() {
        receiverService?.stop()
        status = receiveDirectory == nil ? .needsDirectory : .stopped
        logger.info("Receiver stopped")
    }

    func handle(_ event: ReceiverServiceEvent) {
        switch event {
        case let .started(port):
            uploadURL = "http://\(SystemNetworkInfo.localIPv4Address()):\(port)/uploads/"
            status = .running
        case .stopped:
            activeUploads.removeAll()
            clearTransientUploadFailure()
            if receiveDirectory != nil {
                status = .stopped
            }
        case let .uploadStarted(id, filename, expectedSize):
            activeUploads[id] = ActiveUpload(
                id: id,
                filename: filename,
                expectedSize: expectedSize
            )
        case let .uploadStored(id, _):
            activeUploads.removeValue(forKey: id)
            Task { await reloadLibrary() }
        case let .uploadFailed(id, filename, message):
            activeUploads.removeValue(forKey: id)
            showTransientUploadFailure(filename: filename, message: message)
        case let .receiverFailed(message):
            activeUploads.removeAll()
            clearTransientUploadFailure()
            status = .failed(message)
            lastError = message
        }
    }

    private func showTransientUploadFailure(filename: String, message: String) {
        transientUploadMessageTask?.cancel()
        transientUploadMessage = format(.uploadFailedFormat, filename, message)
        transientUploadMessageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.transientUploadMessage = nil
        }
    }

    private func clearTransientUploadFailure() {
        transientUploadMessageTask?.cancel()
        transientUploadMessageTask = nil
        transientUploadMessage = nil
    }

    private func reloadLibrary() async {
        guard let repository else { return }
        do {
            let records = try await repository.libraryRecords()
            syncDatabase(with: records)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func syncDatabase(with records: [UploadRecord]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<MediaItemEntity>())) ?? []
        let existingByKey = Dictionary(
            uniqueKeysWithValues: existing.map { (identityKey(for: $0), $0) }
        )
        var retained = Set<PersistentIdentifier>()
        var result: [MediaItemEntity] = []

        for record in records {
            let key = record.stableID ?? record.fileURL.path
            let entity: MediaItemEntity
            if let current = existingByKey[key] {
                current.update(from: record)
                entity = current
            } else {
                entity = MediaItemEntity(record: record)
                modelContext.insert(entity)
            }
            retained.insert(entity.persistentModelID)
            result.append(entity)
        }
        for entity in existing where !retained.contains(entity.persistentModelID) {
            modelContext.delete(entity)
        }
        try? modelContext.save()
        items = result
    }

    private func identityKey(for item: MediaItemEntity) -> String {
        item.stableID ?? item.filePath
    }
}
