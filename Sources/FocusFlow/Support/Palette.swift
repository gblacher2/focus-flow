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

    /// A subtle wash (10% opacity) of the canonical phase color.
    static func phaseWash(_ phase: TimerPhase) -> Color {
        Color.phase(phase).opacity(0.10)
    }

    /// The gradient used for the timer ring, derived from the canonical phase color.
    static func phaseGradient(_ phase: TimerPhase) -> AngularGradient {
        let base = Color.phase(phase)
        return AngularGradient(
            colors: [base.opacity(0.6), base],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
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
