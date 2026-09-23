import AppKit
import ApplicationServices
import FocusFlowCore

enum TimerShortcutAction: CaseIterable {
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
    private var specs: [TimerShortcutAction: ShortcutSpec] = [:]

    func install(specs: [TimerShortcutAction: ShortcutSpec], handler: @escaping (TimerShortcutAction) -> Void) -> Status {
        self.specs = specs
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // A focused recorder must see existing bindings so it can reject
            // duplicates before AppKit menu key-equivalent dispatch consumes them.
            // Local NSEvent monitors run on the main event thread, so this is
            // a synchronous bridge to the recorder's main-actor lifecycle state.
            let keyCode = Int(event.keyCode)
            let modifierRawValue = event.modifierFlags.rawValue
            let recorderHandledEvent = MainActor.assumeIsolated {
                guard let recorder = _ShortcutRecorderNSView.activeRecorder else {
                    return false
                }
                recorder.handleRecordingKeyDown(
                    keyCode: keyCode,
                    modifierRawValue: modifierRawValue
                )
                return true
            }
            if recorderHandledEvent {
                return nil
            }
            guard let action = self?.action(for: event) else { return event }
            handler(action)
            return nil
        }

        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // Global monitor callbacks also arrive on AppKit's main event thread.
                let isRecorderActive = MainActor.assumeIsolated {
                    _ShortcutRecorderNSView.activeRecorder != nil
                }
                guard !isRecorderActive else { return }
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
        let keyCode = Int(event.keyCode)

        // Settings prevents duplicate assignments. If a malformed or legacy
        // preferences payload still contains one, keep dispatch deterministic.
        for action in TimerShortcutAction.allCases {
            guard let spec = specs[action] else { continue }
            if spec.matches(
                eventKeyCode: keyCode,
                eventModifierRawValue: event.modifierFlags.rawValue
            ) {
                return action
            }
        }
        return nil
    }
}
