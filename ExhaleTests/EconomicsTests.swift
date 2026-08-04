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
        let p = Progress(plan: plan(.cigarettes, amount: 15, price: 9.50, daysAgo: 1),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 7.125, accuracy: 0.0001)
    }

    func testCigarettesOverNinetyDays() {
        let p = Progress(plan: plan(.cigarettes, amount: 15, price: 9.50, daysAgo: 90),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.moneyKept as NSDecimalNumber).doubleValue, 641.25, accuracy: 0.01)
        XCTAssertEqual(p.unitsAvoided, 1350)
        XCTAssertEqual(p.containersAvoided, 67)      // floor(1350/20)
        XCTAssertEqual(p.hoursReclaimed, 248)        // round(1350 * 11 / 60)
    }

    // MARK: - Vape (the weekly one)

    func testVapeConvertsWeeklyToDaily() {
        // 5 pods/week → 5/7 per day. Pod IS the container, so unitsPerContainer = 1.
        let p = Progress(plan: plan(.vape, amount: 5, price: 6.00, daysAgo: 7),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 30.0 / 7, accuracy: 0.0001)
        XCTAssertEqual((p.moneyKept as NSDecimalNumber).doubleValue, 30.0, accuracy: 0.001)
        XCTAssertEqual(p.unitsAvoided, 5)
        XCTAssertEqual(p.containersAvoided, 5)
    }

    func testVapeMonthlyBurn() {
        let p = Progress(plan: plan(.vape, amount: 5, price: 6.00, daysAgo: 1),
                         now: now(), calendar: calendar)
        XCTAssertEqual((p.monthlyBurn as NSDecimalNumber).doubleValue,
                       (30.0 / 7) * 30.4, accuracy: 0.001)
    }

    // MARK: - Pouches

    func testPouchContainerMaths() {
        // 8/day, 20 per tin → a tin lasts 2.5 days. 30 days → 240 pouches → 12 tins.
        let p = Progress(plan: plan(.pouches, amount: 8, price: 5.50, daysAgo: 30),
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

        let sameNight = Progress(plan: QuitPlan(product: .cigarettes, amount: 15,
                                                unitPrice: 9.5, currencyCode: "EUR",
                                                quitDate: quit),
                                 now: quit.addingTimeInterval(240), calendar: calendar)
        XCTAssertEqual(sameNight.dayNumber, 1)

        // 90 minutes later it is past midnight — day 2, despite 1.5 hours elapsed.
        let afterMidnight = Progress(plan: QuitPlan(product: .cigarettes, amount: 15,
                                                    unitPrice: 9.5, currencyCode: "EUR",
                                                    quitDate: quit),
                                     now: quit.addingTimeInterval(5400), calendar: calendar)
        XCTAssertEqual(afterMidnight.dayNumber, 2)
    }

    func testClockGoingBackwardsCannotRewindTheStreak() {
        let p = Progress(plan: plan(.cigarettes, amount: 15, price: 9.5, daysAgo: 10),
                         now: now().addingTimeInterval(-20 * 86_400), calendar: calendar)
        XCTAssertEqual(p.dayNumber, 1)
        XCTAssertEqual(p.elapsed, 0)
        XCTAssertEqual(p.moneyKept, 0)
    }

    // MARK: - Paywall anchor

    func testPaybackDays() {
        let p = Progress(plan: plan(.cigarettes, amount: 15, price: 9.50, daysAgo: 1),
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

    func testDefaultPriceRespectsProductRatio() {
        let cigs = Currencies.defaultPrice(for: .cigarettes, currency: "EUR")
        let vape = Currencies.defaultPrice(for: .vape, currency: "EUR")
        XCTAssertGreaterThan(cigs, vape)
    }
}
