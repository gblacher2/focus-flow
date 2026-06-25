import AppKit
import ApplicationServices

enum TimerShortcutAction {
    case toggleTimer
    case skip
    case reset
    case showTimer
}

final class ShortcutService {
    enum Status: Equatable {
        case inactive
        case activeGlobal
        case localOnly

        var displayName: String {
            switch self {
            case .inactive: "Inactive"
            case .activeGlobal: "Global shortcuts active"
            case .localOnly: "Local shortcuts active"
            }
        }
    }

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func install(handler: @escaping (TimerShortcutAction) -> Void) -> Status {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let action = self?.action(for: event) else { return event }
            handler(action)
            return nil
        }

        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let action = self?.action(for: event) else { return }
                handler(action)
            }
            return .activeGlobal
        }

        return .localOnly
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        localMonitor = nil
        globalMonitor = nil
    }

    private func action(for event: NSEvent) -> TimerShortcutAction? {
        let required: NSEvent.ModifierFlags = [.command, .option, .control]
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isSuperset(of: required) else {
            return nil
        }

        switch event.keyCode {
        case 49:
            return .toggleTimer
        case 124:
            return .skip
        case 15:
            return .reset
        case 3:
            return .showTimer
        default:
            return nil
        }
    }
}
