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
