import AppKit
import SwiftUI

struct FocusFlowCommands: Commands {
    @ObservedObject var app: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandMenu("Timer") {
            Button(app.primaryActionTitle) {
                app.toggleTimer()
            }
            .keyboardShortcut(.space, modifiers: [.command, .option, .control])

            Button("Skip") {
                app.skip()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .control])

            Button("Previous") {
                app.previous()
            }

            Button("Reset Cycle") {
                app.resetCycle()
            }
            .keyboardShortcut("r", modifiers: [.command, .option, .control])

            Divider()

            Button("Show Timer") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "timer")
            }
            .keyboardShortcut("f", modifiers: [.command, .option, .control])

            Button("Statistics") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "statistics")
            }

            Button("Settings") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
