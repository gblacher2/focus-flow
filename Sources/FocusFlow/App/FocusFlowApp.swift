import AppKit
import FocusFlowCore
import SwiftUI

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var app = AppModel()

    var body: some Scene {
        Window("FocusFlow", id: "timer") {
            ContentView(app: app)
                .frame(minWidth: 300, idealWidth: 312, minHeight: 370, idealHeight: 398)
        }
        .defaultSize(width: 312, height: 398)
        .windowResizability(.contentSize)

        Window("Statistics", id: "statistics") {
            StatisticsView(app: app)
                .frame(minWidth: 700, minHeight: 480)
        }
        .defaultSize(width: 740, height: 520)

        Settings {
            SettingsView(app: app)
        }

        MenuBarExtra {
            MenuBarView(app: app)
        } label: {
            MenuBarClockLabel(app: app)
        }

        .commands {
            FocusFlowCommands(app: app)
        }
    }
}

private struct MenuBarClockLabel: View {
    @ObservedObject var app: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var didOpenAtLaunch = false

    private var isIdle: Bool {
        app.engine.phase == .ready || app.engine.phase == .completed
    }

    private var showsCountdown: Bool {
        !isIdle || app.preferences.showCountdownWhenIdle
    }

    var body: some View {
        HStack(spacing: 4) {
            menuBarIcon
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.phase(app.engine.displayPhase))
            if showsCountdown {
                Text(app.menuBarTitle)
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.medium))
            }
        }
        .accessibilityLabel(showsCountdown ? "FocusFlow timer \(app.menuBarTitle)" : "FocusFlow timer, idle")
        .task {
            // The menu-bar label is the only view guaranteed to instantiate at
            // launch in an .accessory app, so it drives the "open window at
            // launch" preference, and it hands AppModel a way to reopen the timer
            // window (e.g. via ⌃⌥⌘F) after the user has closed it — AppModel has
            // no SwiftUI environment of its own to call openWindow directly.
            app.openTimerWindow = { openWindow(id: "timer") }

            guard !didOpenAtLaunch else { return }
            didOpenAtLaunch = true
            if app.preferences.showWindowAtLaunch {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "timer")
            }
        }
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        let icon = app.menuBarIcon
        if let variableValue = icon.variableValue {
            Image(systemName: icon.systemName, variableValue: variableValue)
        } else {
            Image(systemName: icon.systemName)
        }
    }
}
