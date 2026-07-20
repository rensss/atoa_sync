import AppKit
import QuickLookUI

enum LibraryNavigationCommand {
    case left
    case right
    case up
    case down
}

@MainActor
protocol LibraryKeyMonitoring: AnyObject {
    func start(handler: @escaping @MainActor (LibraryNavigationCommand) -> Bool)
    func stop()
}

@MainActor
final class AppKitLibraryKeyMonitor: LibraryKeyMonitoring {
    private var monitor: Any?

    func start(handler: @escaping @MainActor (LibraryNavigationCommand) -> Bool) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.isEmpty,
                  !(NSApp.keyWindow is QLPreviewPanel),
                  !Self.textInputIsFirstResponder
            else {
                return event
            }

            let command: LibraryNavigationCommand
            switch event.keyCode {
            case 123:
                command = .left
            case 124:
                command = .right
            case 125:
                command = .down
            case 126:
                command = .up
            default:
                return event
            }
            return handler(command) ? nil : event
        }
    }

    private static var textInputIsFirstResponder: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else {
            return false
        }
        return responder is NSTextView || responder is NSTextField
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}
