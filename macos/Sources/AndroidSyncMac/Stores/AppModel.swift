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
    let batchIndex: Int?
    let batchTotal: Int?
    var bytesReceived: Int64 = 0

    init(
        id: UUID,
        filename: String,
        expectedSize: Int64,
        batchIndex: Int? = nil,
        batchTotal: Int? = nil,
        bytesReceived: Int64 = 0
    ) {
        self.id = id
        self.filename = filename
        self.expectedSize = expectedSize
        self.batchIndex = batchIndex
        self.batchTotal = batchTotal
        self.bytesReceived = bytesReceived
    }
}

enum TransferCardState: Equatable {
    case idle
    case receiving
}

protocol ReceiverServiceControlling: AnyObject, Sendable {
    func start() async throws -> UInt16
    func stop()
    func stopAndWait() async
}

extension ReceiverService: ReceiverServiceControlling {}

@MainActor
@Observable
final class AppModel {
    typealias ReceiverServiceFactory = @MainActor (
        LibraryRepository,
        UInt16,
        @escaping ReceiverService.EventHandler
    ) -> any ReceiverServiceControlling
    typealias LibraryRecordsLoader = @MainActor (
        LibraryRepository
    ) async throws -> [UploadRecord]

    private enum ReceiverAction {
        case start
        case stop
        case restart
    }

    private final class ConfigurationCancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        func cancel() {
            lock.withLock {
                cancelled = true
            }
        }

        var isCancelled: Bool {
            lock.withLock { cancelled }
        }
    }

    private struct ReceiverTransition {
        let generation: UInt64
        let services: [any ReceiverServiceControlling]
    }

    private struct ReceiverSnapshot {
        let repository: LibraryRepository?
        let status: ReceiverStatus
        let uploadURL: String
    }

    private let logger = Logger(
        subsystem: "com.androidsync.mac",
        category: "AppModel"
    )
    private let modelContext: ModelContext
    private let userDefaults: UserDefaults
    private let quickLookPreview: QuickLookPreview
    private let libraryKeyMonitor: (any LibraryKeyMonitoring)?
    private let receiverServiceFactory: ReceiverServiceFactory
    private let bookmarkClient: DirectoryBookmarkClient
    private let directoryAccessClient: DirectoryAccessClient
    private let libraryRecordsLoader: LibraryRecordsLoader
    private var repository: LibraryRepository?
    private var receiverService: (any ReceiverServiceControlling)?
    private var receiverEventTask: Task<Void, Never>?
    private var receiverEventContinuation: AsyncStream<ReceiverServiceEvent>.Continuation?
    private var stoppingServices: [ObjectIdentifier: any ReceiverServiceControlling] = [:]
    private var scopedDirectoryURL: URL?
    private var launched = false
    private var transientUploadMessageTask: Task<Void, Never>?
    private var receiverActionGeneration: UInt64 = 0
    private var configurationRequestGeneration: UInt64 = 0
    private var bookmarkOwnerGeneration: UInt64?
    private(set) var receiverGeneration: UInt64 = 0
    private(set) var directoryConfigurationGeneration: UInt64 = 0

    var items: [MediaItemEntity] = []
    var category: LibraryCategory = .all
    var layout: LibraryLayout = .grid
    var dateFilter: LibraryDateFilter = .all
    var sort: LibrarySort = .newest
    var searchText = ""
    var selectedIDs: Set<UUID> = []
    var libraryKeyboardNavigationEnabled = false
    var libraryQuickLookBlocked = false
    var libraryGridColumnCount = 1
    var libraryScrollTargetID: UUID?
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
    private(set) var transferCardState: TransferCardState = .idle
    private var burstCompletedCount = 0
    private var burstBytesReceived: Int64 = 0
    private var burstSawProgress = false
    private var burstExpectedCount = 0
    private var transferSamples: [TransferSample] = []
    private var clearedDeletedKeys: Set<String>
    private static let clearedDeletedKeysDefaultsKey = "clearedDeletedItemKeys"

    struct TransferSample: Equatable {
        let time: Date
        let totalBytes: Int64
    }

    init(
        modelContainer: ModelContainer,
        userDefaults: UserDefaults = .standard,
        quickLookPreview: QuickLookPreview = .shared,
        libraryKeyMonitor: (any LibraryKeyMonitoring)? = nil,
        receiverServiceFactory: @escaping ReceiverServiceFactory = {
            repository,
            port,
            eventHandler in
            ReceiverService(
                repository: repository,
                port: port,
                eventHandler: eventHandler
            )
        },
        bookmarkClient: DirectoryBookmarkClient = .live,
        directoryAccessClient: DirectoryAccessClient = .live,
        libraryRecordsLoader: @escaping LibraryRecordsLoader = {
            try $0.libraryRecords()
        }
    ) {
        modelContext = ModelContext(modelContainer)
        self.userDefaults = userDefaults
        self.quickLookPreview = quickLookPreview
        self.libraryKeyMonitor = libraryKeyMonitor
        self.receiverServiceFactory = receiverServiceFactory
        self.bookmarkClient = bookmarkClient
        self.directoryAccessClient = directoryAccessClient
        self.libraryRecordsLoader = libraryRecordsLoader
        language = AppLanguage.load(from: userDefaults)
        let storedPort = userDefaults.integer(forKey: "receiverPort")
        port = storedPort == 0 ? 8765 : UInt16(clamping: storedPort)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        clearedDeletedKeys = Set(
            userDefaults.stringArray(forKey: Self.clearedDeletedKeysDefaultsKey) ?? []
        )
        libraryKeyMonitor?.start { [weak self] command in
            self?.handleLibraryNavigation(command) ?? false
        }
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

    struct TodayStats: Equatable {
        let count: Int
        let bytes: Int64
    }

    static func todayStats(
        _ items: [MediaItemEntity],
        now: Date,
        calendar: Calendar
    ) -> TodayStats {
        let startOfToday = calendar.startOfDay(for: now)
        let todays = items.filter {
            !$0.removed && $0.receivedAt >= startOfToday && $0.receivedAt <= now
        }
        return TodayStats(
            count: todays.count,
            bytes: todays.reduce(0) { $0 + $1.sizeBytes }
        )
    }

    var todayStats: TodayStats {
        Self.todayStats(items, now: Date(), calendar: .current)
    }

    struct SidebarLibraryStats: Equatable {
        let photoCount: Int
        let videoCount: Int
        let fileCount: Int
        let totalBytes: Int64
    }

    static func sidebarLibraryStats(
        _ items: [MediaItemEntity]
    ) -> SidebarLibraryStats {
        var photoCount = 0
        var videoCount = 0
        var fileCount = 0
        var totalBytes: Int64 = 0

        for item in items where !item.removed {
            switch item.kind {
            case .photo:
                photoCount += 1
            case .video:
                videoCount += 1
            case .file:
                fileCount += 1
            }
            let size = max(0, item.sizeBytes)
            let addition = totalBytes.addingReportingOverflow(size)
            totalBytes = addition.overflow ? .max : addition.partialValue
        }

        return SidebarLibraryStats(
            photoCount: photoCount,
            videoCount: videoCount,
            fileCount: fileCount,
            totalBytes: totalBytes
        )
    }

    var sidebarLibraryStats: SidebarLibraryStats {
        Self.sidebarLibraryStats(items)
    }

    var activeUploadsExpectedBytes: Int64 {
        activeUploads.values.reduce(0) { $0 + $1.expectedSize }
    }

    var activeUploadsRemainingBytes: Int64 {
        activeUploads.values.reduce(0) {
            $0 + max(0, $1.expectedSize - $1.bytesReceived)
        }
    }

    var transferCompletedCount: Int {
        let indexedCompleted = activeUploads.values.compactMap { upload -> Int? in
            guard let index = upload.batchIndex, index > 0 else {
                return nil
            }
            return index - 1
        }.max() ?? 0
        return max(burstCompletedCount, indexedCompleted)
    }

    var transferTotalCount: Int {
        max(burstExpectedCount, burstCompletedCount + activeUploads.count)
    }

    var transferProgress: Double? {
        let indexedUploads = activeUploads.values.compactMap { upload -> Double? in
            guard let index = upload.batchIndex,
                  let total = upload.batchTotal,
                  index > 0,
                  total > 0,
                  upload.expectedSize > 0
            else {
                return nil
            }
            let currentFraction = min(1, Double(upload.bytesReceived) / Double(upload.expectedSize))
            return (Double(index - 1) + currentFraction) / Double(total)
        }
        if let indexedProgress = indexedUploads.max() {
            return min(1, indexedProgress)
        }
        let totalCount = transferTotalCount
        if totalCount > 0 {
            let activeFractions = activeUploads.values.reduce(0.0) { partial, upload in
                guard upload.expectedSize > 0 else { return partial }
                return partial + min(1, Double(upload.bytesReceived) / Double(upload.expectedSize))
            }
            return min(1, (Double(burstCompletedCount) + activeFractions) / Double(totalCount))
        }
        guard burstSawProgress else { return nil }
        let expected = activeUploadsExpectedBytes
        guard expected > 0 else { return nil }
        let received = activeUploads.values.reduce(0) { $0 + $1.bytesReceived }
        return min(1, Double(received) / Double(expected))
    }

    static func transferSpeed(samples: [TransferSample]) -> Int64? {
        guard let first = samples.first, let last = samples.last,
              last.time > first.time
        else { return nil }
        let dt = last.time.timeIntervalSince(first.time)
        return Int64(Double(last.totalBytes - first.totalBytes) / dt)
    }

    var transferSpeedBytesPerSecond: Int64? {
        Self.transferSpeed(samples: transferSamples)
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
            let itemDate = item.mediaDate
            let categoryMatches: Bool
            switch category {
            case .all:
                categoryMatches = !item.removed
            case .photos:
                categoryMatches = !item.removed && item.kind == .photo
            case .videos:
                categoryMatches = !item.removed && item.kind == .video
            case .files:
                categoryMatches = !item.removed && item.kind == .file
            case .recent:
                categoryMatches = !item.removed
                    && item.receivedAt >= startOfToday
                    && item.receivedAt <= now
            case .deleted:
                categoryMatches = item.removed
            }
            let dateMatches: Bool
            switch dateFilter {
            case .all:
                dateMatches = true
            case .today:
                dateMatches = itemDate >= startOfToday
                    && itemDate <= now
            case .sevenDays:
                dateMatches = itemDate >= startOfSevenDays
                    && itemDate <= now
            case .thirtyDays:
                dateMatches = itemDate >= startOfThirtyDays
                    && itemDate <= now
            }
            return categoryMatches && dateMatches
                && (searchText.isEmpty
                    || item.filename.localizedCaseInsensitiveContains(searchText))
        }
        switch sort {
        case .newest:
            return filtered.sorted { $0.mediaDate > $1.mediaDate }
        case .oldest:
            return filtered.sorted { $0.mediaDate < $1.mediaDate }
        case .filename:
            return filtered.sorted {
                $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
            }
        case .size:
            return filtered.sorted { $0.sizeBytes > $1.sizeBytes }
        }
    }

    func categoryCount(_ category: LibraryCategory) -> Int {
        Self.filterItems(
            items,
            category: category,
            dateFilter: .all,
            sort: .newest,
            searchText: "",
            now: Date(),
            calendar: .current
        ).count
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

    var statusCapsuleTitle: String {
        if isRunning, !activeUploads.isEmpty {
            return format(.receivingFilesFormat, activeUploads.count)
        }
        return switch status {
        case .needsDirectory: text(.receiveFolderRequired)
        case .stopped: text(.receiverPaused)
        case .starting: text(.startingReceiver)
        case .running: text(.readyToReceive)
        case .failed: text(.receiverUnavailable)
        }
    }

    var statusCapsuleDetail: String {
        uploadURL.isEmpty ? format(.portFormat, Int(port)) : uploadURL
    }

    func launchIfNeeded() async {
        guard !launched else { return }
        launched = true
        do {
            if let url = try bookmarkClient.resolve() {
                await configureDirectory(
                    url,
                    startReceiverAfterConfiguration: true,
                    persistBookmark: false
                ).value
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

        configureDirectory(url)
    }

    @discardableResult
    func toggleReceiver() -> Task<Void, Never> {
        if isRunning {
            scheduleReceiverAction(.stop)
        } else {
            scheduleReceiverAction(.start)
        }
    }

    @discardableResult
    func restartReceiver() -> Task<Void, Never> {
        scheduleReceiverAction(.restart)
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

    @discardableResult
    func selectAdjacentItem(offset: Int) -> UUID? {
        guard offset != 0 else { return selectedItem?.id }
        let visibleItems = filteredItems
        guard !visibleItems.isEmpty else { return nil }

        let destination: Int
        if let selectedIndex = visibleItems.firstIndex(
            where: { selectedIDs.contains($0.id) }
        ) {
            destination = min(
                max(selectedIndex + offset, visibleItems.startIndex),
                visibleItems.index(before: visibleItems.endIndex)
            )
        } else {
            destination = offset > 0
                ? visibleItems.startIndex
                : visibleItems.index(before: visibleItems.endIndex)
        }

        let id = visibleItems[destination].id
        selectedIDs = [id]
        return id
    }

    private func handleLibraryNavigation(
        _ command: LibraryNavigationCommand
    ) -> Bool {
        guard libraryKeyboardNavigationEnabled,
              !libraryQuickLookBlocked
        else {
            return false
        }

        let offset: Int
        switch command {
        case .left:
            offset = -1
        case .right:
            offset = 1
        case .up:
            offset = layout == .grid ? -libraryGridColumnCount : -1
        case .down:
            offset = layout == .grid ? libraryGridColumnCount : 1
        }
        guard let selectedID = selectAdjacentItem(offset: offset) else {
            return false
        }
        libraryScrollTargetID = selectedID
        return true
    }

    func preview(_ item: MediaItemEntity) {
        presentPreview(startingWith: item, toggling: false)
    }

    func toggleSelectedPreview() {
        guard let item = selectedItem, !item.removed else { return }
        presentPreview(startingWith: item, toggling: true)
    }

    func reveal(_ item: MediaItemEntity) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    func renameSelected(to filename: String) async {
        guard let item = selectedItem, let repository else { return }
        let directoryGeneration = directoryConfigurationGeneration
        do {
            _ = try await repository.rename(item.uploadRecord, to: filename)
            await reloadLibrary(
                from: repository,
                directoryGeneration: directoryGeneration
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSelected() async {
        let selected = items.filter { selectedIDs.contains($0.id) && !$0.removed }
        _ = await deleteItems(selected)
    }

    private func presentPreview(
        startingWith item: MediaItemEntity,
        toggling: Bool
    ) {
        guard !item.removed else { return }
        let previewItems = filteredItems.filter { !$0.removed }
        guard let selectedIndex = previewItems.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        selectedIDs = [item.id]
        let urls = previewItems.map(\.fileURL)
        let idsByURL = Dictionary(
            uniqueKeysWithValues: previewItems.map { ($0.fileURL, $0.id) }
        )
        let onSelectionChange: @MainActor (URL) -> Void = { [weak self] url in
            guard let id = idsByURL[url] else { return }
            self?.selectedIDs = [id]
        }
        let onDelete: @MainActor (URL) async -> Bool = { [weak self] url in
            guard let self, let id = idsByURL[url] else { return false }
            return await self.deletePreviewItem(id: id)
        }

        if toggling {
            quickLookPreview.toggle(
                urls,
                selectedIndex: selectedIndex,
                onSelectionChange: onSelectionChange,
                onDelete: onDelete
            )
        } else {
            quickLookPreview.show(
                urls,
                selectedIndex: selectedIndex,
                onSelectionChange: onSelectionChange,
                onDelete: onDelete
            )
        }
    }

    private func deletePreviewItem(id: UUID) async -> Bool {
        guard let item = items.first(where: { $0.id == id && !$0.removed }) else {
            return false
        }
        return await deleteItems([item])
    }

    private func deleteItems(_ selected: [MediaItemEntity]) async -> Bool {
        guard let repository, !selected.isEmpty else { return false }
        let directoryGeneration = directoryConfigurationGeneration
        do {
            for item in selected {
                try await repository.delete(item.uploadRecord) { url in
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }
            }
            selectedIDs.subtract(selected.map(\.id))
            await reloadLibrary(
                from: repository,
                directoryGeneration: directoryGeneration
            )
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func clearDeletedItems() {
        let deleted = items.filter(\.removed)
        guard !deleted.isEmpty else { return }
        var keys = clearedDeletedKeys
        for item in deleted {
            keys.insert(identityKey(for: item))
            selectedIDs.remove(item.id)
            modelContext.delete(item)
        }
        clearedDeletedKeys = keys
        persistClearedDeletedKeys()
        try? modelContext.save()
        items.removeAll { $0.removed }
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

    @discardableResult
    func configureDirectory(
        _ directory: URL,
        startReceiverAfterConfiguration: Bool = true,
        persistBookmark: Bool = true
    ) -> Task<Void, Never> {
        configurationRequestGeneration &+= 1
        let generation = configurationRequestGeneration
        let cancellation = ConfigurationCancellation()
        let worker = Task { @MainActor [weak self] in
            await self?.prepareDirectoryConfiguration(
                directory,
                generation: generation,
                cancellation: cancellation,
                startReceiverAfterConfiguration: startReceiverAfterConfiguration,
                persistBookmark: persistBookmark
            )
        }
        return Task {
            await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                cancellation.cancel()
                Task { @MainActor [weak self] in
                    self?.cancelDirectoryConfiguration(generation)
                }
            }
        }
    }

    private func cancelDirectoryConfiguration(_ generation: UInt64) {
        guard generation == configurationRequestGeneration else { return }
        configurationRequestGeneration &+= 1
    }

    private func scheduleReceiverAction(_ action: ReceiverAction) -> Task<Void, Never> {
        let transition = beginReceiverTransition(invalidateConfigurations: true)
        return Task { @MainActor [weak self] in
            guard let self else { return }
            await self.stopServices(transition.services)
            guard transition.generation == self.receiverActionGeneration else {
                return
            }
            await self.performReceiverAction(
                action,
                generation: transition.generation
            )
        }
    }

    private func performReceiverAction(
        _ action: ReceiverAction,
        generation: UInt64
    ) async {
        switch action {
        case .start:
            await startReceiver(actionGeneration: generation)
        case .stop:
            uploadURL = ""
            status = receiveDirectory == nil ? .needsDirectory : .stopped
            logger.info("Receiver stopped")
        case .restart:
            if let repository {
                await reloadLibrary(
                    from: repository,
                    directoryGeneration: directoryConfigurationGeneration
                )
            }
            guard generation == receiverActionGeneration else { return }
            await startReceiver(actionGeneration: generation)
        }
    }

    private func prepareDirectoryConfiguration(
        _ directory: URL,
        generation: UInt64,
        cancellation: ConfigurationCancellation,
        startReceiverAfterConfiguration: Bool,
        persistBookmark: Bool
    ) async {
        guard isCurrentConfiguration(generation, cancellation: cancellation) else {
            return
        }
        let didStartAccess = directoryAccessClient.start(directory)
        let candidateRepository = LibraryRepository(rootURL: directory)
        let previousDirectory = receiveDirectory
        let previousSnapshot = ReceiverSnapshot(
            repository: repository,
            status: status,
            uploadURL: uploadURL
        )
        var records: [UploadRecord]
        do {
            records = try await libraryRecordsLoader(candidateRepository)
        } catch {
            releaseCandidateAccess(directory, didStartAccess: didStartAccess)
            guard isCurrentConfiguration(generation, cancellation: cancellation) else {
                return
            }
            lastError = error.localizedDescription
            return
        }

        guard isCurrentConfiguration(generation, cancellation: cancellation) else {
            releaseCandidateAccess(directory, didStartAccess: didStartAccess)
            return
        }

        if persistBookmark {
            do {
                try bookmarkClient.save(directory)
                bookmarkOwnerGeneration = generation
            } catch {
                releaseCandidateAccess(directory, didStartAccess: didStartAccess)
                lastError = error.localizedDescription
                return
            }
        }

        guard isCurrentConfiguration(generation, cancellation: cancellation) else {
            rollbackBookmarkIfOwned(
                by: generation,
                previousDirectory: previousDirectory
            )
            releaseCandidateAccess(directory, didStartAccess: didStartAccess)
            return
        }

        let transition = beginReceiverTransition(invalidateConfigurations: false)
        await stopServices(transition.services)

        guard transition.generation == receiverActionGeneration,
              isCurrentConfiguration(generation, cancellation: cancellation) else {
            rollbackBookmarkIfOwned(
                by: generation,
                previousDirectory: previousDirectory
            )
            releaseCandidateAccess(directory, didStartAccess: didStartAccess)
            if transition.generation == receiverActionGeneration {
                await restoreReceiver(
                    previousSnapshot,
                    actionGeneration: transition.generation
                )
            }
            return
        }

        if previousDirectory == directory {
            do {
                records = try await libraryRecordsLoader(candidateRepository)
            } catch {
                rollbackBookmarkIfOwned(
                    by: generation,
                    previousDirectory: previousDirectory
                )
                releaseCandidateAccess(directory, didStartAccess: didStartAccess)
                lastError = error.localizedDescription
                await restoreReceiver(
                    previousSnapshot,
                    actionGeneration: transition.generation
                )
                return
            }
            guard transition.generation == receiverActionGeneration,
                  isCurrentConfiguration(generation, cancellation: cancellation) else {
                rollbackBookmarkIfOwned(
                    by: generation,
                    previousDirectory: previousDirectory
                )
                releaseCandidateAccess(directory, didStartAccess: didStartAccess)
                if transition.generation == receiverActionGeneration {
                    await restoreReceiver(
                        previousSnapshot,
                        actionGeneration: transition.generation
                    )
                }
                return
            }
        }

        if let scopedDirectoryURL {
            directoryAccessClient.stop(scopedDirectoryURL)
        }
        scopedDirectoryURL = didStartAccess ? directory : nil
        receiveDirectory = directory
        repository = candidateRepository
        directoryConfigurationGeneration &+= 1
        syncDatabase(with: records)
        if bookmarkOwnerGeneration == generation {
            bookmarkOwnerGeneration = nil
        }
        uploadURL = ""
        status = .stopped

        guard startReceiverAfterConfiguration else { return }
        await startReceiver(actionGeneration: transition.generation)
    }

    private func isCurrentConfiguration(
        _ generation: UInt64,
        cancellation: ConfigurationCancellation
    ) -> Bool {
        !cancellation.isCancelled
            && generation == configurationRequestGeneration
    }

    private func rollbackBookmarkIfOwned(
        by generation: UInt64,
        previousDirectory: URL?
    ) {
        guard bookmarkOwnerGeneration == generation else { return }
        if let previousDirectory {
            do {
                try bookmarkClient.save(previousDirectory)
            } catch {
                bookmarkClient.clear()
                lastError = error.localizedDescription
            }
        } else {
            bookmarkClient.clear()
        }
        bookmarkOwnerGeneration = nil
    }

    private func releaseCandidateAccess(_ directory: URL, didStartAccess: Bool) {
        if didStartAccess {
            directoryAccessClient.stop(directory)
        }
    }

    private func beginReceiverTransition(
        invalidateConfigurations: Bool
    ) -> ReceiverTransition {
        if invalidateConfigurations {
            configurationRequestGeneration &+= 1
        }
        receiverActionGeneration &+= 1
        detachReceiverService()
        uploadURL = ""
        if receiveDirectory != nil {
            status = .stopped
        }
        let services = Array(stoppingServices.values)
        return ReceiverTransition(
            generation: receiverActionGeneration,
            services: services
        )
    }

    private func stopServices(
        _ services: [any ReceiverServiceControlling]
    ) async {
        for service in services {
            await service.stopAndWait()
            stoppingServices.removeValue(forKey: ObjectIdentifier(service))
        }
    }

    private func detachReceiverService() {
        receiverGeneration &+= 1
        receiverEventContinuation?.finish()
        receiverEventContinuation = nil
        receiverEventTask?.cancel()
        receiverEventTask = nil
        activeUploads.removeAll()
        clearTransientUploadFailure()
        guard let service = receiverService else { return }
        receiverService = nil
        stoppingServices[ObjectIdentifier(service)] = service
        service.stop()
    }

    private func attachReceiverService(to repository: LibraryRepository) {
        let generation = receiverGeneration
        let (stream, continuation) = AsyncStream<ReceiverServiceEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(64)
        )
        receiverEventContinuation = continuation
        receiverEventTask = Task { @MainActor [weak self] in
            for await event in stream {
                guard !Task.isCancelled else { break }
                self?.handle(event, generation: generation)
            }
        }
        receiverService = receiverServiceFactory(repository, port) { event in
            continuation.yield(event)
        }
    }

    private func startReceiver(actionGeneration: UInt64) async {
        guard receiveDirectory != nil else {
            status = .needsDirectory
            return
        }
        guard let repository else { return }
        attachReceiverService(to: repository)
        await startAttachedReceiver(actionGeneration: actionGeneration)
    }

    private func startAttachedReceiver(actionGeneration: UInt64) async {
        guard let receiverService else { return }
        let generation = receiverGeneration
        status = .starting
        do {
            let actualPort = try await receiverService.start()
            guard generation == receiverGeneration,
                  actionGeneration == receiverActionGeneration else {
                return
            }
            uploadURL = "http://\(SystemNetworkInfo.localIPv4Address()):\(actualPort)/uploads/"
            status = .running
            lastError = nil
            logger.info("Receiver started on port \(actualPort, privacy: .public)")
        } catch {
            guard generation == receiverGeneration,
                  actionGeneration == receiverActionGeneration else {
                return
            }
            status = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            logger.error("Receiver failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func restoreReceiver(
        _ snapshot: ReceiverSnapshot,
        actionGeneration: UInt64
    ) async {
        guard actionGeneration == receiverActionGeneration else { return }
        uploadURL = snapshot.uploadURL
        status = snapshot.status
        guard snapshot.repository != nil else { return }
        switch snapshot.status {
        case .running, .starting:
            await startReceiver(actionGeneration: actionGeneration)
        case .needsDirectory, .stopped, .failed:
            break
        }
    }

    func handle(_ event: ReceiverServiceEvent) {
        handle(event, generation: receiverGeneration)
    }

    func handle(_ event: ReceiverServiceEvent, generation: UInt64) {
        guard generation == receiverGeneration else { return }
        switch event {
        case let .started(port):
            uploadURL = "http://\(SystemNetworkInfo.localIPv4Address()):\(port)/uploads/"
            status = .running
        case .stopped:
            activeUploads.removeAll()
            clearTransientUploadFailure()
            resetTransferCard()
            if receiveDirectory != nil {
                status = .stopped
            }
        case let .uploadStarted(id, filename, expectedSize, batchIndex, batchTotal):
            activeUploads[id] = ActiveUpload(
                id: id,
                filename: filename,
                expectedSize: expectedSize,
                batchIndex: batchIndex,
                batchTotal: batchTotal
            )
            if transferCardState != .receiving {
                burstCompletedCount = 0
                burstBytesReceived = 0
                burstSawProgress = false
                burstExpectedCount = 0
                transferSamples.removeAll()
            }
            if let batchTotal, batchTotal > 0 {
                burstExpectedCount = max(burstExpectedCount, batchTotal)
            } else {
                burstExpectedCount = max(
                    burstExpectedCount,
                    burstCompletedCount + activeUploads.count
                )
            }
            transferCardState = .receiving
        case let .uploadProgress(id, bytesReceived, _):
            guard var upload = activeUploads[id] else { return }
            let delta = bytesReceived - upload.bytesReceived
            guard delta > 0 else { return }
            upload.bytesReceived = bytesReceived
            activeUploads[id] = upload
            burstSawProgress = true
            burstBytesReceived += delta
            let now = Date()
            transferSamples.append(
                TransferSample(time: now, totalBytes: burstBytesReceived)
            )
            transferSamples.removeAll {
                now.timeIntervalSince($0.time) > 3
            }
        case let .uploadStored(id, _):
            let storedUpload = activeUploads.removeValue(forKey: id)
            burstCompletedCount += 1
            if activeUploads.isEmpty,
               storedUpload.map(shouldFinishTransfer(after:)) ?? true {
                resetTransferCard()
            }
            guard let repository else { return }
            let directoryGeneration = directoryConfigurationGeneration
            Task {
                await reloadLibrary(
                    from: repository,
                    directoryGeneration: directoryGeneration,
                    receiverGeneration: generation
                )
            }
        case let .uploadFailed(id, filename, message):
            let failedUpload = activeUploads.removeValue(forKey: id)
            showTransientUploadFailure(filename: filename, message: message)
            if activeUploads.isEmpty,
               failedUpload.map(shouldFinishTransfer(after:)) ?? true {
                resetTransferCard()
            }
        case let .receiverFailed(message):
            activeUploads.removeAll()
            clearTransientUploadFailure()
            resetTransferCard()
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

    private func shouldFinishTransfer(after upload: ActiveUpload) -> Bool {
        if let batchIndex = upload.batchIndex,
           let batchTotal = upload.batchTotal,
           batchTotal > 0 {
            return batchIndex >= batchTotal
                || burstCompletedCount >= burstExpectedCount
        }
        return true
    }

    private func resetTransferCard() {
        transferCardState = .idle
        burstCompletedCount = 0
        burstBytesReceived = 0
        burstSawProgress = false
        burstExpectedCount = 0
        transferSamples.removeAll()
    }

    private func reloadLibrary(
        from repository: LibraryRepository,
        directoryGeneration: UInt64,
        receiverGeneration: UInt64? = nil
    ) async {
        do {
            let records = try await libraryRecordsLoader(repository)
            guard isCurrentRepository(
                repository,
                directoryGeneration: directoryGeneration,
                receiverGeneration: receiverGeneration
            ) else {
                return
            }
            syncDatabase(with: records)
        } catch {
            guard isCurrentRepository(
                repository,
                directoryGeneration: directoryGeneration,
                receiverGeneration: receiverGeneration
            ) else {
                return
            }
            lastError = error.localizedDescription
        }
    }

    private func isCurrentRepository(
        _ repository: LibraryRepository,
        directoryGeneration: UInt64,
        receiverGeneration: UInt64?
    ) -> Bool {
        guard let currentRepository = self.repository,
              currentRepository === repository,
              directoryGeneration == directoryConfigurationGeneration else {
            return false
        }
        if let receiverGeneration {
            return receiverGeneration == self.receiverGeneration
        }
        return true
    }

    private func syncDatabase(with records: [UploadRecord]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<MediaItemEntity>())) ?? []
        let existingByKey = Dictionary(
            uniqueKeysWithValues: existing.map { (identityKey(for: $0), $0) }
        )
        var retained = Set<PersistentIdentifier>()
        var result: [MediaItemEntity] = []

        var clearedKeys = clearedDeletedKeys
        var clearedKeysChanged = false

        for record in records {
            let key = record.stableID ?? record.fileURL.path
            if record.deleted && clearedKeys.contains(key) {
                continue
            }
            if !record.deleted && clearedKeys.remove(key) != nil {
                clearedKeysChanged = true
            }
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
        if clearedKeysChanged {
            clearedDeletedKeys = clearedKeys
            persistClearedDeletedKeys()
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

    private func persistClearedDeletedKeys() {
        userDefaults.set(
            Array(clearedDeletedKeys).sorted(),
            forKey: Self.clearedDeletedKeysDefaultsKey
        )
    }
}
