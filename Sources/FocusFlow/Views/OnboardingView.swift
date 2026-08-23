import FocusFlowCore
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var app: AppModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var currentPane = 1
    @AccessibilityFocusState private var accessibilityFocusedPane: Int?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch currentPane {
                case 1: welcomePane.transition(paneTransition)
                case 2: notificationsPane.transition(paneTransition)
                case 3: finishPane.transition(paneTransition)
                default: EmptyView()
                }
            }
            .frame(width: 300, height: 350)
            .padding(Theme.Spacing.lg)
        }
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                app.completeOnboarding()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .padding(Theme.Spacing.md)
            .accessibilityHint("Completes onboarding without changing optional settings")
        }
        .task {
            app.refreshLoginItemStatus()
            await app.refreshNotificationPermissionStatus()
            accessibilityFocusedPane = currentPane
        }
        .onChange(of: currentPane) { _, newPane in
            accessibilityFocusedPane = newPane
        }
        .onDisappear {
            app.completeOnboarding()
        }
    }

    private var paneTransition: AnyTransition {
        if reduceMotion {
            return .identity
        } else {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
    }

    // MARK: - Panes

    private var welcomePane: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to FocusFlow")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocusedPane, equals: 1)

                Text("FocusFlow lives in your menu bar. Left-click to view the menu; right-click the icon to quickly pause or resume your timer.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Continue") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    currentPane = 2
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var notificationsPane: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Stay Notified")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocusedPane, equals: 2)

                Text("FocusFlow can send notifications when a focus or break phase completes.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Theme.Spacing.md) {
                if app.notificationPermissionStatus == .notDetermined {
                    Button("Enable Notifications") {
                        Task { await app.requestNotificationPermission() }
                    }
                    .buttonStyle(.bordered)
                } else if app.notificationPermissionStatus == .denied {
                    Button("Open Notifications Settings") {
                        app.openNotificationSettings()
                    }
                    .buttonStyle(.bordered)

                    Text("Notifications are denied in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if app.notificationPermissionStatus == .unknown {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.orange)
                        Text("Notification status unavailable")
                            .font(.subheadline)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(app.notificationPermissionStatus.displayName)
                            .font(.subheadline)
                    }
                }
            }
            .frame(height: 60)

            Spacer()

            Button("Continue") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    currentPane = 3
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var finishPane: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "keyboard.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Ready to Focus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($accessibilityFocusedPane, equals: 3)

                Text("Use these global shortcuts to control the timer from anywhere:")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    shortcutRow("Toggle Timer", spec: app.preferences.toggleShortcut)
                    shortcutRow("Skip Phase", spec: app.preferences.skipShortcut)
                    shortcutRow("Reset Cycle", spec: app.preferences.resetShortcut)
                    shortcutRow("Show Timer", spec: app.preferences.showTimerShortcut)
                }
                .font(.subheadline)
                .padding(.top, Theme.Spacing.sm)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Toggle("Launch FocusFlow at login", isOn: Binding(
                    get: { app.preferences.launchAtLogin },
                    set: { app.setLaunchAtLogin($0) }
                ))
                .disabled(app.loginItemStatus == .notFound)

                Text(app.loginItemStatusDescription)
                    .font(.caption)
                    .foregroundStyle(app.loginItemStatusNeedsAttention ? .orange : .secondary)

                if app.loginItemStatus == .requiresApproval {
                    Button("Open Login Items") {
                        app.openLoginItemsSettings()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                if let loginError = app.loginItemErrorMessage {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, Theme.Spacing.sm)

            Spacer()

            Button("Get Started") {
                app.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func shortcutRow(_ label: String, spec: ShortcutSpec) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(spec.displayString)
                .monospacedDigit()
        }
        .frame(width: 200)
    }
}
