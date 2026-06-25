import Foundation

/// A named focus-session rhythm that sets the timer's durations and cycle length
/// in one tap. Presets are a curated layer on top of `TimerPreferences` — applying
/// one writes the four duration/cycle fields, while the user can still fine-tune
/// each value afterward (which makes the active preset "Custom").
public struct SessionPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let focusMinutes: Int
    public let shortBreakMinutes: Int
    public let longBreakMinutes: Int
    public let sessionsBeforeLongBreak: Int
    public let bestFor: String

    public init(
        id: String,
        name: String,
        focusMinutes: Int,
        shortBreakMinutes: Int,
        longBreakMinutes: Int,
        sessionsBeforeLongBreak: Int,
        bestFor: String
    ) {
        self.id = id
        self.name = name
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.sessionsBeforeLongBreak = sessionsBeforeLongBreak
        self.bestFor = bestFor
    }

    /// Short "focus / break" summary, e.g. "25 / 5 min".
    public var durationSummary: String {
        "\(focusMinutes) / \(shortBreakMinutes) min"
    }

    /// The built-in presets, in display order. Longer focus blocks get longer
    /// rests and fewer sessions before a long break.
    public static let all: [SessionPreset] = [
        SessionPreset(
            id: "classic",
            name: "Classic",
            focusMinutes: 25,
            shortBreakMinutes: 5,
            longBreakMinutes: 15,
            sessionsBeforeLongBreak: 4,
            bestFor: "Starting, studying, admin"
        ),
        SessionPreset(
            id: "deepWork",
            name: "Deep Work",
            focusMinutes: 50,
            shortBreakMinutes: 10,
            longBreakMinutes: 20,
            sessionsBeforeLongBreak: 3,
            bestFor: "Deep study or writing"
        ),
        SessionPreset(
            id: "flow",
            name: "Flow",
            focusMinutes: 90,
            shortBreakMinutes: 20,
            longBreakMinutes: 30,
            sessionsBeforeLongBreak: 2,
            bestFor: "High-focus work, fewer context switches"
        )
    ]
}
