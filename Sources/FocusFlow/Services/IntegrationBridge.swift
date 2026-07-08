import AppKit
import Foundation
import FocusFlowCore

private struct SendableObserver: @unchecked Sendable {
    let value: any NSObjectProtocol
}

@MainActor
final class IntegrationBridge {
    static let stateChangedName = Notification.Name("com.gblacher.focusflow.stateChanged")
    static let commandName = Notification.Name("com.gblacher.focusflow.command")

    private weak var app: AppModel?
    private var observer: SendableObserver?

    init(app: AppModel) {
        self.app = app
        
        let obs = DistributedNotificationCenter.default().addObserver(
            forName: Self.commandName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let command = notification.object as? String else { return }
            Task { @MainActor in
                self.handleCommand(command)
            }
        }
        self.observer = SendableObserver(value: obs)
    }

    deinit {
        if let observer = observer {
            DistributedNotificationCenter.default().removeObserver(observer.value)
        }
    }

    func postStateChanged() {
        DistributedNotificationCenter.default().postNotificationName(
            Self.stateChangedName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func handleCommand(_ command: String) {
        guard let app = app else { return }
        switch command {
        case "toggle":
            app.toggleTimer()
        case "startFocus":
            if !app.engine.isRunning {
                app.toggleTimer()
            }
        case "pause":
            if app.engine.isRunning {
                app.toggleTimer()
            }
        case "resume":
            if !app.engine.isRunning {
                app.toggleTimer()
            }
        case "skip":
            app.skip()
        case "reset":
            app.resetCycle()
        default:
            break
        }
    }
}
