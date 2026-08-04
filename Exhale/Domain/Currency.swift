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

    /// Typical shelf price of a 20-cigarette pack, used only as the initial
    /// stepper value. Editable by the user on the very next tap.
    private static let referencePackPrices: [String: Double] = [
        "EUR": 9.50, "USD": 9.00, "GBP": 16.00, "CHF": 9.50,
        "DKK": 65, "NOK": 150, "SEK": 90, "ISK": 1800,
        "PLN": 20, "CZK": 160, "CAD": 18, "AUD": 45,
        "JPY": 600, "BRL": 12
    ]

    /// Falls back to 10 units for currencies we have no reference for. That is
    /// a starting position, not a claim about local prices.
    static func referencePackPrice(for code: String) -> Double {
        referencePackPrices[code.uppercased()] ?? 10
    }

    static func defaultPrice(for product: NicotineProduct, currency: String) -> Decimal {
        let pack = referencePackPrice(for: currency)
        let raw = pack * product.config.priceRelativeToPack
        let step = priceStep(for: currency)
        return roundToStep(Decimal(raw), step: step)
    }

    /// Number of fraction digits this currency actually uses (0 for JPY, ISK…).
    static func fractionDigits(for code: String) -> Int {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.maximumFractionDigits
    }

    /// Stepper increment: roughly one twentieth of a typical pack, snapped to a
    /// 1/2/5 × 10ⁿ value, and never finer than the currency's minor unit.
    static func priceStep(for code: String) -> Decimal {
        let target = referencePackPrice(for: code) / 20
        let magnitude = pow(10.0, (log10(target)).rounded(.down))
        let normalised = target / magnitude
        let nice: Double = normalised < 1.5 ? 1 : (normalised < 3.5 ? 2 : 5)
        var step = nice * magnitude

        let minorUnit = pow(10.0, -Double(fractionDigits(for: code)))
        if step < minorUnit { step = minorUnit }
        return Decimal(step)
    }

    static func roundToStep(_ value: Decimal, step: Decimal) -> Decimal {
        guard step > 0 else { return value }
        let steps = (value / step) as NSDecimalNumber
        let rounded = Decimal(steps.doubleValue.rounded())
        return max(step, rounded * step)
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
