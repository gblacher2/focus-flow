import FocusFlowCore
import Foundation

struct PreferencesStore {
    private let key = "com.gabrielblacher.FocusFlow.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TimerPreferences {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(TimerPreferences.self, from: data)
        else {
            return TimerPreferences()
        }
        return decoded.validated()
    }

    func save(_ preferences: TimerPreferences) {
        guard let data = try? JSONEncoder().encode(preferences.validated()) else { return }
        defaults.set(data, forKey: key)
    }
}
