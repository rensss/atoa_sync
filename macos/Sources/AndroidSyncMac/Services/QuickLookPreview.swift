import AppKit
@preconcurrency import QuickLookUI

@MainActor
protocol QuickLookPanel: AnyObject {
    var isVisible: Bool { get }
    var isKeyWindow: Bool { get }
    var currentPreviewItemIndex: Int { get set }

    func present(
        dataSource: any QLPreviewPanelDataSource,
        selectedIndex: Int,
        onVisibilityLost: @escaping @MainActor () -> Void
    )
    func reloadData()
    func dismiss()
}

@MainActor
protocol QuickLookPanelProviding {
    func existingPanel() -> (any QuickLookPanel)?
    func sharedPanel() -> (any QuickLookPanel)?
}

@MainActor
enum QuickLookKeyCommand {
    case close
    case previous
    case next
    case delete
}

@MainActor
protocol QuickLookKeyMonitoring: AnyObject {
    func start(handler: @escaping @MainActor (QuickLookKeyCommand) -> Bool)
    func stop()
}

@MainActor
private final class AppKitQuickLookKeyMonitor: QuickLookKeyMonitoring {
    private var monitor: Any?

    func start(handler: @escaping @MainActor (QuickLookKeyCommand) -> Bool) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.isEmpty else {
                return event
            }

            let command: QuickLookKeyCommand
            switch event.keyCode {
            case 49 where !event.isARepeat:
                command = .close
            case 123:
                command = .previous
            case 124:
                command = .next
            case 51 where !event.isARepeat,
                 117 where !event.isARepeat:
                command = .delete
            default:
                return event
            }
            return handler(command) ? nil : event
        }
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}

@MainActor
private final class AppKitQuickLookPanel: QuickLookPanel {
    private let panel: QLPreviewPanel
    private var visibilityObservers: [NSObjectProtocol] = []
    private var onVisibilityLost: (@MainActor () -> Void)?

    init(panel: QLPreviewPanel) {
        self.panel = panel
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var isKeyWindow: Bool {
        panel.isKeyWindow
    }

    var currentPreviewItemIndex: Int {
        get { panel.currentPreviewItemIndex }
        set { panel.currentPreviewItemIndex = newValue }
    }

    func present(
        dataSource: any QLPreviewPanelDataSource,
        selectedIndex: Int,
        onVisibilityLost: @escaping @MainActor () -> Void
    ) {
        stopObservingVisibility()
        self.onVisibilityLost = onVisibilityLost
        startObservingVisibility()
        panel.dataSource = dataSource
        panel.reloadData()
        panel.currentPreviewItemIndex = selectedIndex
        panel.makeKeyAndOrderFront(nil)
    }

    func reloadData() {
        panel.reloadData()
    }

    func dismiss() {
        stopObservingVisibility()
        panel.orderOut(nil)
        panel.dataSource = nil
    }

    private func startObservingVisibility() {
        let notifications: [Notification.Name] = [
            NSWindow.willCloseNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didResignKeyNotification
        ]
        visibilityObservers = notifications.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.notifyIfHidden()
                }
            }
        }
    }

    private func notifyIfHidden() {
        guard !panel.isVisible else { return }
        let handler = onVisibilityLost
        stopObservingVisibility()
        panel.dataSource = nil
        handler?()
    }

    private func stopObservingVisibility() {
        for observer in visibilityObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        visibilityObservers.removeAll()
        onVisibilityLost = nil
    }
}

@MainActor
private struct AppKitQuickLookPanelProvider: QuickLookPanelProviding {
    func existingPanel() -> (any QuickLookPanel)? {
        guard QLPreviewPanel.sharedPreviewPanelExists(),
              let panel = QLPreviewPanel.shared()
        else {
            return nil
        }
        return AppKitQuickLookPanel(panel: panel)
    }

    func sharedPanel() -> (any QuickLookPanel)? {
        guard let panel = QLPreviewPanel.shared() else { return nil }
        return AppKitQuickLookPanel(panel: panel)
    }
}

@MainActor
final class QuickLookPreview: NSObject {
    static let shared = QuickLookPreview()

    private let panelProvider: any QuickLookPanelProviding
    private let keyMonitor: any QuickLookKeyMonitoring
    private var activePanel: (any QuickLookPanel)?
    private var urls: [URL] = []
    private var currentIndex = 0
    private var onSelectionChange: (@MainActor (URL) -> Void)?
    private var onDelete: (@MainActor (URL) async -> Bool)?
    private var deletionInProgress = false
    private(set) var url: URL?

    init(
        panelProvider: any QuickLookPanelProviding = AppKitQuickLookPanelProvider(),
        keyMonitor: any QuickLookKeyMonitoring = AppKitQuickLookKeyMonitor()
    ) {
        self.panelProvider = panelProvider
        self.keyMonitor = keyMonitor
        super.init()
    }

    func show(_ url: URL) {
        show([url], selectedIndex: 0)
    }

    func show(
        _ urls: [URL],
        selectedIndex: Int,
        onSelectionChange: @escaping @MainActor (URL) -> Void = { _ in },
        onDelete: @escaping @MainActor (URL) async -> Bool = { _ in false }
    ) {
        guard urls.indices.contains(selectedIndex) else {
            close()
            return
        }
        self.urls = urls
        currentIndex = selectedIndex
        url = urls[selectedIndex]
        self.onSelectionChange = onSelectionChange
        self.onDelete = onDelete

        let panel: any QuickLookPanel
        if let activePanel {
            panel = activePanel
        } else {
            guard let sharedPanel = panelProvider.sharedPanel() else {
                self.url = nil
                return
            }
            panel = sharedPanel
            activePanel = sharedPanel
        }
        panel.present(dataSource: self, selectedIndex: selectedIndex) { [weak self] in
            self?.clearPreviewState()
        }
        installKeyMonitor()
    }

    func toggle(_ url: URL) {
        toggle([url], selectedIndex: 0)
    }

    func toggle(
        _ urls: [URL],
        selectedIndex: Int,
        onSelectionChange: @escaping @MainActor (URL) -> Void = { _ in },
        onDelete: @escaping @MainActor (URL) async -> Bool = { _ in false }
    ) {
        if let panel = activePanel, panel.isVisible {
            close(panel)
        } else if let panel = panelProvider.existingPanel(), panel.isVisible {
            activePanel = panel
            close(panel)
        } else {
            show(
                urls,
                selectedIndex: selectedIndex,
                onSelectionChange: onSelectionChange,
                onDelete: onDelete
            )
        }
    }

    func close() {
        if let panel = activePanel {
            close(panel)
            return
        }
        guard let panel = panelProvider.existingPanel() else {
            clearPreviewState()
            return
        }
        close(panel)
    }

    private func close(_ panel: any QuickLookPanel) {
        panel.dismiss()
        clearPreviewState()
    }

    private func installKeyMonitor() {
        keyMonitor.start { [weak self] command in
            guard let self,
                  let panel = self.activePanel,
                  panel.isVisible,
                  panel.isKeyWindow
            else {
                return false
            }

            switch command {
            case .close:
                self.close(panel)
            case .previous:
                self.move(by: -1, in: panel)
            case .next:
                self.move(by: 1, in: panel)
            case .delete:
                self.deleteCurrentItem(from: panel)
            }
            return true
        }
    }

    private func move(by offset: Int, in panel: any QuickLookPanel) {
        let destination = min(max(currentIndex + offset, 0), urls.count - 1)
        guard destination != currentIndex else { return }
        currentIndex = destination
        url = urls[destination]
        panel.currentPreviewItemIndex = destination
        onSelectionChange?(urls[destination])
    }

    private func deleteCurrentItem(from panel: any QuickLookPanel) {
        guard !deletionInProgress,
              urls.indices.contains(currentIndex),
              let onDelete
        else {
            return
        }
        deletionInProgress = true
        let deletingURL = urls[currentIndex]

        Task { @MainActor [weak self, weak panel] in
            let deleted = await onDelete(deletingURL)
            guard let self else { return }
            self.deletionInProgress = false
            guard deleted,
                  let panel,
                  panel.isVisible,
                  let removedIndex = self.urls.firstIndex(of: deletingURL)
            else {
                return
            }
            self.removePreview(at: removedIndex, from: panel)
        }
    }

    private func removePreview(at removedIndex: Int, from panel: any QuickLookPanel) {
        let previouslySelectedURL = url
        let removedURL = urls[removedIndex]
        urls.remove(at: removedIndex)
        guard !urls.isEmpty else {
            close(panel)
            return
        }

        if previouslySelectedURL == removedURL {
            currentIndex = min(removedIndex, urls.count - 1)
        } else if let previouslySelectedURL,
                  let retainedIndex = urls.firstIndex(of: previouslySelectedURL) {
            currentIndex = retainedIndex
        } else {
            currentIndex = min(removedIndex, urls.count - 1)
        }
        url = urls[currentIndex]
        panel.reloadData()
        panel.currentPreviewItemIndex = currentIndex
        onSelectionChange?(urls[currentIndex])
    }

    private func clearPreviewState() {
        keyMonitor.stop()
        activePanel = nil
        urls.removeAll()
        currentIndex = 0
        onSelectionChange = nil
        onDelete = nil
        deletionInProgress = false
        url = nil
    }
}

extension QuickLookPreview: @preconcurrency QLPreviewPanelDataSource {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> any QLPreviewItem {
        urls[index] as NSURL
    }
}
