import AppKit
import CoreGraphics
import Foundation

@MainActor
final class IdleMonitorService {
    private var pollTimer: Foundation.Timer?
    private var onReturn: (() -> Void)?

    func secondsSinceLastInput() -> TimeInterval {
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    func startReturnPoll(onReturn: @escaping () -> Void) {
        stopReturnPoll()
        self.onReturn = onReturn

        let timer = Foundation.Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        timer.tolerance = 1.0
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopReturnPoll() {
        pollTimer?.invalidate()
        pollTimer = nil
        onReturn = nil
    }

    private func poll() {
        if secondsSinceLastInput() < 5.0 {
            let callback = onReturn
            stopReturnPoll()
            callback?()
        }
    }
}
