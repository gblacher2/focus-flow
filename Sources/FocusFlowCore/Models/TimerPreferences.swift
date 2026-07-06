import Foundation

public struct TimerPreferences: Codable, Equatable, Sendable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var sessionsBeforeLongBreak: Int
    public var autoStartBreaks: Bool
    public var autoStartFocus: Bool
    public var notificationsEnabled: Bool
    public var soundsEnabled: Bool
    public var focusCompleteSound: TimerSound
    public var breakCompleteSound: TimerSound
    public var showWindowAtLaunch: Bool
    public var showCountdownWhenIdle: Bool

    public init(
        focusMinutes: Int = 25,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 15,
        sessionsBeforeLongBreak: Int = 4,
        autoStartBreaks: Bool = false,
        autoStartFocus: Bool = false,
        notificationsEnabled: Bool = true,
        soundsEnabled: Bool = true,
        focusCompleteSound: TimerSound = .ping,
        breakCompleteSound: TimerSound = .glass,
        showWindowAtLaunch: Bool = false,
        showCountdownWhenIdle: Bool = false
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.sessionsBeforeLongBreak = sessionsBeforeLongBreak
        self.autoStartBreaks = autoStartBreaks
        self.autoStartFocus = autoStartFocus
        self.notificationsEnabled = notificationsEnabled
        self.soundsEnabled = soundsEnabled
        self.focusCompleteSound = focusCompleteSound
        self.breakCompleteSound = breakCompleteSound
        self.showWindowAtLaunch = showWindowAtLaunch
        self.showCountdownWhenIdle = showCountdownWhenIdle
        self.validate()
    }

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case shortBreakMinutes
        case longBreakMinutes
        case sessionsBeforeLongBreak
        case autoStartBreaks
        case autoStartFocus
        case notificationsEnabled
        case soundsEnabled
        case focusCompleteSound
        case breakCompleteSound
        case showWindowAtLaunch
        case showCountdownWhenIdle
    }

    // Explicit decoding so that JSON persisted before newer preference keys
    // existed can still decode cleanly by defaulting them, rather than
    // throwing and sending PreferencesStore.load() down its all-defaults
    // fallback path (which would silently wipe the user's real settings).
    // Other fields keep strict decoding since they've always been present in
    // persisted payloads.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decode(Int.self, forKey: .focusMinutes)
        shortBreakMinutes = try container.decode(Int.self, forKey: .shortBreakMinutes)
        longBreakMinutes = try container.decode(Int.self, forKey: .longBreakMinutes)
        sessionsBeforeLongBreak = try container.decode(Int.self, forKey: .sessionsBeforeLongBreak)
        autoStartBreaks = try container.decode(Bool.self, forKey: .autoStartBreaks)
        autoStartFocus = try container.decode(Bool.self, forKey: .autoStartFocus)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        soundsEnabled = try container.decode(Bool.self, forKey: .soundsEnabled)
        focusCompleteSound = try container.decode(TimerSound.self, forKey: .focusCompleteSound)
        breakCompleteSound = try container.decode(TimerSound.self, forKey: .breakCompleteSound)
        showWindowAtLaunch = try container.decodeIfPresent(Bool.self, forKey: .showWindowAtLaunch) ?? false
        showCountdownWhenIdle = try container.decodeIfPresent(Bool.self, forKey: .showCountdownWhenIdle) ?? false
        validate()
    }

    public var focusSeconds: Int { focusMinutes * 60 }
    public var shortBreakSeconds: Int { shortBreakMinutes * 60 }
    public var longBreakSeconds: Int { longBreakMinutes * 60 }

    /// The built-in preset whose durations and cycle length exactly match the
    /// current preferences, or `nil` when the values are custom.
    public var matchingPreset: SessionPreset? {
        SessionPreset.all.first { preset in
            preset.focusMinutes == focusMinutes &&
                preset.shortBreakMinutes == shortBreakMinutes &&
                preset.longBreakMinutes == longBreakMinutes &&
                preset.sessionsBeforeLongBreak == sessionsBeforeLongBreak
        }
    }

    /// Applies a preset's durations and cycle length. Other behavior settings
    /// (auto-start, sounds, notifications) are left untouched.
    public mutating func apply(_ preset: SessionPreset) {
        focusMinutes = preset.focusMinutes
        shortBreakMinutes = preset.shortBreakMinutes
        longBreakMinutes = preset.longBreakMinutes
        sessionsBeforeLongBreak = preset.sessionsBeforeLongBreak
        validate()
    }

    public mutating func validate() {
        focusMinutes = Self.clamp(focusMinutes, lower: 1, upper: 240)
        shortBreakMinutes = Self.clamp(shortBreakMinutes, lower: 1, upper: 120)
        longBreakMinutes = Self.clamp(longBreakMinutes, lower: 1, upper: 240)
        sessionsBeforeLongBreak = Self.clamp(sessionsBeforeLongBreak, lower: 1, upper: 12)
    }

    public func validated() -> TimerPreferences {
        var copy = self
        copy.validate()
        return copy
    }

    private static func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

public enum TimerSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case basso = "Basso"
    case glass = "Glass"
    case hero = "Hero"
    case ping = "Ping"
    case pop = "Pop"
    case submarine = "Submarine"
    case tink = "Tink"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}
