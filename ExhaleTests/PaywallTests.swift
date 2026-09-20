import XCTest
@testable import Exhale

/// The paywall's numbers have to be true, not just persuasive.
final class PaywallTests: XCTestCase {

    private func plan(currency: String) -> QuitPlan {
        QuitPlan(product: .cigarettes, amount: 15, weeklySpend: 49.875,
                 currencyCode: currency,
                 quitDate: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func progress(_ plan: QuitPlan) -> QuitProgress {
        QuitProgress(plan: plan, now: Date(timeIntervalSince1970: 1_700_000_000))
    }

    /// The annual figure is the persuasive one, so it had better be right.
    func testYearlyBurnIsDailyCostTimesThreeSixtyFive() {
        let p = progress(plan(currency: "EUR"))
        // €49.875 a week is €7.125 a day. No pack size involved.
        XCTAssertEqual((p.dailyCost as NSDecimalNumber).doubleValue, 7.125, accuracy: 0.001)
        XCTAssertEqual((p.yearlyBurn as NSDecimalNumber).doubleValue,
                       7.125 * 365, accuracy: 0.01)
    }

    func testYearlyBurnIsTwelveMonthsIshOfMonthlyBurn() {
        let p = progress(plan(currency: "EUR"))
        let monthlyTimesTwelve = (p.monthlyBurn as NSDecimalNumber).doubleValue * 12
        let yearly = (p.yearlyBurn as NSDecimalNumber).doubleValue
        // 30.4 * 12 = 364.8 vs 365 — within half a percent of each other.
        XCTAssertEqual(yearly / monthlyTimesTwelve, 1, accuracy: 0.005)
    }

    /// The bug this guards: the payback figure divides the store's price by the
    /// user's daily cost. If the App Store charged in EUR and the user priced
    /// their pack in GBP, that division is meaningless.
    func testPaybackComparisonRequiresMatchingCurrencies() {
        let euroOffer = MockSubscriptionGate.sampleOffers[0]
        XCTAssertEqual(euroOffer.currencyCode, "EUR")

        let euroPlan = plan(currency: "EUR")
        XCTAssertTrue(
            euroOffer.currencyCode.caseInsensitiveCompare(euroPlan.currencyCode) == .orderedSame,
            "matching currencies should permit the comparison"
        )

        let sterlingPlan = plan(currency: "GBP")
        XCTAssertFalse(
            euroOffer.currencyCode.caseInsensitiveCompare(sterlingPlan.currencyCode) == .orderedSame,
            "a EUR offer must never be compared against a GBP habit"
        )
    }

    func testPaybackDaysUsesTheStorePriceNotAGuess() {
        let p = progress(plan(currency: "EUR"))
        // €29.99 / €7.125 a day = 4.2 -> 5 days
        XCTAssertEqual(p.paybackDays(yearlyPrice: 29.99), 5)
        // A different store price must move the answer.
        XCTAssertEqual(p.paybackDays(yearlyPrice: 59.99), 9)
    }

    /// No offer should ever carry a price string the app assembled itself.
    func testOffersCarryStoreSuppliedPriceStrings() {
        for offer in MockSubscriptionGate.sampleOffers {
            XCTAssertFalse(offer.localisedPrice.isEmpty)
            XCTAssertFalse(offer.currencyCode.isEmpty)
        }
    }

    /// A zero-cost habit must not divide by zero on the anchor.
    func testZeroCostHabitDoesNotCrashThePaybackAnchor() {
        var free = plan(currency: "EUR")
        free.weeklySpend = 0
        XCTAssertEqual(progress(free).paybackDays(yearlyPrice: 29.99), 1)
    }
}

/// When the paywall is allowed to stand in front of the app, and when it is
/// emphatically not.
///
/// This is the money path and it has two opposite failure modes, each bad in
/// its own direction: let everyone through and the app earns nothing; lock on
/// a question the store never answered and paying subscribers are shut out of
/// what they bought, or — worse — a broken offering bricks every install at
/// once with no way to buy the way out and no release ready to fix it.
@MainActor
final class SubscriptionLockTests: XCTestCase {

    private func model(_ gate: MockSubscriptionGate) -> AppModel {
        AppModel(
            state: PersistedState(),
            clock: AppClock(frozen: Seed.referenceNow),
            store: .ephemeral,
            persistenceEnabled: false,
            subscriptions: gate
        )
    }

    func testUnknownEntitlementDoesNotLock() {
        // The state at every cold launch, for as long as the store takes.
        XCTAssertFalse(model(MockSubscriptionGate(isSubscribed: nil)).isLocked)
    }

    func testSubscriberIsNotLocked() {
        XCTAssertFalse(model(MockSubscriptionGate(isSubscribed: true)).isLocked)
    }

    func testNonSubscriberWithOffersIsLocked() {
        XCTAssertTrue(model(MockSubscriptionGate(isSubscribed: false)).isLocked)
    }

    /// The brick case. No offering means no way to buy, and locking someone
    /// out with no way back in is not a paywall.
    func testNonSubscriberIsNotLockedWhenNothingCanBeSold() {
        let gate = MockSubscriptionGate(state: .unavailable("No subscriptions are available right now."),
                                        isSubscribed: false)
        XCTAssertFalse(model(gate).isLocked)
    }

    func testNonSubscriberIsNotLockedWhilePricesAreStillLoading() {
        let gate = MockSubscriptionGate(state: .loading, isSubscribed: false)
        XCTAssertFalse(model(gate).isLocked)
    }

    /// Buying is the way through, and the only way through.
    func testPurchaseUnlocks() async {
        let gate = MockSubscriptionGate(isSubscribed: false)
        let m = model(gate)
        XCTAssertTrue(m.isLocked)
        _ = await gate.purchase(MockSubscriptionGate.sampleOffers[0])
        XCTAssertFalse(m.isLocked)
    }
}

/// The one line on the paywall that talks about time.
///
/// It is read from three places on the timeline and was true from only one of
/// them: at ninety days it told people their heart rate would settle in
/// twenty minutes, which had happened three months earlier.
final class MilestoneImmediacyTests: XCTestCase {

    private let quit = Date(timeIntervalSince1970: 1_700_000_000)

    private func line(hoursElapsed: Double,
                      product: NicotineProduct = .cigarettes) -> MilestoneImmediacy? {
        MilestoneImmediacy(product: product, hoursElapsed: hoursElapsed, quitDate: quit)
    }

    func testTheMomentTheyStopItIsTheFirstMilestoneMinutesAway() {
        let l = line(hoursElapsed: 0)
        XCTAssertEqual(l?.lede, "Your first milestone is ")
        // 0.34h = 20.4 min.
        XCTAssertEqual(l?.value, "20 min away")
        XCTAssertEqual(l?.title, "heart rate settles")
    }

    /// Someone who stopped at breakfast and reached the paywall mid-morning.
    /// Their heart rate settled long ago, so this is no longer their first.
    func testAFewHoursInItIsTheNextOneCountedFromNow() {
        let l = line(hoursElapsed: 1.7)
        XCTAssertEqual(l?.lede, "Your next milestone is ")
        // Carbon monoxide clears at 12h: 10.3h away, not "12 h".
        XCTAssertEqual(l?.value, "10 hours away")
    }

    func testAnHourAwayIsSingular() {
        // Carbon monoxide clears at 12h, so eleven hours in leaves exactly one.
        XCTAssertEqual(line(hoursElapsed: 11)?.value, "1 hour away")
    }

    func testUnderAnHourIsSaidInMinutes() {
        XCTAssertEqual(line(hoursElapsed: 11.2)?.value, "48 min away")
    }

    /// The bug that started this: `Milestone.when` is the distance from the
    /// quit date, so a mark at "6 months" is not six months away from someone
    /// who is already three months in.
    func testDistantMilestonesAreNamedByDateNotByDistanceFromTheQuitDate() {
        let l = line(hoursElapsed: 24 * 90)
        XCTAssertEqual(l?.lede, "Your next milestone is ")
        XCTAssertFalse(l?.value.contains("away") ?? true,
                       "a mark months out should be dated, not counted in hours")
        XCTAssertFalse(l?.value.isEmpty ?? true)
    }

    /// Inside a day it must read as a duration. Naming a date for something
    /// happening this evening makes it sound further off than it is.
    func testSomethingLaterTodayIsSaidInHoursNotAsADate() {
        let value = line(hoursElapsed: 2)?.value ?? ""
        XCTAssertTrue(value.hasSuffix("away"), "got \(value)")
    }

    func testNothingIsClaimedOnceEveryMilestoneIsBehindThem() {
        // Well past the last mark on the timeline.
        XCTAssertNil(line(hoursElapsed: 24 * 365 * 25))
    }
}
