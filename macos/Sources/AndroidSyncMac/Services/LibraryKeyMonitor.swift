import AppKit
import QuickLookUI

enum LibraryNavigationCommand: Equatable {
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
            guard !(NSApp.keyWindow is QLPreviewPanel),
                  !Self.textInputIsFirstResponder
            else {
                return event
            }

            guard let command = Self.command(
                forKeyCode: event.keyCode,
                modifierFlags: event.modifierFlags
            ) else {
                return event
            }
            return handler(command) ? nil : event
        }
    }

    static func command(
        forKeyCode keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> LibraryNavigationCommand? {
        let userModifiers = modifierFlags.intersection([
            .command,
            .control,
            .option,
            .shift
        ])
        guard userModifiers.isEmpty else { return nil }

        switch keyCode {
        case 123:
            return .left
        case 124:
            return .right
        case 125:
            return .down
        case 126:
            return .up
        default:
            return nil
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
