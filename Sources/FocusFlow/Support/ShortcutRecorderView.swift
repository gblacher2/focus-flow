import AppKit
import FocusFlowCore
import SwiftUI

// MARK: - Shortcut Recorder View

struct ShortcutRecorderView: NSViewRepresentable {
    var title: String
    @Binding var spec: ShortcutSpec
    var defaultSpec: ShortcutSpec
    var onDuplicate: ((ShortcutSpec) -> Void)?
    var otherSpecs: [ShortcutSpec] = []

    func makeNSView(context: Context) -> _ShortcutRecorderNSView {
        let view = _ShortcutRecorderNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: _ShortcutRecorderNSView, context: Context) {
        context.coordinator.parent = self
        nsView.actionTitle = title
        nsView.spec = spec
        nsView.isRecording = context.coordinator.isRecording
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: ShortcutRecorderDelegate {
        var parent: ShortcutRecorderView
        var isRecording = false

        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }

        func recordingDidStart() {
            isRecording = true
        }

        func recordingDidEnd() {
            isRecording = false
        }

        func recordingDidCapture(keyCode: Int, modifiers: UInt) {
            isRecording = false
            let newSpec = ShortcutSpec(
                keyCode: keyCode,
                modifierRawValue: ShortcutSpec.normalizedModifierRawValue(modifiers)
            )

            if parent.otherSpecs.contains(where: { $0.conflicts(with: newSpec) }) {
                parent.onDuplicate?(newSpec)
                return
            }

            parent.spec = newSpec
        }

        func recordingDidCancel() {
            isRecording = false
        }

        func recordingDidReset() {
            isRecording = false
            if parent.otherSpecs.contains(where: { $0.conflicts(with: parent.defaultSpec) }) {
                parent.onDuplicate?(parent.defaultSpec)
                return
            }
            parent.spec = parent.defaultSpec
        }
    }
}

@MainActor
protocol ShortcutRecorderDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidEnd()
    func recordingDidCapture(keyCode: Int, modifiers: UInt)
    func recordingDidCancel()
    func recordingDidReset()
}

final class _ShortcutRecorderNSView: NSView {
    static private(set) weak var activeRecorder: _ShortcutRecorderNSView?

    weak var delegate: ShortcutRecorderDelegate?
    var actionTitle = "Shortcut"
    var spec: ShortcutSpec? {
        didSet {
            needsDisplay = true
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }
    var isRecording = false {
        didSet {
            if isRecording {
                Self.activeRecorder = self
            } else if Self.activeRecorder === self {
                Self.activeRecorder = nil
            }
            needsDisplay = true
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }
    private var validationHint: String? {
        didSet {
            needsDisplay = true
            NSAccessibility.post(element: self, notification: .valueChanged)
        }
    }

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.setAccessibilityElement(false)

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    // VoiceOver Accessibility overrides
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? {
        if isRecording {
            return "\(actionTitle) shortcut recorder, recording"
        } else {
            return "\(actionTitle) shortcut recorder"
        }
    }
    override func accessibilityValue() -> Any? {
        if let validationHint {
            return validationHint
        }
        if isRecording {
            return "Type a shortcut. Press Escape to cancel or Delete to reset."
        } else {
            return spec?.displayString ?? "No shortcut assigned"
        }
    }

    override func accessibilityPerformPress() -> Bool {
        beginRecording()
        return isRecording
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned, isRecording {
            isRecording = false
            validationHint = nil
            delegate?.recordingDidEnd()
        }
        return resigned
    }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            if event.keyCode == 36 || event.keyCode == 49 {
                beginRecording()
                return
            }
            super.keyDown(with: event)
            return
        }

        handleRecordingKeyDown(
            keyCode: Int(event.keyCode),
            modifierRawValue: event.modifierFlags.rawValue
        )
    }

    func handleRecordingKeyDown(keyCode: Int, modifierRawValue: UInt) {
        // Escape cancels
        if keyCode == 53 {
            validationHint = nil
            isRecording = false
            delegate?.recordingDidCancel()
            window?.makeFirstResponder(nil)
            return
        }

        // Delete or Backspace resets
        if keyCode == 51 || keyCode == 117 {
            validationHint = nil
            isRecording = false
            delegate?.recordingDidReset()
            window?.makeFirstResponder(nil)
            return
        }

        let modifiers = ShortcutSpec.normalizedModifierRawValue(modifierRawValue)

        // A plain Tab exits capture and continues normal keyboard traversal.
        if keyCode == 48, modifiers == 0 {
            validationHint = nil
            isRecording = false
            delegate?.recordingDidCancel()
            window?.selectNextKeyView(self)
            return
        }

        // Reject plain keys and Shift-only combos
        if !ShortcutSpec.isRecordableModifierRawValue(modifiers) {
            validationHint = "Add Control, Option, or Command"
            NSSound.beep()
            return
        }

        validationHint = nil
        isRecording = false
        delegate?.recordingDidCapture(keyCode: keyCode, modifiers: modifiers)
        window?.makeFirstResponder(nil)
    }

    private func beginRecording() {
        guard window?.makeFirstResponder(self) == true else { return }
        validationHint = nil
        guard !isRecording else { return }
        isRecording = true
        delegate?.recordingDidStart()
    }

    override func updateLayer() {
        super.updateLayer()

        if isRecording {
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            label.stringValue = validationHint ?? "Type shortcut…"
            label.textColor = validationHint == nil ? .controlAccentColor : .systemRed
        } else {
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
            label.stringValue = spec?.displayString ?? ""
            label.textColor = .labelColor
        }
    }
}

// MARK: - ShortcutSpec Display & Conversion

extension ShortcutSpec {
    var menuKeyEquivalent: String {
        return ShortcutSpec.keyEquivalentString(for: keyCode) ?? ""
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        if menuKeyEquivalent.isEmpty {
            return []
        }
        return NSEvent.ModifierFlags(
            rawValue: ShortcutSpec.normalizedModifierRawValue(modifierRawValue)
        )
    }

    var swiftUIModifiers: EventModifiers {
        guard swiftUIKeyEquivalent != nil else { return [] }
        let nsModifiers = NSEvent.ModifierFlags(
            rawValue: ShortcutSpec.normalizedModifierRawValue(modifierRawValue)
        )
        var mods: EventModifiers = []
        if nsModifiers.contains(.control) { mods.insert(.control) }
        if nsModifiers.contains(.option) { mods.insert(.option) }
        if nsModifiers.contains(.shift) { mods.insert(.shift) }
        if nsModifiers.contains(.command) { mods.insert(.command) }
        return mods
    }

    var swiftUIKeyEquivalent: KeyEquivalent? {
        guard let str = ShortcutSpec.keyEquivalentString(for: keyCode), str.count == 1 else { return nil }
        return KeyEquivalent(Character(str))
    }
}
