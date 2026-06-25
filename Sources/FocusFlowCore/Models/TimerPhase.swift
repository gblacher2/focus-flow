import Foundation

public enum TimerPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case ready
    case focus
    case shortBreak
    case longBreak
    case paused
    case completed

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ready: "Ready"
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        case .paused: "Paused"
        case .completed: "Complete"
        }
    }

    public var isRunningPhase: Bool {
        self == .focus || self == .shortBreak || self == .longBreak
    }

    public var isBreak: Bool {
        self == .shortBreak || self == .longBreak
    }
}
