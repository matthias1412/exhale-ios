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
        price: Decimal,
        daysAgo: Double
    ) -> QuitPlan {
        QuitPlan(
            product: product,
            amount: amount,
            unitPrice: price,
            currencyCode: "EUR",
            quitDate: Date(timeIntervalSince1970: 1_700_000_000 - daysAgo * 86_400)
        )
    }

    private func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000) }

    // MARK: - Cigarettes

    func testCigarettesDailyCost() {
        // 15/day at €9.50 for 20 → 0.75 packs/day → €7.125/day
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, price: 9.50, daysAgo: 1),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 7.125, accuracy: 0.0001)
    }

    func testCigarettesOverNinetyDays() {
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, price: 9.50, daysAgo: 90),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.moneyKept as NSDecimalNumber).doubleValue, 641.25, accuracy: 0.01)
        XCTAssertEqual(p.unitsAvoided, 1350)
        XCTAssertEqual(p.containersAvoided, 67)      // floor(1350/20)
        XCTAssertEqual(p.hoursReclaimed, 248)        // round(1350 * 11 / 60)
    }

    // MARK: - Vape (the weekly one)

    func testVapeConvertsWeeklyToDaily() {
        // 5 pods/week → 5/7 per day. Pod IS the container, so unitsPerContainer = 1.
        let p = QuitProgress(plan: plan(.vape, amount: 5, price: 6.00, daysAgo: 7),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 30.0 / 7, accuracy: 0.0001)
        XCTAssertEqual((p.moneyKept as NSDecimalNumber).doubleValue, 30.0, accuracy: 0.001)
        XCTAssertEqual(p.unitsAvoided, 5)
        XCTAssertEqual(p.containersAvoided, 5)
    }

    func testVapeMonthlyBurn() {
        let p = QuitProgress(plan: plan(.vape, amount: 5, price: 6.00, daysAgo: 1),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.monthlyBurn as NSDecimalNumber).doubleValue,
                       (30.0 / 7) * 30.4, accuracy: 0.001)
    }

    // MARK: - Pouches

    func testPouchContainerMaths() {
        // 8/day, 20 per tin → a tin lasts 2.5 days. 30 days → 240 pouches → 12 tins.
        let p = QuitProgress(plan: plan(.pouches, amount: 8, price: 5.50, daysAgo: 30),
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
                                                unitPrice: 9.5, currencyCode: "EUR",
                                                quitDate: quit),
                                 now: quit.addingTimeInterval(240), calendar: calendar)
        XCTAssertEqual(sameNight.dayNumber, 1)

        // 90 minutes later it is past midnight — day 2, despite 1.5 hours elapsed.
        let afterMidnight = QuitProgress(plan: QuitPlan(product: .cigarettes, amount: 15,
                                                    unitPrice: 9.5, currencyCode: "EUR",
                                                    quitDate: quit),
                                     now: quit.addingTimeInterval(5400), calendar: calendar)
        XCTAssertEqual(afterMidnight.dayNumber, 2)
    }

    func testClockGoingBackwardsCannotRewindTheStreak() {
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, price: 9.5, daysAgo: 10),
                         now: now().addingTimeInterval(-20 * 86_400), calendar: calendar)
        XCTAssertEqual(p.dayNumber, 1)
        XCTAssertEqual(p.elapsed, 0)
        XCTAssertEqual(p.moneyKept, 0)
    }

    // MARK: - Paywall anchor

    func testPaybackDays() {
        let p = QuitProgress(plan: plan(.cigarettes, amount: 15, price: 9.50, daysAgo: 1),
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
        XCTAssertEqual(Currencies.priceStep(for: "JPY"), 10)
        XCTAssertEqual(Currencies.priceStep(for: "ISK"), 10)
        XCTAssertEqual(Currencies.priceStep(for: "EUR"), 0.5)
        XCTAssertEqual(Currencies.priceStep(for: "GBP"), 0.5)
    }

    func testANewPlanHasNoInventedPrice() {
        XCTAssertEqual(QuitPlan.starting(product: .cigarettes, currency: "EUR").unitPrice, 0)
    }
}

/// Relapse is the norm, not the exception, so the maths around it has to hold.
final class RelapseTests: XCTestCase {

    private func state(quitDaysAgo: Int) -> PersistedState {
        var s = PersistedState()
        s.plan = QuitPlan(product: .cigarettes, amount: 15, unitPrice: 9.5,
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
        s.plan = QuitPlan(product: .cigarettes, amount: 15, unitPrice: 9.5,
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
        s.plan = QuitPlan(product: .cigarettes, amount: 15, unitPrice: 9.5,
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
