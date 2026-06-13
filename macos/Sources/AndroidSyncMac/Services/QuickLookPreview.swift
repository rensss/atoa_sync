import AppKit
@preconcurrency import QuickLookUI

@MainActor
protocol QuickLookPanel: AnyObject {
    var isVisible: Bool { get }

    func present(dataSource: any QLPreviewPanelDataSource)
    func dismiss()
}

@MainActor
protocol QuickLookPanelProviding {
    func existingPanel() -> (any QuickLookPanel)?
    func sharedPanel() -> (any QuickLookPanel)?
}

@MainActor
private final class AppKitQuickLookPanel: QuickLookPanel {
    private let panel: QLPreviewPanel

    init(panel: QLPreviewPanel) {
        self.panel = panel
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func present(dataSource: any QLPreviewPanelDataSource) {
        panel.dataSource = dataSource
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        panel.orderOut(nil)
        panel.dataSource = nil
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
    private(set) var url: URL?

    init(
        panelProvider: any QuickLookPanelProviding = AppKitQuickLookPanelProvider()
    ) {
        self.panelProvider = panelProvider
        super.init()
    }

    func show(_ url: URL) {
        self.url = url
        guard let panel = panelProvider.sharedPanel() else {
            self.url = nil
            return
        }
        panel.present(dataSource: self)
    }

    func toggle(_ url: URL) {
        if let panel = panelProvider.existingPanel(), panel.isVisible {
            close(panel)
        } else {
            show(url)
        }
    }

    func close() {
        guard let panel = panelProvider.existingPanel() else {
            url = nil
            return
        }
        close(panel)
    }

    private func close(_ panel: any QuickLookPanel) {
        panel.dismiss()
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
