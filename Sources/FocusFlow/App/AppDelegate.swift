import AppKit
import SwiftUI
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var didOpenAtLaunch = false

    static let bridgeLog = Logger(subsystem: "com.gabrielblacher.FocusFlow", category: "bridge")

    /// SwiftUI installs its own internal object as `NSApp.delegate` and only
    /// forwards callbacks to the `@NSApplicationDelegateAdaptor` instance, so
    /// `NSApp.delegate as? AppDelegate` never succeeds. AppModel reaches the
    /// adaptor-created instance through this reference instead.
    private(set) static weak var shared: AppDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Creates the off-screen EnvironmentBridgeView in an un-ordered window
    /// to capture SwiftUI environment closures. Show-at-launch lives in the
    /// bridge's `.task` — the closures don't exist until it runs, so opening
    /// the timer window from here would call a still-nil `openTimerWindow`.
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
            // The window is never ordered in; force layout so the hosting
            // view renders and its `.task` actually fires.
            win.contentView?.layoutSubtreeIfNeeded()
            self.window = win

            // StatusItemController has behavioral fallbacks when the closures
            // stay nil, but a wiring failure should still be visible in logs.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if app.openTimerWindow == nil {
                    Self.bridgeLog.fault("Environment bridge never wired openWindow/openSettings closures")
                }
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

                // Show-at-launch must run after the closures above exist;
                // `attachIfNeeded` guards this view's one-time creation, so
                // this task body runs at most once.
                if app.preferences.showWindowAtLaunch {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "timer")
                }
            }
    }
}
