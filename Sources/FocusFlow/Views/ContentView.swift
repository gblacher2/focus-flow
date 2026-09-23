import AppKit
import FocusFlowCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var app: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Spacing.sm)

            timerRing

            Spacer(minLength: Theme.Spacing.md)

            sessionControls
                .padding(.bottom, Theme.Spacing.md)

            ZStack(alignment: .center) {
                if app.pendingReviewRecordID != nil {
                    reviewRow
                        .transition(.opacity)
                } else {
                    titleAndTag
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: app.pendingReviewRecordID != nil)

            Spacer(minLength: Theme.Spacing.sm)

            if let error = app.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .frame(minWidth: 296, idealWidth: 312)
        .scenePadding(.vertical)
        .background(VisualEffectBackground().ignoresSafeArea())
        // macOS gives first-responder to the first focusable control (the title
        // field) when the window opens, which silently swallows the bare-Space
        // play/pause shortcut (see SpaceToggleShortcut below). `.defaultFocus`
        // cannot veto that AppKit-level assignment, so bounce focus off after the
        // window settles; the user clicks into the field to type a title.
        .onAppear {
            DispatchQueue.main.async {
                titleFocused = false
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .sheet(isPresented: $app.isOnboardingPresented, onDismiss: {
            app.completeOnboarding()
        }) {
            OnboardingView(app: app)
        }
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Wash
            Circle()
                .fill(Color.phaseWash(app.engine.displayPhase))

            // Track
            Circle()
                .stroke(.quaternary, lineWidth: 6)

            // Progress arc
            Circle()
                .trim(from: 0, to: visibleProgress)
                .stroke(
                    Color.phaseGradient(app.engine.displayPhase),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: app.progress)

            // Center content
            VStack(spacing: Theme.Spacing.xs) {
                Text(DurationFormatter.clock(app.engine.remainingSeconds))
                    .font(Theme.Typography.clock)

                phaseLabel

                if let tag = app.selectedTag {
                    timerTagAccent(tag)
                }
            }
        }
        .frame(width: 198, height: 198)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: app.engine.phase)
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
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: phaseIcon)
                .font(.caption2)

            if app.engine.phase == .completed {
                Text("Next: ")
                    .font(.subheadline.weight(.medium)) +
                Text(app.engine.pendingPhase.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            } else {
                Text(phaseLabelText)
                    .font(.subheadline.weight(.medium))
            }
        }
        .foregroundStyle(.secondary)
    }

    private func timerTagAccent(_ tag: Tag) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
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
        HStack(spacing: Theme.Spacing.lg) {
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
            .buttonStyle(ControlButtonStyle(size: 44, prominent: true, tint: playButtonTint))
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

    // MARK: - Title, Tag & Review

    private var reviewRow: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("How was that focus?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    app.dismissReview()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 32) {
                Button {
                    app.setFocusQuality(1)
                } label: {
                    Image(systemName: "wind")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Distracted")
                .help("Distracted")

                Button {
                    app.setFocusQuality(2)
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Okay")
                .help("Okay")

                Button {
                    app.setFocusQuality(3)
                } label: {
                    Image(systemName: "flame")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Deep focus")
                .help("Deep focus")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var titleAndTag: some View {
        VStack(spacing: Theme.Spacing.sm) {
            VStack(spacing: Theme.Spacing.xs) {
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
            HStack(spacing: Theme.Spacing.xs) {
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
            .font(Theme.Typography.tileCaption)
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

    /// The primary play/pause button is tinted with `ringColor` (the phase color), but
    /// `ringColor` is `.secondary` gray while ready/completed — exactly when the button
    /// should invite the user to start. Use the accent color in those two states only;
    /// running/paused keep the phase-color behavior.
    private var playButtonTint: Color {
        switch app.engine.phase {
        case .ready, .completed:
            .accentColor
        default:
            ringColor
        }
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
