import SwiftUI

/// A circular control button with subtle hover and press feedback, used for the
/// timer transport controls. Respects Reduce Motion (no scale/animation).
struct ControlButtonStyle: ButtonStyle {
    var size: CGFloat = 32
    var prominent = false
    var tint: Color = .secondary

    func makeBody(configuration: Configuration) -> some View {
        ControlButton(
            configuration: configuration,
            size: size,
            prominent: prominent,
            tint: tint
        )
    }

    private struct ControlButton: View {
        let configuration: Configuration
        let size: CGFloat
        let prominent: Bool
        let tint: Color

        @State private var hovering = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .scaleEffect(scale)
                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .contentShape(Circle())
                .onHover { hovering = $0 }
                .opacity(isEnabled ? 1 : 0.4)
        }

        private var scale: CGFloat {
            guard !reduceMotion, configuration.isPressed else { return 1 }
            return 0.92
        }

        private var background: Color {
            if prominent {
                // Always-tinted resting state, slightly stronger on hover/press.
                return tint.opacity(configuration.isPressed ? 0.28 : (hovering ? 0.22 : 0.15))
            }
            if configuration.isPressed {
                return Color.primary.opacity(0.12)
            }
            return hovering ? Color.primary.opacity(0.06) : Color.clear
        }
    }
}
