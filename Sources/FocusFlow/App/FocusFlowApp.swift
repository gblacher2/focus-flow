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

        // The menu bar item is owned entirely by StatusItemController
        // (an AppKit NSStatusItem), not by SwiftUI's MenuBarExtra, so that
        // we can distinguish left-click from right-click reliably via
        // sendAction(on:). See StatusItemController.swift.
        //
        .commands {
            FocusFlowCommands(app: app)
        }
    }
}
