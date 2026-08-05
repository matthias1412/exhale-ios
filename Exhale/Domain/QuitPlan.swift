import Foundation

/// The four stored facts. Everything the app displays is derived from these —
/// there is no duplicated state, no cached counters, no accumulated timers.
struct QuitPlan: Codable, Equatable, Sendable {
    var product: NicotineProduct
    /// Units per `product.config.period` — cigarettes/day, pods/week, pouches/day.
    var amount: Int
    /// What the habit costs in a week, in `currencyCode`.
    ///
    /// This used to be the price of one container, with the money derived as
    /// `amount / unitsPerContainer * unitPrice`. That only works if everyone's
    /// container holds the same number, and none of them do: cigarettes come in
    /// tens, twenties and twenty-fives, pouch tins run anywhere from ten to
    /// twenty-two, and a "pod" covers everything from a refill to a disposable
    /// that lasts a fortnight. A user answering "€6" for a tin of fifteen while
    /// the app assumed twenty was quietly told they were saving a quarter less
    /// than they were.
    ///
    /// Spend is the one number people actually know, and it needs no assumption
    /// about packaging at all.
    var weeklySpend: Decimal
    var currencyCode: String
    /// The exact instant of the last one. Physiological milestones and the money
    /// counter run from this; the day *number* runs off local midnights.
    var quitDate: Date

    var config: ProductConfig { product.config }

    /// The spend as the user is asked for it — per day for cigarettes and
    /// pouches, per week for vape, matching the amount question right before.
    /// Stored weekly regardless, so switching product can't rescale the money.
    var spendPerPeriod: Decimal {
        get {
            switch config.period {
            case .day: weeklySpend / 7
            case .week: weeklySpend
            }
        }
        set {
            switch config.period {
            case .day: weeklySpend = newValue * 7
            case .week: weeklySpend = newValue
            }
        }
    }

    static func starting(
        product: NicotineProduct,
        currency: String = Currencies.deviceDefault,
        quitDate: Date = Date()
    ) -> QuitPlan {
        QuitPlan(
            product: product,
            amount: product.config.defaultAmount,
            weeklySpend: 0,   // the user types it; we never guess
            currencyCode: currency,
            quitDate: quitDate
        )
    }

    // MARK: - Persistence

    /// `unitPrice` has no property behind it — it exists only so an old plan
    /// can still be read. That also means the encoder cannot be synthesised
    /// (Swift has nothing to write for it), so it is spelled out below.
    private enum CodingKeys: String, CodingKey {
        case product, amount, weeklySpend, currencyCode, quitDate
        case unitPrice   // pre-spend plans only, never written
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(product, forKey: .product)
        try container.encode(amount, forKey: .amount)
        try container.encode(weeklySpend, forKey: .weeklySpend)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(quitDate, forKey: .quitDate)
    }

    init(product: NicotineProduct, amount: Int, weeklySpend: Decimal,
         currencyCode: String, quitDate: Date) {
        self.product = product
        self.amount = amount
        self.weeklySpend = weeklySpend
        self.currencyCode = currencyCode
        self.quitDate = quitDate
    }

    /// Reads plans written before the switch to spend.
    ///
    /// Throwing here would fail the whole `PersistedState` decode and drop the
    /// user back into onboarding with their streak gone — which is the one
    /// thing this app must never do. Old plans are converted using the very
    /// container assumption being retired, because for an existing user that
    /// figure is what they have been watching tick up, and changing it under
    /// them would be worse than carrying it forward.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        product = try container.decode(NicotineProduct.self, forKey: .product)
        amount = try container.decode(Int.self, forKey: .amount)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        quitDate = try container.decode(Date.self, forKey: .quitDate)

        if let weekly = try container.decodeIfPresent(Decimal.self, forKey: .weeklySpend) {
            weeklySpend = weekly
        } else {
            let unitPrice = try container.decodeIfPresent(Decimal.self, forKey: .unitPrice) ?? 0
            let cfg = product.config
            let dailyUnits = Double(amount) / cfg.period.daysPerPeriod
            let dailyCost = Decimal(dailyUnits / Double(cfg.unitsPerContainer)) * unitPrice
            weeklySpend = dailyCost * 7
        }
    }
}

/// Everything shown on screen, recomputed from `QuitPlan` + the current instant.
///
/// Two different clocks on purpose:
///  - **Day number** counts local midnights, so "Day 2" begins at midnight and
///    the streak reads the way people actually talk about it.
///  - **Everything else** runs from the exact quit instant, because the money
///    should tick smoothly and the body doesn't heal on calendar boundaries.
struct QuitProgress: Equatable, Sendable {

    let dayNumber: Int
    /// False when the quit date is still ahead — the user has scheduled it.
    /// Everything derived is zero until then; there is nothing to count yet.
    let hasStarted: Bool
    /// Whole days until the quit begins. Zero once it has.
    let daysUntilStart: Int
    let elapsed: TimeInterval
    let hoursElapsed: Double
    let moneyKept: Decimal
    let monthlyBurn: Decimal
    /// The number that actually lands. People discount a daily cost to nothing
    /// and shrug at a monthly one; the annual figure is the one that reads as
    /// a holiday they didn't take.
    let yearlyBurn: Decimal
    let dailyCost: Decimal
    let unitsAvoided: Int
    let containersAvoided: Int
    /// Cigarettes only — 11 minutes per cigarette, a widely published figure.
    let hoursReclaimed: Int

    init(plan: QuitPlan, now: Date = Date(), calendar: Calendar = .current) {
        let raw = now.timeIntervalSince(plan.quitDate)
        let elapsed = max(0, raw)
        self.hasStarted = raw >= 0

        let startOfNow = calendar.startOfDay(for: now)
        let startOfQuit = calendar.startOfDay(for: plan.quitDate)
        self.daysUntilStart = max(0, calendar.dateComponents(
            [.day], from: startOfNow, to: startOfQuit
        ).day ?? 0)
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
        // Straight from what the user told us they spend. No container size in
        // the money path — see `QuitPlan.weeklySpend`.
        let dailyCost = plan.weeklySpend / 7
        self.dailyCost = dailyCost

        let elapsedDays = elapsed / 86_400
        self.moneyKept = dailyCost * Decimal(elapsedDays)
        self.monthlyBurn = dailyCost * Decimal(30.4)
        self.yearlyBurn = dailyCost * 365

        // Nudge off the floating-point cliff before flooring. 5 pods/week over
        // exactly 7 days is 4.999999… in binary, which would show "4 pods
        // avoided" on the day the fifth one was due.
        let rawUnits = dailyUnits * elapsedDays
        let units = Int(((rawUnits * 1e9).rounded() / 1e9).rounded(.down))
        self.unitsAvoided = units
        // Only ever drawn as tally glyphs on The Bill — "roughly this many
        // packs". `unitsPerContainer` is a rough average and is deliberately
        // kept out of anything numeric the user is asked to trust.
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
