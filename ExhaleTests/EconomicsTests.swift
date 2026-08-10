import XCTest
@testable import Exhale

/// The economics are the product's second pillar — if the money is wrong, the
/// whole Bill is a lie. Vape's weekly→daily conversion and the container maths
/// are the two places it can quietly go wrong.
final class EconomicsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func plan(
        _ product: NicotineProduct,
        amount: Int,
        weekly: Decimal,
        daysAgo: Double
    ) -> QuitPlan {
        QuitPlan(
            product: product,
            amount: amount,
            weeklySpend: weekly,
            currencyCode: "EUR",
            quitDate: Date(timeIntervalSince1970: 1_700_000_000 - daysAgo * 86_400)
        )
    }

    private func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000) }

    // MARK: - Cigarettes

    func testCigarettesDailyCost() {
        // €49.875 a week is a seventh of that a day. No pack size involved.
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, weekly: 49.875, daysAgo: 1),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 7.125, accuracy: 0.0001)
    }

    /// The point of the change: two people spending the same get the same
    /// money back, whatever size box it came in.
    func testMoneyIgnoresContainerSize() {
        let smoker = QuitProgress(plan: plan(.cigarettes, amount: 20, weekly: 70, daysAgo: 30),
                                  now: now(), calendar: calendar)
        let poucher = QuitProgress(plan: plan(.pouches, amount: 8, weekly: 70, daysAgo: 30),
                                   now: now(), calendar: calendar)
        XCTAssertEqual((smoker.moneyKept as NSDecimalNumber).doubleValue,
                       (poucher.moneyKept as NSDecimalNumber).doubleValue, accuracy: 0.001)
    }

    func testCigarettesOverNinetyDays() {
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, weekly: 49.875, daysAgo: 90),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.moneyKept as NSDecimalNumber).doubleValue, 641.25, accuracy: 0.01)
        XCTAssertEqual(p.unitsAvoided, 1350)
        XCTAssertEqual(p.containersAvoided, 67)      // floor(1350/20)
        XCTAssertEqual(p.hoursReclaimed, 248)        // round(1350 * 11 / 60)
    }

    // MARK: - Vape (the weekly one)

    func testVapeConvertsWeeklyToDaily() {
        // €30 a week, 5 pods a week.
        let p = QuitProgress(plan: plan(.vape, amount: 5, weekly: 30.00, daysAgo: 7),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 30.0 / 7, accuracy: 0.0001)
        XCTAssertEqual((p.moneyKept as NSDecimalNumber).doubleValue, 30.0, accuracy: 0.001)
        XCTAssertEqual(p.unitsAvoided, 5)
        XCTAssertEqual(p.containersAvoided, 5)
    }

    func testVapeMonthlyBurn() {
        let p = QuitProgress(plan: plan(.vape, amount: 5, weekly: 30.00, daysAgo: 1),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.monthlyBurn as NSDecimalNumber).doubleValue,
                       (30.0 / 7) * 30.4, accuracy: 0.001)
    }

    // MARK: - Pouches

    func testPouchContainerMaths() {
        // Tally glyphs only: 8/day for 30 days is 240 pouches, drawn as roughly
        // 12 tins. Nothing about the money depends on this.
        let p = QuitProgress(plan: plan(.pouches, amount: 8, weekly: 28.00, daysAgo: 30),
                         now: now(), calendar: calendar)
        XCTAssertEqual(p.unitsAvoided, 240)
        XCTAssertEqual(p.containersAvoided, 12)
    }

    // MARK: - Day numbering

    func testDayNumberCountsLocalMidnights() {
        // Quit at 23:00; four minutes later it is still day 1.
        var components = DateComponents()
        components.year = 2026; components.month = 3; components.day = 10
        components.hour = 23; components.minute = 0
        let quit = calendar.date(from: components)!

        let sameNight = QuitProgress(plan: QuitPlan(product: .cigarettes, amount: 15,
                                                weeklySpend: 49.875, currencyCode: "EUR",
                                                quitDate: quit),
                                 now: quit.addingTimeInterval(240), calendar: calendar)
        XCTAssertEqual(sameNight.dayNumber, 1)

        // 90 minutes later it is past midnight — day 2, despite 1.5 hours elapsed.
        let afterMidnight = QuitProgress(plan: QuitPlan(product: .cigarettes, amount: 15,
                                                    weeklySpend: 49.875, currencyCode: "EUR",
                                                    quitDate: quit),
                                     now: quit.addingTimeInterval(5400), calendar: calendar)
        XCTAssertEqual(afterMidnight.dayNumber, 2)
    }

    func testClockGoingBackwardsCannotRewindTheStreak() {
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, weekly: 49.875, daysAgo: 10),
                         now: now().addingTimeInterval(-20 * 86_400), calendar: calendar)
        XCTAssertEqual(p.dayNumber, 1)
        XCTAssertEqual(p.elapsed, 0)
        XCTAssertEqual(p.moneyKept, 0)
    }

    // MARK: - Paywall anchor

    func testPaybackDays() {
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, weekly: 49.875, daysAgo: 1),
                         now: now(), calendar: calendar)
        // €29.99 / €7.125 per day = 4.2 → 5 days
        XCTAssertEqual(p.paybackDays(yearlyPrice: 29.99), 5)
    }

    // MARK: - Currency

    func testNoHardcodedExchangeRates() {
        // Defaults are per-currency starting positions, never conversions.
        // A 0-decimal currency must not produce fractional steps.
        XCTAssertEqual(Currencies.fractionDigits(for: "JPY"), 0)
        XCTAssertGreaterThanOrEqual(
            (Currencies.priceStep(for: "JPY") as NSDecimalNumber).doubleValue, 1)
    }

    /// There must be no per-country price table to go stale — the user types
    /// their own price and the stepper is derived from the currency alone.
    func testStepDerivesFromCurrencyNotFromAPriceTable() {
        // Sized for a weekly spend, not a pack price — see Currencies.priceStep.
        XCTAssertEqual(Currencies.priceStep(for: "JPY"), 50)
        XCTAssertEqual(Currencies.priceStep(for: "ISK"), 50)
        XCTAssertEqual(Currencies.priceStep(for: "EUR"), 1)
        XCTAssertEqual(Currencies.priceStep(for: "GBP"), 1)
    }

    func testANewPlanHasNoInventedPrice() {
        XCTAssertEqual(QuitPlan.starting(product: .cigarettes, currency: "EUR").weeklySpend, 0)
    }

    /// A plan written before the switch must survive the upgrade. Losing it
    /// would drop the user back into onboarding with their streak gone, which
    /// is the one failure the whole app is built to prevent.
    func testOldPlansMigrateToWeeklySpend() throws {
        let json = """
        {"product":"cigarettes","amount":15,"unitPrice":9.5,
         "currencyCode":"EUR","quitDate":0}
        """.data(using: .utf8)!
        let plan = try JSONDecoder().decode(QuitPlan.self, from: json)
        // Old maths: 15/day ÷ 20 per pack × €9.50 = €7.125/day = €49.875/week.
        XCTAssertEqual((plan.weeklySpend as NSDecimalNumber).doubleValue,
                       49.875, accuracy: 0.0001)
        XCTAssertEqual(plan.amount, 15)
    }

    /// Stored weekly, asked per period. Cigarettes are a daily question.
    func testSpendPerPeriodRoundTrips() {
        var plan = QuitPlan.starting(product: .cigarettes, currency: "EUR")
        plan.spendPerPeriod = 7
        XCTAssertEqual((plan.weeklySpend as NSDecimalNumber).doubleValue, 49, accuracy: 0.0001)

        var vape = QuitPlan.starting(product: .vape, currency: "EUR")
        vape.spendPerPeriod = 30
        XCTAssertEqual((vape.weeklySpend as NSDecimalNumber).doubleValue, 30, accuracy: 0.0001)
    }
}

/// Relapse is the norm, not the exception, so the maths around it has to hold.
final class RelapseTests: XCTestCase {

    private func state(quitDaysAgo: Int) -> PersistedState {
        var s = PersistedState()
        s.plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                          currencyCode: "EUR",
                          quitDate: Date(timeIntervalSince1970: 1_700_000_000
                                         - Double(quitDaysAgo) * 86_400))
        return s
    }

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    func testSlipDoesNotResetTheStreak() {
        var s = state(quitDaysAgo: 60)
        let before = QuitProgress(plan: s.plan!, now: now).dayNumber
        s.recordSlip(at: now)
        XCTAssertEqual(QuitProgress(plan: s.plan!, now: now).dayNumber, before,
                       "one slip must not zero the spiral")
        XCTAssertEqual(s.slipsInCurrentAttempt().count, 1)
        XCTAssertTrue(s.pastAttempts.isEmpty)
    }

    func testRelapseStartsANewRunButKeepsTheOldOne() {
        var s = state(quitDaysAgo: 60)
        s.recordRelapse(at: now)
        XCTAssertEqual(s.pastAttempts.count, 1)
        XCTAssertEqual(QuitProgress(plan: s.plan!, now: now).dayNumber, 1)
        XCTAssertEqual(s.totalAttempts, 2)
    }

    /// The days already earned still count — that is the whole point.
    func testBestStreakSurvivesARelapse() {
        var s = state(quitDaysAgo: 60)
        let previous = QuitProgress(plan: s.plan!, now: now).dayNumber
        s.recordRelapse(at: now)
        XCTAssertEqual(s.bestStreakDays(now: now), previous)
    }

    func testSlipsFromEarlierRunsDoNotCountAgainstTheCurrentOne() {
        var s = state(quitDaysAgo: 60)
        s.recordSlip(at: now.addingTimeInterval(-30 * 86_400))
        s.recordRelapse(at: now)
        XCTAssertEqual(s.slipsInCurrentAttempt().count, 0)
        XCTAssertEqual(s.slips.count, 1, "the slip is still on record, just not this run's")
    }
}

/// Regressions for defects found by reading the code back rather than by any
/// test failing. Each of these shipped silently.
final class RegressionTests: XCTestCase {

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func state(daysAgo: Double) -> PersistedState {
        var s = PersistedState()
        s.plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                          currencyCode: "EUR",
                          quitDate: now.addingTimeInterval(-daysAgo * 86_400))
        return s
    }

    /// Money is the second pillar of the product and it must move. A frozen
    /// clock gives the same answer twice; a real one must not.
    func testMoneyKeptAdvancesWithTime() {
        let plan = state(daysAgo: 10).plan!
        let a = QuitProgress(plan: plan, now: now).moneyKept
        let b = QuitProgress(plan: plan, now: now.addingTimeInterval(60)).moneyKept
        XCTAssertGreaterThan(b, a, "the counter must advance as time passes")
    }

    /// After a relapse the new run must be able to celebrate its early
    /// milestones. Inheriting the previous run's watermark suppressed all of
    /// them — precisely when encouragement matters most.
    func testRelapseClearsTheCelebrationWatermark() {
        var s = state(daysAgo: 62)
        s.lastCelebratedHours = 720          // reached "1 month" last time
        s.recordRelapse(at: now)
        XCTAssertEqual(s.lastCelebratedHours, 0)

        let unseen = Milestones.unseen(
            for: .cigarettes,
            quitDate: s.plan!.quitDate,
            lastSeenHours: s.lastCelebratedHours,
            now: now.addingTimeInterval(13 * 3600)
        )
        XCTAssertFalse(unseen.isEmpty, "a fresh run must reach its early milestones again")
        XCTAssertEqual(unseen.first?.when, "20 min")
    }

    /// A future quit date is a real state, not a day 1.
    func testFutureQuitDateHasNotStarted() {
        var s = PersistedState()
        s.plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                          currencyCode: "EUR",
                          quitDate: now.addingTimeInterval(3 * 86_400))
        let p = QuitProgress(plan: s.plan!, now: now)
        XCTAssertFalse(p.hasStarted)
        XCTAssertEqual(p.daysUntilStart, 3)
        XCTAssertEqual(p.moneyKept, 0, "nothing has been saved yet")
        XCTAssertEqual(p.unitsAvoided, 0)
    }

    /// Notifications must never be scheduled in the past for a scheduled quit.
    func testFutureQuitStillSchedulesEveryMilestone() {
        let quit = now.addingTimeInterval(3 * 86_400)
        let future = Milestones.forProduct(.cigarettes)
            .filter { $0.date(from: quit) > now }
        XCTAssertEqual(future.count, Milestones.forProduct(.cigarettes).count,
                       "every milestone is still ahead of a quit that hasn't begun")
    }
}

/// Edge cases around slipping, which is where a quit app is most likely to be
/// wrong in a way the user actually feels.
final class SlipEdgeCaseTests: XCTestCase {

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func state(daysAgo: Double) -> PersistedState {
        var s = PersistedState()
        s.plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                          currencyCode: "EUR",
                          quitDate: now.addingTimeInterval(-daysAgo * 86_400))
        return s
    }

    /// People open the app days after the cigarette, not during it.
    func testARelapseCanBeBackdated() {
        var s = state(daysAgo: 62)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        s.recordRelapse(at: threeDaysAgo)

        XCTAssertEqual(QuitProgress(plan: s.plan!, now: now).dayNumber, 4,
                       "the new streak runs from when it actually happened")
        XCTAssertEqual(s.pastAttempts.first?.ended, threeDaysAgo)
    }

    /// The previous attempt must end where the new one begins, not overlap it.
    func testBackdatedRelapseDoesNotOverlapAttempts() {
        var s = state(daysAgo: 62)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        s.recordRelapse(at: threeDaysAgo)
        XCTAssertEqual(s.pastAttempts.first?.ended, s.plan?.quitDate)
    }

    /// A backdated slip belongs to the run it happened in.
    func testBackdatedSlipCountsAgainstTheRunItHappenedIn() {
        var s = state(daysAgo: 10)
        s.recordSlip(at: now.addingTimeInterval(-3 * 86_400))
        XCTAssertEqual(s.slipsInCurrentAttempt().count, 1)
    }

    /// A slip dated before the current attempt began is not this run's.
    func testSlipBeforeTheRunStartedIsNotCounted() {
        var s = state(daysAgo: 2)
        s.recordSlip(at: now.addingTimeInterval(-9 * 86_400))
        XCTAssertEqual(s.slipsInCurrentAttempt().count, 0)
        XCTAssertEqual(s.slips.count, 1)
    }
}

/// The streak surviving a reinstall is the single failure users would not
/// forgive, so the conflict rule needs to be exactly right.
final class CloudMirrorTests: XCTestCase {

    private func state(day: Int, updated: TimeInterval) -> PersistedState {
        var s = PersistedState()
        s.plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                          currencyCode: "EUR",
                          quitDate: Date(timeIntervalSince1970: 1_700_000_000
                                         - Double(day) * 86_400))
        s.updatedAt = Date(timeIntervalSince1970: updated)
        return s
    }

    /// A fresh install has nothing on disk — the cloud copy must win.
    func testReinstallRestoresFromCloud() {
        let cloud = state(day: 200, updated: 1_700_000_000)
        XCTAssertEqual(CloudMirror.newer(nil, cloud)?.plan?.quitDate,
                       cloud.plan?.quitDate)
    }

    func testNewerCopyWins() {
        let older = state(day: 10, updated: 1_700_000_000)
        let newer = state(day: 40, updated: 1_700_000_900)
        XCTAssertEqual(CloudMirror.newer(older, newer)?.plan?.quitDate,
                       newer.plan?.quitDate)
        XCTAssertEqual(CloudMirror.newer(newer, older)?.plan?.quitDate,
                       newer.plan?.quitDate)
    }

    func testNothingAnywhereIsNotAnError() {
        XCTAssertNil(CloudMirror.newer(nil, nil))
    }

    /// updatedAt exists only to break ties. If it counted toward equality,
    /// stamping it during a save would retrigger the save that set it.
    func testUpdatedAtIsExcludedFromEquality() {
        var a = state(day: 5, updated: 1_700_000_000)
        var b = a
        b.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(a, b)

        b.cravingsWon += 1
        XCTAssertNotEqual(a, b, "real changes must still compare unequal")
        a.cravingsWon += 1
        XCTAssertEqual(a, b)
    }
}

/// Every word that reaches a lock screen.
///
/// Three defects lived here and none was visible in the app: the reason the
/// user gave never reached a single notification, a scheduled quit date
/// produced no day-one alert at all, and the weekly receipt could fire before
/// the user had stopped — reading "0.00 stayed in your pocket this week".
final class NotificationCopyTests: XCTestCase {

    /// The whole point of asking. Someone quitting for Emma should see Emma.
    func testTheNameReachesTheLockScreen() {
        let first = NotificationCopy.dayOne(reason: .someone, name: "Emma")
        XCTAssertTrue(first.body.contains("Emma"), first.body)

        let eve = NotificationCopy.eveOfQuit(reason: .someone, name: "Emma")
        XCTAssertTrue(eve.body.contains("Emma"), eve.body)

        let later = NotificationCopy.morning(day: 20, reason: .someone, name: "Emma")
        XCTAssertTrue(later.body.contains("Emma"), later.body)
    }

    /// ...and it must degrade cleanly. A blank name field is the common case
    /// for someone who picked "someone in particular" and moved on.
    func testAMissingNameNeverLeavesAHole() {
        for name in [nil, "", "   "] as [String?] {
            for message in [
                NotificationCopy.dayOne(reason: .someone, name: name),
                NotificationCopy.eveOfQuit(reason: .someone, name: name),
                NotificationCopy.morning(day: 5, reason: .someone, name: name),
                NotificationCopy.morning(day: 30, reason: .someone, name: name)
            ] {
                XCTAssertFalse(message.body.contains("  "), "double space: \(message.body)")
                XCTAssertFalse(message.body.contains("()"), message.body)
                XCTAssertFalse(message.body.contains("nil"), message.body)
                XCTAssertFalse(message.body.isEmpty)
            }
        }
    }

    /// Every reason gets its own day one — a generic one wastes the only
    /// notification the user has actually been waiting for.
    func testEveryReasonHasItsOwnDayOne() {
        var bodies = Set<String>()
        for reason in QuitReason.allCases {
            let m = NotificationCopy.dayOne(reason: reason, name: "Emma")
            XCTAssertEqual(m.title, "Day one")
            XCTAssertFalse(m.body.isEmpty)
            bodies.insert(m.body)
        }
        XCTAssertEqual(bodies.count, QuitReason.allCases.count,
                       "two reasons share a day-one message")
        // ...and no reason at all still says something.
        XCTAssertFalse(NotificationCopy.dayOne(reason: nil, name: nil).body.isEmpty)
    }

    /// The first week has a script; after that the line varies by reason so a
    /// daily nudge does not become wallpaper.
    func testTheFirstWeekIsNotRepetitive() {
        var seen = Set<String>()
        for day in 1...7 {
            let m = NotificationCopy.morning(day: day, reason: .health, name: nil)
            XCTAssertEqual(m.title, "Day \(day)")
            seen.insert(m.body)
        }
        XCTAssertGreaterThanOrEqual(seen.count, 5,
                                    "the first week repeats itself too often")
    }

    func testLaterMorningsDifferByReason() {
        let bodies = QuitReason.allCases.map {
            NotificationCopy.morning(day: 40, reason: $0, name: "Emma").body
        }
        XCTAssertEqual(Set(bodies).count, QuitReason.allCases.count)
    }

    /// Milestones stay factual: they are the only place the app makes a claim
    /// about the user's body.
    func testMilestonesSayWhenAndWhat() {
        let week = Milestones.all.first { $0.when == "1 week" }!
        let m = NotificationCopy.milestone(week)
        XCTAssertEqual(m.title, week.title)
        XCTAssertTrue(m.body.hasPrefix("1 week in."), m.body)
        XCTAssertTrue(m.body.contains(week.body))
    }

    /// Nothing is long enough to be truncated into meaninglessness on a lock
    /// screen, where roughly 110 characters of body survive.
    func testNothingIsTooLongForALockScreen() {
        var all: [NotificationCopy.Message] = []
        for reason in QuitReason.allCases {
            all.append(NotificationCopy.dayOne(reason: reason, name: "Emma"))
            all.append(NotificationCopy.eveOfQuit(reason: reason, name: "Emma"))
            for day in [1, 2, 3, 5, 40] {
                all.append(NotificationCopy.morning(day: day, reason: reason, name: "Emma"))
            }
        }
        for m in all {
            XCTAssertLessThanOrEqual(m.title.count, 24, "title too long: \(m.title)")
            XCTAssertLessThanOrEqual(m.body.count, 120, "body too long: \(m.body)")
        }
    }
}

/// The name is a dedication, never a witness.
///
/// The app knows a first name and nothing else. It does not know whether that
/// person lives with the user, sees them weekly, or died in 2019. Wording that
/// implied otherwise shipped once — "Emma would say so too", which claims she
/// is watching and approving while saying nothing at all, and "Emma hasn't
/// smelled it on you since", which assumes daily physical proximity.
final class NameUsageTests: XCTestCase {

    private var everyMessageMentioningTheName: [String] {
        var out: [String] = []
        for name in ["Emma", "Dad"] {
            out.append(NotificationCopy.dayOne(reason: .someone, name: name).body)
            out.append(NotificationCopy.eveOfQuit(reason: .someone, name: name).body)
            for day in [1, 2, 3, 5, 9, 16, 40, 400] {
                out.append(NotificationCopy.morning(day: day, reason: .someone, name: name).body)
            }
        }
        return out.filter { $0.contains("Emma") || $0.contains("Dad") }
    }

    /// Nothing may claim the named person perceives, thinks or says anything.
    func testTheNamedPersonIsNeverGivenAnOpinionOrASense() {
        let forbidden = [
            "would say", "would be", "thinks", "knows", "sees", "saw",
            "smelled", "smells", "noticed", "proud", "watching", "'s too"
        ]
        for body in everyMessageMentioningTheName {
            for phrase in forbidden {
                XCTAssertFalse(
                    body.lowercased().contains(phrase),
                    "\"\(body)\" claims something about the named person"
                )
            }
        }
    }

    /// ...and the name still has to appear somewhere, or asking for it was
    /// pointless.
    func testTheNameIsStillUsed() {
        XCTAssertFalse(everyMessageMentioningTheName.isEmpty)
        XCTAssertTrue(
            NotificationCopy.dayOne(reason: .someone, name: "Emma").body.contains("Emma")
        )
    }

    /// No line may tell the user what they are feeling — that is a claim about
    /// someone's inside on a morning that might be going badly.
    func testNothingTellsTheUserHowTheyFeel() {
        var all: [String] = []
        for reason in QuitReason.allCases {
            for day in [1, 2, 3, 5, 9, 16, 40, 400] {
                all.append(NotificationCopy.morning(day: day, reason: reason, name: "Emma").body)
            }
            all.append(NotificationCopy.dayOne(reason: reason, name: "Emma").body)
        }
        for body in all {
            for phrase in ["you feel", "you're not resisting", "you don't want",
                           "whether you've noticed"] {
                XCTAssertFalse(body.lowercased().contains(phrase),
                               "\"\(body)\" tells the user their own state")
            }
        }
    }

    /// No line may assume what day of the week it is.
    func testNothingAssumesTheCalendar() {
        var all: [String] = []
        for reason in QuitReason.allCases {
            all.append(NotificationCopy.dayOne(reason: reason, name: nil).body)
            all.append(NotificationCopy.eveOfQuit(reason: reason, name: nil).body)
            for day in [1, 3, 9, 40] {
                all.append(NotificationCopy.morning(day: day, reason: reason, name: nil).body)
            }
        }
        for body in all {
            for phrase in ["weekend", "monday", "friday", "saturday", "sunday"] {
                XCTAssertFalse(body.lowercased().contains(phrase),
                               "\"\(body)\" assumes the day of the week")
            }
        }
    }
}

/// Backdating a quit date.
///
/// The chips reach a week back, which covers "last Thursday" and nothing else.
/// Someone who stopped in the spring is a real user, since the welcome screen
/// invites them in, so the date has to be settable properly. The risk is what
/// happens to milestones they crossed before installing.
@MainActor
final class BackdatingTests: XCTestCase {

    private func model(quitDaysAgo: Int) -> AppModel {
        let m = AppModel(
            state: PersistedState(),
            clock: AppClock(frozen: Seed.referenceNow),
            store: .ephemeral,
            persistenceEnabled: false,
            subscriptions: MockSubscriptionGate()
        )
        var state = m.state
        state.phase = .app
        let quit = Calendar.current.date(
            byAdding: .day, value: -quitDaysAgo,
            to: Calendar.current.startOfDay(for: Seed.referenceNow)
        )!
        state.plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                              currencyCode: "EUR", quitDate: quit)
        // What OnboardingSteps.finish does for a past date.
        let elapsed = Seed.referenceNow.timeIntervalSince(quit) / 3600
        if elapsed > 0 { state.lastCelebratedHours = elapsed }
        m.state = state
        return m
    }

    /// Someone who stopped a month ago has crossed seven marks. Firing even one
    /// burst for a morning in July is hollow, and firing seven is absurd.
    func testNothingIsCelebratedRetrospectively() {
        let m = model(quitDaysAgo: 30)
        m.claimPendingCelebration()
        XCTAssertNil(m.pendingCelebration,
                     "a milestone crossed before install was celebrated")
        XCTAssertNil(m.withheldDay)
    }

    /// ...but the streak itself is real and counted.
    func testTheDaysStillCount() {
        XCTAssertEqual(model(quitDaysAgo: 30).progress?.dayNumber, 31)
        XCTAssertEqual(model(quitDaysAgo: 200).progress?.dayNumber, 201)
    }

    /// And the next milestone ahead of them still fires normally.
    func testTheNextOneStillArrives() {
        let m = model(quitDaysAgo: 30)          // past 1 month, before 3 months
        m.claimPendingCelebration()
        XCTAssertNil(m.pendingCelebration)

        // Three months later, the mark they reach *with* the app is theirs.
        var state = m.state
        state.plan?.quitDate = Calendar.current.date(
            byAdding: .day, value: -95, to: Seed.referenceNow)!
        m.state = state
        m.claimPendingCelebration()
        XCTAssertEqual(m.pendingCelebration?.when, "3 months")
    }
}

/// A scheduled start does not begin on its own.
///
/// The count used to be pure arithmetic on the clock: `now >= quitDate`. Set
/// Monday, keep smoking, open the app on Wednesday and it said day three. The
/// one number the whole product rests on was being asserted by a calendar
/// rather than reported by a person.
@MainActor
final class ScheduledStartTests: XCTestCase {

    private func scheduled(daysFromNow: Int) -> AppModel {
        let m = AppModel(
            state: PersistedState(),
            clock: AppClock(frozen: Seed.referenceNow),
            store: .ephemeral,
            persistenceEnabled: false,
            subscriptions: MockSubscriptionGate()
        )
        var state = m.state
        state.phase = .app
        var plan = QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                            currencyCode: "EUR", quitDate: Seed.referenceNow)
        plan.quitDate = Calendar.current.date(
            byAdding: .day, value: daysFromNow,
            to: Calendar.current.startOfDay(for: Seed.referenceNow)
        )!
        state.plan = plan
        state.awaitingStart = daysFromNow > 0
        m.state = state
        return m
    }

    /// Before the day: counting down, not counting up, and nothing to confirm.
    func testBeforeTheDayNothingIsPending() {
        let m = scheduled(daysFromNow: 3)
        XCTAssertFalse(m.awaitingStartConfirmation)
        XCTAssertEqual(m.progress?.hasStarted, false)
    }

    /// The day passes unconfirmed: the app asks rather than assuming.
    func testThePassedDayAsksInsteadOfCounting() {
        let m = scheduled(daysFromNow: 3)
        var state = m.state
        state.plan?.quitDate = Calendar.current.date(
            byAdding: .day, value: -2, to: Seed.referenceNow)!
        m.state = state
        XCTAssertTrue(m.awaitingStartConfirmation,
                      "two days past a scheduled start and it just counted")
    }

    /// Confirming starts the count from the day they said.
    func testConfirmingStartsTheCount() {
        let m = scheduled(daysFromNow: 3)
        var state = m.state
        state.plan?.quitDate = Calendar.current.date(
            byAdding: .day, value: -2, to: Seed.referenceNow)!
        m.state = state

        m.confirmStart()
        XCTAssertFalse(m.awaitingStartConfirmation)
        XCTAssertEqual(m.state.awaitingStart, false)
        XCTAssertEqual(m.progress?.dayNumber, 3)
    }

    /// "I stopped, but later than that" moves the start and shortens the count.
    func testStoppingLaterCountsFromLater() {
        let m = scheduled(daysFromNow: 3)
        var state = m.state
        state.plan?.quitDate = Calendar.current.date(
            byAdding: .day, value: -4, to: Seed.referenceNow)!
        m.state = state

        let actually = Calendar.current.date(byAdding: .day, value: -1, to: Seed.referenceNow)!
        m.confirmStart(at: actually)
        XCTAssertEqual(m.progress?.dayNumber, 2)
        XCTAssertFalse(m.awaitingStartConfirmation)
    }

    /// "Not yet, move it" pushes the date out and keeps waiting.
    func testReschedulingKeepsItPending() {
        let m = scheduled(daysFromNow: 3)
        let later = Calendar.current.date(byAdding: .day, value: 5, to: Seed.referenceNow)!
        m.rescheduleStart(to: later)
        XCTAssertEqual(m.state.awaitingStart, true)
        XCTAssertFalse(m.awaitingStartConfirmation)
        XCTAssertEqual(m.progress?.hasStarted, false)
    }

    /// "Start now instead" from the countdown begins immediately.
    func testStartingNowBegins() {
        let m = scheduled(daysFromNow: 3)
        m.confirmStart(at: Seed.referenceNow)
        XCTAssertFalse(m.awaitingStartConfirmation)
        XCTAssertEqual(m.progress?.dayNumber, 1)
        XCTAssertEqual(m.progress?.hasStarted, true)
    }

    /// Nothing is celebrated for the gap between the scheduled day and owning
    /// up to it: the user was not stopped during it.
    func testTheUnconfirmedGapEarnsNoCelebration() {
        let m = scheduled(daysFromNow: 3)
        var state = m.state
        state.plan?.quitDate = Calendar.current.date(
            byAdding: .day, value: -5, to: Seed.referenceNow)!
        m.state = state
        m.confirmStart()
        m.claimPendingCelebration()
        XCTAssertNil(m.pendingCelebration)
    }

    /// State written before any of this existed must still decode. There is no
    /// custom decoder, so a non-optional addition would throw and take the
    /// user's streak with it.
    func testOlderSavedStateStillLoads() throws {
        let json = """
        {"phase":"app","cravingsWon":3,"notifyMilestones":true,"notifyWeeklyBill":true,
         "notifyMorningCheckIn":false,"reasons":[],"lastCelebratedHours":0,
         "pastAttempts":[],"slips":[],"updatedAt":0}
        """.data(using: .utf8)!
        let state = try JSONDecoder().decode(PersistedState.self, from: json)
        XCTAssertNil(state.awaitingStart)
        XCTAssertEqual(state.cravingsWon, 3)
    }

    // MARK: - Finishing onboarding

    /// The commit moved out of QuitMomentStep when the reminders step was added
    /// after it. These pin the behaviour to its new home rather than to the
    /// view that used to own it.
    private func draftingModel(quitDate: Date) -> AppModel {
        let m = AppModel(clock: FrozenClock(now: Seed.referenceNow))
        var draft = QuitPlan.starting(product: .cigarettes)
        draft.weeklySpend = 60
        draft.quitDate = quitDate
        m.draft = draft
        return m
    }

    func testFinishingOnboardingSavesThePlanAndMovesToPaywall() {
        let m = draftingModel(quitDate: Seed.referenceNow)
        m.completeOnboarding()
        XCTAssertNotNil(m.state.plan)
        XCTAssertEqual(m.state.phase, .paywall)
    }

    func testAFutureDateFinishesAwaitingConfirmation() {
        let future = Calendar.current.date(
            byAdding: .day, value: 4, to: Seed.referenceNow)!
        let m = draftingModel(quitDate: future)
        m.completeOnboarding()
        XCTAssertEqual(m.state.awaitingStart, true)
        // Not yet due, so it counts down rather than asking.
        XCTAssertFalse(m.awaitingStartConfirmation)
    }

    func testStartingNowNeverAwaitsConfirmation() {
        let m = draftingModel(quitDate: Seed.referenceNow)
        m.completeOnboarding()
        XCTAssertEqual(m.state.awaitingStart, false)
        XCTAssertFalse(m.awaitingStartConfirmation)
    }

    func testBackdatingFinishesWithoutRetroactiveCelebrations() {
        let past = Calendar.current.date(
            byAdding: .day, value: -31, to: Seed.referenceNow)!
        let m = draftingModel(quitDate: past)
        m.completeOnboarding()
        XCTAssertEqual(m.state.awaitingStart, false)
        m.claimPendingCelebration()
        XCTAssertNil(m.pendingCelebration)
    }
}
