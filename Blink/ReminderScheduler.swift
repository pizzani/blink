import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class ReminderScheduler {
    static let intervalOptions = [5, 10, 15, 20, 30, 45, 60]

    private static let reminderID = "blink.reminder"
    private static let intervalKey = "intervalMinutes"
    private static let pausedKey = "isPaused"

    var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: Self.intervalKey)
            reschedule()
        }
    }

    var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: Self.pausedKey)
            reschedule()
        }
    }

    private(set) var isAuthorized = true

    private let center = UNUserNotificationCenter.current()
    private let delegate = NotificationDelegate()

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        intervalMinutes = stored > 0 ? stored : 20
        isPaused = UserDefaults.standard.bool(forKey: Self.pausedKey)
        center.delegate = delegate
    }

    func start() {
        Task {
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            reschedule()
        }
    }

    func reschedule() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        guard !isPaused else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(intervalMinutes * 60), repeats: true)
        center.add(UNNotificationRequest(identifier: Self.reminderID, content: Self.content(), trigger: trigger))
    }

    func sendTest() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: Self.content(), trigger: trigger))
    }

    func stop() {
        center.removeAllPendingNotificationRequests()
    }

    private static func content() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to blink 👀"
        content.body = "Look at something ~6 m (20 ft) away for 20 seconds."
        content.sound = .default
        return content
    }
}

/// Shows reminders even while Blink is the active app (e.g. its menu is open).
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
