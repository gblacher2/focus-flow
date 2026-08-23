import Foundation

public struct ShortcutSpec: Codable, Equatable, Sendable {
    public var keyCode: Int          // hardware key code (NSEvent.keyCode)
    public var modifierRawValue: UInt // NSEvent.ModifierFlags.rawValue subset

    public init(keyCode: Int, modifierRawValue: UInt) {
        self.keyCode = keyCode
        self.modifierRawValue = modifierRawValue
    }

    // The ⌃⌥⌘ modifier mask raw value is 0x1C0000
    // (.control 1<<18 | .option 1<<19 | .command 1<<20).
    // This mirrors NSEvent.ModifierFlags without importing AppKit.
    public static let defaultModifierMask: UInt = 0x1C0000
    public static let shiftModifierMask: UInt = 0x020000
    public static let keyboardModifierMask: UInt = 0x1E0000

    public static let defaultToggle = ShortcutSpec(keyCode: 49, modifierRawValue: defaultModifierMask)
    public static let defaultSkip = ShortcutSpec(keyCode: 124, modifierRawValue: defaultModifierMask)
    public static let defaultReset = ShortcutSpec(keyCode: 15, modifierRawValue: defaultModifierMask)
    public static let defaultShowTimer = ShortcutSpec(keyCode: 3, modifierRawValue: defaultModifierMask)

    /// Removes Caps Lock and hardware/layout flags such as Numeric Pad and Function.
    /// Only Control, Option, Shift, and Command participate in shortcut identity.
    public static func normalizedModifierRawValue(_ rawValue: UInt) -> UInt {
        rawValue & keyboardModifierMask
    }

    /// Recorder bindings require Control, Option, or Command. Shift may accompany
    /// one of those modifiers, but plain keys and Shift-only combinations are invalid.
    public static func isRecordableModifierRawValue(_ rawValue: UInt) -> Bool {
        let normalized = normalizedModifierRawValue(rawValue)
        return normalized != 0 && normalized != shiftModifierMask
    }

    /// Pure production matcher used by the AppKit event monitor and SelfTests.
    public func matches(eventKeyCode: Int, eventModifierRawValue: UInt) -> Bool {
        keyCode == eventKeyCode
            && Self.normalizedModifierRawValue(modifierRawValue)
                == Self.normalizedModifierRawValue(eventModifierRawValue)
    }

    /// Logical identity for duplicate detection, ignoring non-keyboard flag noise.
    public func conflicts(with other: ShortcutSpec) -> Bool {
        keyCode == other.keyCode
            && Self.normalizedModifierRawValue(modifierRawValue)
                == Self.normalizedModifierRawValue(other.modifierRawValue)
    }

    public var displayString: String {
        let modifiers = Self.normalizedModifierRawValue(modifierRawValue)
        var str = ""
        if (modifiers & 0x040000) != 0 { str += "⌃" }
        if (modifiers & 0x080000) != 0 { str += "⌥" }
        if (modifiers & 0x020000) != 0 { str += "⇧" }
        if (modifiers & 0x100000) != 0 { str += "⌘" }

        str += keyName(for: keyCode)
        return str
    }

    public func keyName(for code: Int) -> String {
        if let name = ShortcutSpec.keyCodeToName[code] {
            return name
        }
        if let char = ShortcutSpec.keyCodeToChar[code] {
            return char.uppercased()
        }
        return "Key \(code)"
    }

    public static func keyEquivalentString(for code: Int) -> String? {
        if let char = keyCodeToChar[code] { return char }
        switch code {
        case 49: return " "
        case 126: return "\u{F700}" // NSUpArrowFunctionKey
        case 125: return "\u{F701}" // NSDownArrowFunctionKey
        case 123: return "\u{F702}" // NSLeftArrowFunctionKey
        case 124: return "\u{F703}" // NSRightArrowFunctionKey
        case 122: return "\u{F704}" // NSF1FunctionKey
        case 120: return "\u{F705}" // NSF2FunctionKey
        case 99: return "\u{F706}"  // NSF3FunctionKey
        case 118: return "\u{F707}" // NSF4FunctionKey
        case 96: return "\u{F708}"  // NSF5FunctionKey
        case 97: return "\u{F709}"  // NSF6FunctionKey
        case 98: return "\u{F70A}"  // NSF7FunctionKey
        case 100: return "\u{F70B}" // NSF8FunctionKey
        case 101: return "\u{F70C}" // NSF9FunctionKey
        case 109: return "\u{F70D}" // NSF10FunctionKey
        case 103: return "\u{F70E}" // NSF11FunctionKey
        case 111: return "\u{F70F}" // NSF12FunctionKey
        case 51: return "\u{08}"    // NSBackspaceCharacter
        case 117: return "\u{7F}"   // NSDeleteCharacter
        case 36: return "\r"
        case 53: return "\u{1b}" // Escape
        case 48: return "\t"
        default: return nil
        }
    }

    private static let keyCodeToChar: [Int: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y",
        17: "t", 31: "o", 32: "u", 34: "i", 35: "p", 37: "l", 38: "j", 39: "\'",
        40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".",
        50: "`", 30: "]", 33: "[", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0", 27: "-", 24: "="
    ]

    private static let keyCodeToName: [Int: String] = [
        49: "Space",
        51: "Delete",
        117: "Forward Delete",
        36: "Return",
        53: "Escape",
        48: "Tab",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
}
