import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var didOpenAtLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Creates the off-screen EnvironmentBridgeView in an un-ordered window
    /// to capture SwiftUI environment closures, and opens the timer window
    /// if showWindowAtLaunch is enabled.
    func attachIfNeeded(app: AppModel) {
        guard !didOpenAtLaunch else { return }
        didOpenAtLaunch = true

        // Run on the next run-loop pass so SwiftUI has fully set up the app environment
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let win = NSWindow(
                contentRect: NSRect(x: -100, y: -100, width: 1, height: 1),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isReleasedWhenClosed = false
            win.isExcludedFromWindowsMenu = true
            win.contentView = NSHostingView(rootView: EnvironmentBridgeView(app: app))
            self.window = win

            if app.preferences.showWindowAtLaunch {
                NSApp.activate(ignoringOtherApps: true)
                app.openTimerWindow?()
            }
        }
    }
}

private struct EnvironmentBridgeView: View {
    let app: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                app.openTimerWindow = { openWindow(id: "timer") }
                app.openStatisticsWindow = { openWindow(id: "statistics") }
                app.openSettingsWindow = { openSettings() }
            }
    }
}
