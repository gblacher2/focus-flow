import FocusFlowCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            timerRing

            Spacer(minLength: 12)

            sessionControls
                .padding(.bottom, 12)

            titleAndTag
                .padding(.horizontal, 22)

            Spacer(minLength: 6)

            if let error = app.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 296, idealWidth: 312)
        .scenePadding(.vertical)
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Track
            Circle()
                .stroke(.quaternary, lineWidth: 6)

            // Progress arc
            Circle()
                .trim(from: 0, to: visibleProgress)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: app.progress)

            if let tag = app.selectedTag {
                tagRingDot(tag)
            }

            // Center content
            VStack(spacing: 5) {
                Text(DurationFormatter.clock(app.engine.remainingSeconds))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .monospacedDigit()

                phaseLabel

                if let tag = app.selectedTag {
                    timerTagAccent(tag)
                }
            }
        }
        .frame(width: 198, height: 198)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringAccessibilityLabel)
        .accessibilityValue(ringAccessibilityValue)
    }

    private var ringAccessibilityLabel: String {
        "\(app.engine.displayPhase.displayName) timer"
    }

    private var ringAccessibilityValue: String {
        let remaining = remainingSpokenTime
        switch app.engine.phase {
        case .ready:
            return "Ready"
        case .focus, .shortBreak, .longBreak:
            return "\(remaining) remaining, session \(spokenCycleLabel)"
        case .paused:
            return "Paused, \(remaining) remaining"
        case .completed:
            return "Complete. Next: \(app.engine.pendingPhase.displayName)"
        }
    }

    private var remainingSpokenTime: String {
        let total = max(0, app.engine.remainingSeconds)
        let minutes = total / 60
        let seconds = total % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if seconds > 0 { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: " ")
    }

    private var phaseLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: phaseIcon)
                .font(.caption2)

            Text(phaseLabelText)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.secondary)
    }

    private func timerTagAccent(_ tag: Tag) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.tag(tag.colorName))
                .frame(width: 7, height: 7)
            Text(tag.title)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: 118)
    }

    private func tagRingDot(_ tag: Tag) -> some View {
        Circle()
            .fill(Color.tag(tag.colorName))
            .frame(width: 12, height: 12)
            .padding(3)
            .background(.background, in: Circle())
            .offset(x: 68, y: -68)
            .accessibilityHidden(true)
    }

    private var phaseLabelText: String {
        switch app.engine.phase {
        case .ready:
            "Ready"
        case .focus, .shortBreak, .longBreak:
            "\(app.engine.displayPhase.displayName) · \(cycleLabel)"
        case .paused:
            "\(app.engine.displayPhase.displayName) · Paused"
        case .completed:
            "Next: \(app.engine.pendingPhase.displayName)"
        }
    }

    private var cycleLabel: String {
        "\(app.engine.focusSessionsCompletedInCycle + 1)/\(app.preferences.sessionsBeforeLongBreak)"
    }

    private var spokenCycleLabel: String {
        "\(app.engine.focusSessionsCompletedInCycle + 1) of \(app.preferences.sessionsBeforeLongBreak)"
    }

    private var phaseIcon: String {
        switch app.engine.displayPhase {
        case .focus:
            "brain.head.profile"
        case .shortBreak, .longBreak:
            "cup.and.saucer"
        case .ready, .paused, .completed:
            "timer"
        }
    }

    // MARK: - Controls

    private var sessionControls: some View {
        HStack(spacing: 16) {
            Button {
                app.previous()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.body)
            }
            .buttonStyle(ControlButtonStyle(size: 30))
            .help("Previous")
            .accessibilityLabel("Previous phase")

            Button {
                app.toggleTimer()
            } label: {
                Image(systemName: app.primaryActionSystemImage)
                    .font(.title2)
            }
            .buttonStyle(ControlButtonStyle(size: 44, prominent: true, tint: ringColor))
            // Space toggles the timer, but only when the title field isn't being
            // edited — otherwise the key equivalent would swallow typed spaces.
            .modifier(SpaceToggleShortcut(enabled: !titleFocused))
            .help(app.primaryActionTitle)
            .accessibilityLabel(app.primaryActionTitle)

            Button {
                app.skip()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.body)
            }
            .buttonStyle(ControlButtonStyle(size: 30))
            .help("Skip")
            .accessibilityLabel("Skip phase")

            Button {
                app.resetCycle()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
            }
            .buttonStyle(ControlButtonStyle(size: 30))
            .help("Reset cycle")
            .accessibilityLabel("Reset cycle")
        }
    }

    // MARK: - Title & Tag

    private var titleAndTag: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                TextField(
                    "What are you working on?",
                    text: Binding(
                        get: { app.sessionTitle },
                        set: { app.setSessionTitle($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .focused($titleFocused)

                Capsule()
                    .fill(titleUnderlineColor)
                    .frame(height: 1)
                    .frame(maxWidth: 184)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: titleFocused)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: app.selectedTagID)
            }

            tagPicker
        }
    }

    private var tagPicker: some View {
        Menu {
            Button {
                app.setSelectedTagID(nil)
            } label: {
                HStack {
                    Text("No Tag")
                    if app.selectedTagID == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(app.tags) { tag in
                Button {
                    app.setSelectedTagID(tag.id)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.tag(tag.colorName))
                            .frame(width: 7, height: 7)
                        Text(tag.title)
                        if app.selectedTagID == tag.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let tag = selectedTag {
                    Circle()
                        .fill(Color.tag(tag.colorName))
                        .frame(width: 7, height: 7)
                    Text(tag.title)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                    Text("Tag")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Helpers

    private var selectedTag: Tag? {
        app.selectedTag
    }

    private var titleUnderlineColor: Color {
        if titleFocused {
            return .accentColor.opacity(0.5)
        }
        if let selectedTag {
            return Color.tag(selectedTag.colorName).opacity(0.42)
        }
        return Color.secondary.opacity(0.2)
    }

    private var ringColor: Color {
        Color.phase(app.engine.displayPhase)
    }

    private var ringGradient: AngularGradient {
        let base = ringColor
        return AngularGradient(
            colors: [base.opacity(0.6), base],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * visibleProgress)
        )
    }

    private var visibleProgress: Double {
        guard app.engine.isRunning || app.engine.phase == .paused else { return 0 }
        return max(0.001, app.progress)
    }
}

/// Applies the bare-Space play/pause key equivalent only while `enabled`, so the
/// shortcut steps aside when the session-title field has focus.
private struct SpaceToggleShortcut: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyboardShortcut(.space, modifiers: [])
        } else {
            content
        }
    }
}
