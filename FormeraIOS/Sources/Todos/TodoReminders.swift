import UIKit
import UserNotifications

/// Local (on-this-phone) reminders for todos with a due date *and* time --
/// no server push involved, so a reminder only exists for todos this phone
/// has seen: a todo created or changed on someone else's phone gets its
/// reminder the next time this phone loads Team Todos.
///
/// Only todos that are "mine" get one: ones I'm mentioned on, or -- when
/// nobody's mentioned -- ones I created. Otherwise every phone would ring
/// for every todo on the shared team list.
enum TodoReminders {
    private static let identifierPrefix = "todo-"
    /// iOS keeps at most 64 pending local notifications per app; stay under
    /// it and keep the soonest.
    private static let maxScheduled = 60

    /// Replaces every pending todo reminder with one per matching todo.
    static func sync(_ todos: [Todo], userId: Int) async {
        let now = Date()
        let upcoming = todos
            .filter { !$0.isDone && isMine($0, userId: userId) }
            .compactMap { todo in todo.dueDateTime.map { (todo, $0) } }
            .filter { $0.1 > now }
            .sorted { $0.1 < $1.1 }
            .prefix(maxScheduled)

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard !upcoming.isEmpty else { return }
        // Asks the first time only; afterwards returns the saved answer.
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        for (todo, dueAt) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = "Todo due"
            content.body = todo.title
            content.sound = .default
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: dueAt
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + String(todo.id),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Removes every pending todo reminder -- e.g. on sign-out, so the
    /// next person to sign in on this phone doesn't get them.
    static func clear() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }

    private static func isMine(_ todo: Todo, userId: Int) -> Bool {
        if todo.mentions.isEmpty {
            return todo.createdBy?.id == userId
        }
        return todo.mentions.contains { $0.id == userId }
    }
}

/// Shows a reminder as a banner even while the app is open -- iOS
/// otherwise silently drops a local notification that fires in the
/// foreground.
final class NotificationPresenter: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
