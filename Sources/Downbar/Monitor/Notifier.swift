import AppKit
import Foundation
import UserNotifications

/// Local notifications when a monitored service changes health. Posts only on
/// transitions (entering/worsening an issue, or recovering) — never on every
/// poll — so there's no spam.
enum Notifier {
    /// Ask once; no-op if already decided. Safe to call on every launch.
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Posts a notification. When `url` is supplied it's stashed in the content's
    /// `userInfo["url"]` so the delegate can open it on tap (deep-link).
    static func post(title: String, body: String, url: URL? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let url { content.userInfo["url"] = url.absoluteString }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Strong reference to the notification-center delegate (the center holds it
    /// weakly, so we must keep it alive for the app's lifetime).
    @MainActor private static var delegate: NotificationDelegate?

    /// Installs the delegate that opens `userInfo["url"]` when a notification is
    /// tapped. Call once at launch.
    @MainActor static func configureNotificationDelegate() {
        let d = NotificationDelegate()
        delegate = d
        UNUserNotificationCenter.current().delegate = d
    }
}

/// Opens the status-page URL carried in a notification when the user taps it.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let string = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: string) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }
}

/// User preferences for down-detection notifications, persisted in UserDefaults.
enum NotificationPrefs {
    private static let enabledKey = "notificationsEnabled"
    private static let minSeverityKey = "notificationMinSeverity"
    private static let mutedKey = "mutedServiceIDs"

    /// Whether down-detection notifications are enabled (default on).
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Lowest severity that fires a "down" alert (default `.minor`). Recovery
    /// alerts ignore this threshold.
    static var minSeverity: Indicator {
        get {
            guard let raw = UserDefaults.standard.object(forKey: minSeverityKey) as? Int,
                  let value = Indicator(rawValue: raw) else { return .minor }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: minSeverityKey) }
    }

    /// Set of service IDs the user has muted, backed by a `[String]` in UserDefaults.
    static var mutedServiceIDs: Set<UUID> {
        get {
            let raw = UserDefaults.standard.stringArray(forKey: mutedKey) ?? []
            return Set(raw.compactMap(UUID.init(uuidString:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.uuidString), forKey: mutedKey)
        }
    }

    static func isMuted(_ id: UUID) -> Bool {
        mutedServiceIDs.contains(id)
    }

    static func setMuted(_ id: UUID, _ muted: Bool) {
        var ids = mutedServiceIDs
        if muted { ids.insert(id) } else { ids.remove(id) }
        mutedServiceIDs = ids
    }
}
