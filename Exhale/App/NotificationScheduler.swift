import Foundation
import OSLog
import UserNotifications

/// Local notifications only — no server, no push token, nothing leaves the
/// device. That is a feature of the product, not an implementation shortcut.
///
/// The whole set is torn down and rebuilt on any plan change, because a
/// milestone's fire date is derived from the quit date: edit the quit date and
/// every future alert moves with it.
@MainActor
final class NotificationScheduler {

    static let shared = NotificationScheduler()

    private let centre = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.matthias1412.exhale", category: "notifications")

    private enum Identifier {
        static let milestonePrefix = "milestone."
        static let weeklyBill = "weekly-bill"
        static let morningCheckIn = "morning-check-in"
    }

    private init() {}

    /// Returns whether the user granted permission. Never called during seeded
    /// screenshot runs — a permission dialog would land in every capture.
    @discardableResult
    func requestAuthorisation() async -> Bool {
        do {
            return try await centre.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Authorisation failed: \(error.localizedDescription)")
            return false
        }
    }

    func authorisationStatus() async -> UNAuthorizationStatus {
        await centre.notificationSettings().authorizationStatus
    }

    /// Rebuilds the entire schedule from the current plan and preferences.
    func reschedule(state: PersistedState, now: Date = Date()) async {
        centre.removeAllPendingNotificationRequests()

        guard let plan = state.plan else { return }

        if state.notifyMilestones {
            await scheduleMilestones(plan: plan, now: now)
        }
        if state.notifyWeeklyBill {
            await scheduleWeeklyBill()
        }
        if state.notifyMorningCheckIn {
            await scheduleMorningCheckIn()
        }

        let pending = await centre.pendingNotificationRequests().count
        logger.info("Scheduled \(pending) notifications")
    }

    private func scheduleMilestones(plan: QuitPlan, now: Date) async {
        for milestone in Milestones.forProduct(plan.product) {
            let fireDate = milestone.date(from: plan.quitDate)
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(milestone.when) — \(milestone.title)"
            content.body = milestone.body
            content.sound = .default

            await add(
                identifier: Identifier.milestonePrefix + milestone.id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, fireDate.timeIntervalSince(now)),
                    repeats: false
                )
            )
        }
    }

    private func scheduleWeeklyBill() async {
        let content = UNMutableNotificationContent()
        content.title = "Your week, itemised"
        content.body = "See what you kept in your pocket this week."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1        // Sunday
        components.hour = 10

        await add(
            identifier: Identifier.weeklyBill,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func scheduleMorningCheckIn() async {
        let content = UNMutableNotificationContent()
        content.title = "One day at a time"
        content.body = "Your spiral is waiting."
        content.sound = .default

        var components = DateComponents()
        components.hour = 9

        await add(
            identifier: Identifier.morningCheckIn,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func add(
        identifier: String,
        content: UNNotificationContent,
        trigger: UNNotificationTrigger
    ) async {
        do {
            try await centre.add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            )
        } catch {
            logger.error("Could not schedule \(identifier): \(error.localizedDescription)")
        }
    }

    /// Settings' "Send me a test notification" — fires the next milestone's
    /// real copy a few seconds out, so the user sees exactly what they'll get.
    func sendTestNotification(state: PersistedState, now: Date = Date()) async {
        let content = UNMutableNotificationContent()

        if let plan = state.plan,
           let next = Milestones.upcoming(
               for: plan.product,
               hoursElapsed: QuitProgress(plan: plan, now: now).hoursElapsed,
               limit: 1
           ).first {
            content.title = "\(next.when) — \(next.title)"
            content.body = next.body
        } else {
            content.title = "Exhale"
            content.body = "You have outlived every milestone we track. Extraordinary."
        }
        content.sound = .default

        await add(
            identifier: "test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
    }

    /// Diagnostic for Settings — what is actually queued, read back from the
    /// system rather than recomputed from the plan.
    func pendingMilestoneCount() async -> Int {
        await centre.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(Identifier.milestonePrefix) }
            .count
    }
}
