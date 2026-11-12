import Foundation
import UserNotifications

/// A notification to show now (date == nil) or at a set moment.
struct PlannedNotification: Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date?
}

protocol NotificationPosting: AnyObject {
    func requestAuthorization() async -> Bool
    func isDenied() async -> Bool
    /// Replaces all scheduled peak notifications with this plan.
    func replaceScheduled(_ plan: [PlannedNotification], ids: [String])
    func post(_ notification: PlannedNotification)
    /// Called with the notification id when the user clicks a notification.
    var onOpen: ((String) -> Void)? { get set }
}

final class UserNotificationService: NSObject, NotificationPosting, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    var onOpen: ((String) -> Void)?

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    func replaceScheduled(_ plan: [PlannedNotification], ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        plan.forEach(post)
    }

    func post(_ n: PlannedNotification) {
        let content = UNMutableNotificationContent()
        content.title = n.title
        content.body = n.body
        content.sound = .default
        var trigger: UNNotificationTrigger?
        if let date = n.date {
            let interval = date.timeIntervalSinceNow
            guard interval > 1 else { return }
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        }
        center.add(UNNotificationRequest(identifier: n.id, content: content, trigger: trigger))
    }

    // Show banners even though a menu bar app counts as "active".
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.identifier
        DispatchQueue.main.async { self.onOpen?(id) }
        completionHandler()
    }
}
