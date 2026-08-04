import Foundation

/// The product being quit. This choice cascades through units, questions,
/// copy, tally glyphs and which health milestones apply — see `Milestone`.
enum NicotineProduct: String, Codable, CaseIterable, Identifiable, Sendable {
    case cigarettes
    case vape
    case pouches

    var id: String { rawValue }

    /// Switched rather than looked up in a dictionary, so there is no force
    /// unwrap and the compiler proves every case is covered.
    var config: ProductConfig {
        switch self {
        case .cigarettes: ProductConfig.cigarettes
        case .vape: ProductConfig.vape
        case .pouches: ProductConfig.pouches
        }
    }
}

/// How often the user thinks about their consumption. Vape is the odd one out:
/// people count pods per week, not per day.
enum ConsumptionPeriod: String, Codable, Sendable {
    case day
    case week

    /// Divisor to turn a per-period amount into a per-day amount.
    var daysPerPeriod: Double {
        switch self {
        case .day: 1
        case .week: 7
        }
    }
}

/// Shape of the tally glyph struck through on The Bill.
struct TallyGlyph: Sendable, Equatable {
    let width: Double
    let height: Double
    /// `nil` means a full circle (corner radius = half the height).
    let cornerRadius: Double?
}

struct ProductConfig: Sendable {
    let product: NicotineProduct

    /// "Cigarettes" — used in the picker and the plan summary.
    let displayName: String
    /// "packs, rollies" — the sub-line in the picker.
    let pickerHint: String

    // Onboarding copy
    let amountQuestion: String
    let priceQuestion: String

    // Amount
    let period: ConsumptionPeriod
    let defaultAmount: Int
    let minAmount: Int
    let maxAmount: Int

    /// How many units come in one purchasable container.
    /// Vape is 1 because a pod *is* the container.
    let unitsPerContainer: Int

    /// "cigarettes" / "pods" / "pouches"
    let unitNoun: String
    /// "packs" / "pods" / "tins"
    let containerNoun: String

    /// Completes "≈ €289 a month …" on the price step.
    let burnVerb: String

    let tallyGlyph: TallyGlyph

    /// The default unit price is expressed as a multiplier of the currency's
    /// reference pack price, so we never hardcode cross-currency rates.
    /// See `Currencies.referencePackPrice(for:)`.
    let priceRelativeToPack: Double

    /// "PACKS NOT BOUGHT"
    var tallyLabel: String { "\(containerNoun.uppercased()) NOT BOUGHT" }

    /// "CIGARETTES A DAY"
    var amountUnitLabel: String {
        "\(unitNoun.uppercased()) A \(period == .day ? "DAY" : "WEEK")"
    }

    static let cigarettes = ProductConfig(
            product: .cigarettes,
            displayName: "Cigarettes",
            pickerHint: "packs, rollies",
            amountQuestion: "Cigarettes on a normal day?",
            priceQuestion: "Price of a pack?",
            period: .day,
            defaultAmount: 15,
            minAmount: 1,
            maxAmount: 60,
            unitsPerContainer: 20,
            unitNoun: "cigarettes",
            containerNoun: "packs",
            burnVerb: "going up in smoke",
            tallyGlyph: TallyGlyph(width: 15, height: 21, cornerRadius: 2),
            priceRelativeToPack: 1.0
    )

    static let vape = ProductConfig(
            product: .vape,
            displayName: "Vape",
            pickerHint: "pods, disposables",
            amountQuestion: "Pods in a normal week?",
            priceQuestion: "Price of one pod?",
            period: .week,
            defaultAmount: 5,
            minAmount: 1,
            maxAmount: 28,
            unitsPerContainer: 1,
            unitNoun: "pods",
            containerNoun: "pods",
            burnVerb: "vanishing into vapour",
            tallyGlyph: TallyGlyph(width: 9, height: 22, cornerRadius: 5),
            // €6.00 against a €9.50 reference pack
            priceRelativeToPack: 6.0 / 9.5
    )

    static let pouches = ProductConfig(
            product: .pouches,
            displayName: "Nicotine pouches",
            pickerHint: "snus, pouches",
            amountQuestion: "Pouches on a normal day?",
            priceQuestion: "Price of a tin?",
            period: .day,
            defaultAmount: 8,
            minAmount: 1,
            maxAmount: 40,
            unitsPerContainer: 20,
            unitNoun: "pouches",
            containerNoun: "tins",
            burnVerb: "disappearing under your lip",
            tallyGlyph: TallyGlyph(width: 18, height: 18, cornerRadius: nil),
            // €5.50 against a €9.50 reference pack
            priceRelativeToPack: 5.5 / 9.5
    )
}
