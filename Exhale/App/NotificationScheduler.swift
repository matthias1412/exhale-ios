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
        static let dayOne = "day-one"
        static let eveOfQuit = "eve-of-quit"
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

        // The start itself, before anything derived from it. Someone who set
        // a date and then heard nothing on the morning got the one silence the
        // app cannot afford.
        await scheduleStart(state: state, plan: plan, now: now)

        // Everything derived from the quit date waits for the quit to be
        // real. Sending "20 minutes in, your heart rate settles" to someone who
        // scheduled Monday and then did not stop is the app asserting something
        // it has no way to know.
        let awaiting = (state.awaitingStart ?? false) && plan.quitDate <= now
        if !awaiting {
            if state.notifyMilestones {
                await scheduleMilestones(plan: plan, now: now)
            }
            if state.notifyWeeklyBill {
                await scheduleWeeklyBill(state: state, plan: plan, now: now)
            }
            if state.notifyMorningCheckIn {
                await scheduleMorningCheckIn(state: state, plan: plan, now: now)
            }
        }

        let pending = await centre.pendingNotificationRequests().count
        logger.info("Scheduled \(pending) notifications")
    }

    /// Day one, and the evening before it.
    ///
    /// Sent regardless of the milestone toggle: this is not a milestone, it is
    /// the appointment the user made with themselves. It only exists at all
    /// when the quit date is still ahead — someone who has already had their
    /// last one is on day one as they finish onboarding.
    private func scheduleStart(state: PersistedState, plan: QuitPlan, now: Date) async {
        let reason = state.reasons.primary
        let start = plan.quitDate
        guard start > now else { return }

        let dayOne = NotificationCopy.dayOne(reason: reason, name: state.reasonName)
        await add(
            identifier: Identifier.dayOne,
            content: content(dayOne),
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, start.timeIntervalSince(now)), repeats: false
            )
        )

        // The night before, at 8pm — but only if that is still in the future
        // and at least a couple of hours away, so setting a date for tomorrow
        // morning at 11pm tonight does not fire immediately.
        let calendar = Calendar.current
        let eveDay = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        guard let eve = calendar.date(
            bySettingHour: 20, minute: 0, second: 0, of: eveDay
        ), eve.timeIntervalSince(now) > 2 * 3600 else { return }

        let message = NotificationCopy.eveOfQuit(reason: reason, name: state.reasonName)
        await add(
            identifier: Identifier.eveOfQuit,
            content: content(message),
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: eve.timeIntervalSince(now), repeats: false
            )
        )
    }

    private func scheduleMilestones(plan: QuitPlan, now: Date) async {
        for milestone in Milestones.forProduct(plan.product) {
            let fireDate = milestone.date(from: plan.quitDate)
            guard fireDate > now else { continue }

            // The in-app timeline needs the relative time right-aligned; a
            // lock screen does not. "72 h — Nicotine-free body" reads like a
            // sensor reading. The title alone is warmer and the body says when.
            await add(
                identifier: Identifier.milestonePrefix + milestone.id,
                content: content(NotificationCopy.milestone(milestone)),
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
    private func scheduleWeeklyBill(state: PersistedState, plan: QuitPlan, now: Date) async {
        let calendar = Calendar.current
        guard var fire = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 10, weekday: 1),   // Sunday morning
            matchingPolicy: .nextTime
        ) else { return }

        for week in 0..<8 {
            // A quit date a few days out meant the first Sunday landed before
            // the user had stopped: "0.00 stayed in your pocket this week.
            // 0.00 since you stopped." Measured at 22 hours early for a Friday
            // install and a Monday start.
            guard fire > plan.quitDate else {
                fire = calendar.date(byAdding: .day, value: 7, to: fire) ?? fire
                continue
            }
            let progress = QuitProgress(plan: plan, now: fire)
            let weekEarlier = QuitProgress(
                plan: plan, now: fire.addingTimeInterval(-7 * 86_400)
            )
            let thisWeek = max(0, progress.moneyKept - weekEarlier.moneyKept)

            // "kept it" — kept what? Ambiguous on a lock screen.
            let message = NotificationCopy.weeklyBill(
                thisWeek: thisWeek.moneyString(plan.currencyCode),
                total: progress.moneyKept.moneyString(plan.currencyCode)
            )
            await add(
                identifier: "\(Identifier.weeklyBill).\(week)",
                content: content(message),
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
    private func scheduleMorningCheckIn(state: PersistedState, plan: QuitPlan, now: Date) async {
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

            let message = NotificationCopy.morning(
                day: progress.dayNumber,
                reason: state.reasons.primary,
                name: state.reasonName
            )
            await add(
                identifier: "\(Identifier.morningCheckIn).\(day)",
                content: content(message),
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

    private func content(_ message: NotificationCopy.Message) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        return content
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
            let message = NotificationCopy.milestone(next)
            content.title = message.title
            content.body = message.body
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
