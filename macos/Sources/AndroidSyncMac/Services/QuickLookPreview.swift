import AppKit
@preconcurrency import QuickLookUI

@MainActor
protocol QuickLookPanel: AnyObject {
    var isVisible: Bool { get }
    var isKeyWindow: Bool { get }

    func present(
        dataSource: any QLPreviewPanelDataSource,
        onVisibilityLost: @escaping @MainActor () -> Void
    )
    func dismiss()
}

@MainActor
protocol QuickLookPanelProviding {
    func existingPanel() -> (any QuickLookPanel)?
    func sharedPanel() -> (any QuickLookPanel)?
}

@MainActor
protocol QuickLookSpaceKeyMonitoring: AnyObject {
    func start(handler: @escaping @MainActor () -> Bool)
    func stop()
}

@MainActor
private final class AppKitQuickLookSpaceKeyMonitor: QuickLookSpaceKeyMonitoring {
    private var monitor: Any?

    func start(handler: @escaping @MainActor () -> Bool) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == 49, modifiers.isEmpty, !event.isARepeat else {
                return event
            }
            return handler() ? nil : event
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

    func present(
        dataSource: any QLPreviewPanelDataSource,
        onVisibilityLost: @escaping @MainActor () -> Void
    ) {
        stopObservingVisibility()
        self.onVisibilityLost = onVisibilityLost
        startObservingVisibility()
        panel.dataSource = dataSource
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
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
    private let spaceKeyMonitor: any QuickLookSpaceKeyMonitoring
    private var activePanel: (any QuickLookPanel)?
    private(set) var url: URL?

    init(
        panelProvider: any QuickLookPanelProviding = AppKitQuickLookPanelProvider(),
        spaceKeyMonitor: any QuickLookSpaceKeyMonitoring = AppKitQuickLookSpaceKeyMonitor()
    ) {
        self.panelProvider = panelProvider
        self.spaceKeyMonitor = spaceKeyMonitor
        super.init()
    }

    func show(_ url: URL) {
        self.url = url
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
        panel.present(dataSource: self) { [weak self] in
            self?.clearPreviewState()
        }
        installSpaceKeyMonitor()
    }

    func toggle(_ url: URL) {
        if let panel = activePanel, panel.isVisible {
            close(panel)
        } else if let panel = panelProvider.existingPanel(), panel.isVisible {
            activePanel = panel
            close(panel)
        } else {
            show(url)
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

    private func installSpaceKeyMonitor() {
        spaceKeyMonitor.start { [weak self] in
            guard let self,
                  let panel = self.activePanel,
                  panel.isVisible,
                  panel.isKeyWindow
            else {
                return false
            }
            self.close(panel)
            return true
        }
    }

    private func clearPreviewState() {
        spaceKeyMonitor.stop()
        activePanel = nil
        url = nil
    }
}

extension QuickLookPreview: @preconcurrency QLPreviewPanelDataSource {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> any QLPreviewItem {
        url! as NSURL
    }
}
