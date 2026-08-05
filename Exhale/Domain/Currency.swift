import Foundation

/// Currency handling.
///
/// Deliberately contains **no exchange rates**. The prototype carried a table of
/// multipliers against EUR (`USD: 1.1`, `JPY: 170`, …) which would have shown
/// stale, wrong prices to most of the world. Two rules replace it:
///
///  1. Subscription prices always come from the store, already localised.
///     Nothing in this file touches them.
///  2. The user's own pack/pod/tin price is entered by the user. All we supply
///     is a plausible *starting position* for the stepper, per currency, which
///     they immediately adjust. Those are typical retail prices, not conversions.
enum Currencies {

    /// Offered as chips on the price step. The device's own currency is added
    /// at the front if it isn't already here.
    static let suggested = [
        "EUR", "USD", "GBP", "CHF", "DKK", "NOK", "SEK",
        "ISK", "PLN", "CZK", "CAD", "AUD", "JPY", "BRL"
    ]

    /// The currency to start onboarding in.
    static var deviceDefault: String {
        Locale.current.currency?.identifier ?? "EUR"
    }

    /// Chips to show, device currency first.
    static func chips(includingSelected selected: String) -> [String] {
        var codes = suggested
        for extra in [deviceDefault, selected] where !codes.contains(extra) {
            codes.insert(extra, at: 0)
        }
        return codes
    }

    /// There is deliberately **no table of typical prices per country**.
    ///
    /// Guessing what a pack costs in 175 storefronts is data we would have to
    /// keep correct forever, and being wrong shows the user a number that
    /// insults them. The user types their own price; the app starts blank and
    /// asks. That is both more accurate and less code.

    /// Number of fraction digits this currency actually uses (0 for JPY, ISK…).
    static func fractionDigits(for code: String) -> Int {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.maximumFractionDigits
    }

    /// Stepper increment, derived only from the currency's own minor unit —
    /// nothing here needs to know what things cost anywhere.
    ///
    /// Sized for a spend figure rather than a pack price. When the question
    /// was "price of a pack" a 0.50 nudge was right; a weekly vape spend is an
    /// order of magnitude larger, and stepping to it half a unit at a time is
    /// thirty taps.
    static func priceStep(for code: String) -> Decimal {
        fractionDigits(for: code) == 0 ? 50 : 1
    }

}

extension Decimal {
    /// "€9.50" / "¥600" / "65 kr" — symbol and placement come from the system,
    /// never from a hand-maintained table.
    func currencyString(_ code: String, fractionDigits: Int? = nil) -> String {
        let digits = fractionDigits ?? Currencies.fractionDigits(for: code)
        return formatted(.currency(code: code).precision(.fractionLength(digits)))
    }

    /// The big money figure on The Bill and the Today stats. Drops the decimals
    /// once the number is long enough that they stop meaning anything.
    func moneyString(_ code: String) -> String {
        let natural = Currencies.fractionDigits(for: code)
        let digits = (self >= 10_000 || natural == 0) ? 0 : natural
        return currencyString(code, fractionDigits: digits)
    }
}
