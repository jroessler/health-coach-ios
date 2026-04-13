import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user opens the weekly summary reminder notification; switch main `TabView` to Coach.
    static let healthCoachOpenMainCoachTab = Notification.Name("healthCoachOpenMainCoachTab")
}

enum CoachWeeklyReminderService {
    static let enabledKey = "com.jannik.healthcoach.weeklyCoachSummaryReminderEnabled"
    static let promptCompletedKey = "com.jannik.healthcoach.weeklyCoachSummaryReminderPromptCompleted"
    static let notificationIdentifier = "com.jannik.healthcoach.weeklySummaryReminder"

    /// Returns the effective enabled state after applying (false if the user denied notifications).
    @discardableResult
    static func setReminderEnabled(_ enabled: Bool) async -> Bool {
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()

        guard enabled else {
            defaults.set(false, forKey: enabledKey)
            center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
            return false
        }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            defaults.set(false, forKey: enabledKey)
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else {
                    defaults.set(false, forKey: enabledKey)
                    return false
                }
            } catch {
                defaults.set(false, forKey: enabledKey)
                return false
            }
        case .authorized, .provisional, .ephemeral:
            break
        @unknown default:
            defaults.set(false, forKey: enabledKey)
            return false
        }

        scheduleWeeklySundayReminder()
        defaults.set(true, forKey: enabledKey)
        return true
    }

    private static func scheduleWeeklySundayReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Start your weekly summary"
        content.body = "Open AI Coach to generate your health summary."
        content.sound = .default

        var components = DateComponents()
        components.calendar = Calendar.current
        components.weekday = 1 // Sunday (Gregorian, US-style weekday numbering)
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
