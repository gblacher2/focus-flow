import AppKit
import FocusFlowCore
import UserNotifications

enum NotificationPermissionStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    init(_ authorizationStatus: UNAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .notDetermined:
            "Not requested"
        case .denied:
            "Blocked"
        case .authorized:
            "Allowed"
        case .provisional:
            "Delivered quietly"
        case .ephemeral:
            "Temporary access"
        case .unknown:
            "Unknown"
        }
    }
}

final class NotificationService: @unchecked Sendable {
    func authorizationStatus() async -> NotificationPermissionStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: NotificationPermissionStatus(settings.authorizationStatus))
            }
        }
    }

    func requestAuthorization() async -> NotificationPermissionStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    continuation.resume(returning: NotificationPermissionStatus(settings.authorizationStatus))
                }
            }
        }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    func notify(title: String, body: String, sound: TimerSound) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("\(sound.rawValue).aiff"))

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
