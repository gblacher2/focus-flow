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
            .optionalKeyboardShortcut(app.preferences.toggleShortcut.swiftUIKeyEquivalent, modifiers: app.preferences.toggleShortcut.swiftUIModifiers)

            Button("Skip") {
                app.skip()
            }
            .optionalKeyboardShortcut(app.preferences.skipShortcut.swiftUIKeyEquivalent, modifiers: app.preferences.skipShortcut.swiftUIModifiers)

            Button("Previous") {
                app.previous()
            }

            Button("Reset Cycle") {
                app.resetCycle()
            }
            .optionalKeyboardShortcut(app.preferences.resetShortcut.swiftUIKeyEquivalent, modifiers: app.preferences.resetShortcut.swiftUIModifiers)

            Divider()

            Button("Show Timer") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "timer")
            }
            .optionalKeyboardShortcut(app.preferences.showTimerShortcut.swiftUIKeyEquivalent, modifiers: app.preferences.showTimerShortcut.swiftUIModifiers)

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

extension Button {
    @ViewBuilder
    func optionalKeyboardShortcut(_ keyEquivalent: KeyEquivalent?, modifiers: EventModifiers) -> some View {
        if let keyEquivalent {
            self.keyboardShortcut(keyEquivalent, modifiers: modifiers)
        } else {
            self
        }
    }
}
