import FocusFlowCore
import SwiftUI

extension Color {
    /// Canonical phase accent color. Single source of truth for phase tinting
    /// across the timer ring, menu bar, and statistics.
    static func phase(_ phase: TimerPhase) -> Color {
        switch phase {
        case .focus:
            .accentColor
        case .shortBreak:
            .green
        case .longBreak:
            .teal
        case .ready, .paused, .completed:
            .secondary
        }
    }

    /// Canonical tag color resolved from a stored color name.
    static func tag(_ name: String) -> Color {
        switch name {
        case "green":
            .green
        case "orange":
            .orange
        case "purple":
            .purple
        case "pink":
            .pink
        default:
            .blue
        }
    }
}

/// The tag color names offered in the UI, in display order.
enum TagPalette {
    static let names = ["blue", "green", "orange", "purple", "pink"]
}
