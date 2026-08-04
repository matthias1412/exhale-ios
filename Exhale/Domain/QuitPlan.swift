import Foundation

/// The four stored facts. Everything the app displays is derived from these —
/// there is no duplicated state, no cached counters, no accumulated timers.
struct QuitPlan: Codable, Equatable, Sendable {
    var product: NicotineProduct
    /// Units per `product.config.period` — cigarettes/day, pods/week, pouches/day.
    var amount: Int
    /// Price of one container (pack / pod / tin) in `currencyCode`.
    var unitPrice: Decimal
    var currencyCode: String
    /// The exact instant of the last one. Physiological milestones and the money
    /// counter run from this; the day *number* runs off local midnights.
    var quitDate: Date

    var config: ProductConfig { product.config }

    static func starting(
        product: NicotineProduct,
        currency: String = Currencies.deviceDefault,
        quitDate: Date = Date()
    ) -> QuitPlan {
        QuitPlan(
            product: product,
            amount: product.config.defaultAmount,
            unitPrice: Currencies.defaultPrice(for: product, currency: currency),
            currencyCode: currency,
            quitDate: quitDate
        )
    }
}

/// Everything shown on screen, recomputed from `QuitPlan` + the current instant.
///
/// Two different clocks on purpose:
///  - **Day number** counts local midnights, so "Day 2" begins at midnight and
///    the streak reads the way people actually talk about it.
///  - **Everything else** runs from the exact quit instant, because the money
///    should tick smoothly and the body doesn't heal on calendar boundaries.
struct Progress: Equatable, Sendable {

    let dayNumber: Int
    let elapsed: TimeInterval
    let hoursElapsed: Double
    let moneyKept: Decimal
    let monthlyBurn: Decimal
    let dailyCost: Decimal
    let unitsAvoided: Int
    let containersAvoided: Int
    /// Cigarettes only — 11 minutes per cigarette, a widely published figure.
    let hoursReclaimed: Int

    init(plan: QuitPlan, now: Date = Date(), calendar: Calendar = .current) {
        let raw = now.timeIntervalSince(plan.quitDate)
        let elapsed = max(0, raw)
        self.elapsed = elapsed
        self.hoursElapsed = elapsed / 3600

        // Calendar days, local midnight. Quit day itself is day 1.
        let startOfQuitDay = calendar.startOfDay(for: plan.quitDate)
        let startOfToday = calendar.startOfDay(for: max(now, plan.quitDate))
        let midnights = calendar.dateComponents(
            [.day], from: startOfQuitDay, to: startOfToday
        ).day ?? 0
        self.dayNumber = max(1, midnights + 1)

        let cfg = plan.config
        let dailyUnits = Double(plan.amount) / cfg.period.daysPerPeriod
        let dailyCost = Decimal(dailyUnits / Double(cfg.unitsPerContainer)) * plan.unitPrice
        self.dailyCost = dailyCost

        let elapsedDays = elapsed / 86_400
        self.moneyKept = dailyCost * Decimal(elapsedDays)
        self.monthlyBurn = dailyCost * Decimal(30.4)

        // Nudge off the floating-point cliff before flooring. 5 pods/week over
        // exactly 7 days is 4.999999… in binary, which would show "4 pods
        // avoided" on the day the fifth one was due.
        let rawUnits = dailyUnits * elapsedDays
        let units = Int(((rawUnits * 1e9).rounded() / 1e9).rounded(.down))
        self.unitsAvoided = units
        self.containersAvoided = units / cfg.unitsPerContainer
        self.hoursReclaimed = Int((Double(units) * 11 / 60).rounded())
    }

    /// Paywall anchor: how many days of not buying pay for a year of Exhale.
    func paybackDays(yearlyPrice: Decimal) -> Int {
        guard dailyCost > 0 else { return 1 }
        let days = (yearlyPrice / dailyCost) as NSDecimalNumber
        return max(1, Int(days.doubleValue.rounded(.up)))
    }
}
