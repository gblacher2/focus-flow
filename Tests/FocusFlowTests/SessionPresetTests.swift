import FocusFlowCore
import Testing

@Test func builtInPresetsAreDistinctAndOrdered() {
    let presets = SessionPreset.all
    #expect(presets.map(\.id) == ["classic", "deepWork", "flow"])
    #expect(Set(presets.map(\.id)).count == presets.count)
}

@Test func applyingEachPresetMakesItTheMatchingPreset() {
    for preset in SessionPreset.all {
        var prefs = TimerPreferences()
        prefs.apply(preset)

        #expect(prefs.focusMinutes == preset.focusMinutes)
        #expect(prefs.shortBreakMinutes == preset.shortBreakMinutes)
        #expect(prefs.longBreakMinutes == preset.longBreakMinutes)
        #expect(prefs.sessionsBeforeLongBreak == preset.sessionsBeforeLongBreak)
        #expect(prefs.matchingPreset?.id == preset.id)
    }
}

@Test func defaultPreferencesMatchClassicPreset() {
    #expect(TimerPreferences().matchingPreset?.id == "classic")
}

@Test func flowPresetUsesTwentyMinuteBreak() {
    let flow = SessionPreset.all.first { $0.id == "flow" }
    #expect(flow?.focusMinutes == 90)
    #expect(flow?.shortBreakMinutes == 20)
}

@Test func customDurationsHaveNoMatchingPreset() {
    var prefs = TimerPreferences()
    prefs.apply(SessionPreset.all[1]) // Deep Work
    prefs.focusMinutes = 47           // off-preset fine-tune
    #expect(prefs.matchingPreset == nil)
}

@Test func presetDurationSummaryReadsFocusOverBreak() {
    let classic = SessionPreset.all[0]
    #expect(classic.durationSummary == "25 / 5 min")
}
