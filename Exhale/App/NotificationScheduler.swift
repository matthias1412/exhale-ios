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


    /// Rebuilds the entire schedule from the current plan and preferences.
    func reschedule(state: PersistedState, now: Date = Date()) async {
        centre.removeAllPendingNotificationRequests()

        guard let plan = state.plan else { return }

        if state.notifyMilestones {
            await scheduleMilestones(plan: plan, now: now)
        }
        if state.notifyWeeklyBill {
            await scheduleWeeklyBill(plan: plan, now: now)
        }
        if state.notifyMorningCheckIn {
            await scheduleMorningCheckIn(plan: plan, now: now)
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

    /// The weekly bill, **with the actual number in it**.
    ///
    /// This was a repeating calendar trigger whose body read "See what you kept
    /// in your pocket this week." A notification about money that doesn't say
    /// the money is a notification about nothing — and the whole product is
    /// that figure.
    ///
    /// Everything in Exhale derives from four stored facts, so a future value
    /// is computable today. Eight discrete notifications with real figures
    /// instead of one repeating placeholder; the window refills whenever the
    /// app is opened. Well inside iOS's 64 pending limit alongside the
    /// milestones.
    private func scheduleWeeklyBill(plan: QuitPlan, now: Date) async {
        let calendar = Calendar.current
        guard var fire = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 10, weekday: 1),   // Sunday morning
            matchingPolicy: .nextTime
        ) else { return }

        for week in 0..<8 {
            let progress = QuitProgress(plan: plan, now: fire)
            let weekEarlier = QuitProgress(
                plan: plan, now: fire.addingTimeInterval(-7 * 86_400)
            )
            let thisWeek = max(0, progress.moneyKept - weekEarlier.moneyKept)

            let content = UNMutableNotificationContent()
            content.title = "Another week you kept it"
            content.body = "\(thisWeek.moneyString(plan.currencyCode)) stayed in your "
                + "pocket this week. \(progress.moneyKept.moneyString(plan.currencyCode)) "
                + "since you stopped."
            content.sound = .default

            await add(
                identifier: "\(Identifier.weeklyBill).\(week)",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fire
                    ),
                    repeats: false
                )
            )
            fire = calendar.date(byAdding: .day, value: 7, to: fire) ?? fire
        }
    }

    /// The morning nudge, carrying the day count.
    ///
    /// "Your spiral is waiting" says nothing. The day number is evidence, and
    /// the second line is deliberately about identity rather than effort —
    /// people who come to see themselves as non-smokers stay stopped more
    /// reliably than people who see themselves as smokers resisting.
    private func scheduleMorningCheckIn(plan: QuitPlan, now: Date) async {
        let calendar = Calendar.current
        guard var fire = calendar.nextDate(
            after: now, matching: DateComponents(hour: 9), matchingPolicy: .nextTime
        ) else { return }

        for day in 0..<7 {
            let progress = QuitProgress(plan: plan, now: fire)
            guard progress.hasStarted else {
                fire = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Day \(progress.dayNumber)"
            content.body = progress.dayNumber <= 2
                ? "The first days are the loudest. It gets quieter."
                : "You've already done this \(progress.dayNumber - 1) times. Today is just the next one."
            content.sound = .default

            await add(
                identifier: "\(Identifier.morningCheckIn).\(day)",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: fire
                    ),
                    repeats: false
                )
            )
            fire = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire
        }
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

}
