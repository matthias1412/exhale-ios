import SwiftUI

/// The paywall's persuasion, kept honest.
///
/// What it leans on, and why:
///
/// - **Loss framing.** "Nicotine takes X a year from you", not "you could save
///   X". Losses weigh roughly twice what equivalent gains do, and the money is
///   already leaving their pocket — describing it as a loss is also just true.
/// - **Aggregation.** A daily cost is discounted to nothing. The annual figure
///   is the one that reads as a holiday that didn't happen.
/// - **A dated projection.** "By 5 August 2027 you'll have kept X" is concrete,
///   personalised and in their currency, which beats an abstract promise.
/// - **Relative anchoring.** The subscription next to the habit's annual cost
///   makes the price self-evidently small, without ever calling it cheap.
/// - **Immediacy.** The first milestone is twenty minutes away. A reward you
///   can reach tonight beats one a year out.
///
/// What it deliberately does *not* do: no countdown timers, no fake scarcity,
/// no hidden dismiss, no shame, and no invented numbers — every figure is
/// derived from what the user typed. That's a design position, and it also
/// keeps the paywall on the right side of App Store review.
struct PaywallAnchor: View {
    let progress: QuitProgress
    let plan: QuitPlan
    let offer: SubscriptionOffer?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            yearlyLoss
            projection
            if let comparison { comparison }
            immediacy
        }
    }

    // MARK: - The annual figure

    private var yearlyLoss: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NICOTINE TAKES")
                .font(.spaceGrotesk(11, weight: .medium))
                .tracking(1.98)
                .foregroundStyle(Palette.textFaint)

            Text(progress.yearlyBurn.moneyString(plan.currencyCode))
                .font(.spaceGrotesk(40, weight: .bold, relativeTo: .largeTitle))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(Palette.emberSoft)

            Text("from you every year")
                .font(.spaceGrotesk(13))
                .foregroundStyle(Palette.textMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Nicotine takes \(progress.yearlyBurn.moneyString(plan.currencyCode)) from you every year"
        )
    }

    // MARK: - A dated, personalised projection

    private var projection: some View {
        let oneYearOn = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
        let date = oneYearOn.formatted(.dateTime.day().month(.wide).year())
        return HStack(alignment: .top, spacing: 10) {
            Circle().fill(Palette.accent).frame(width: 6, height: 6).padding(.top, 6)
            Text("Stay with it and by ")
                .font(.spaceGrotesk(13.5))
                .foregroundStyle(Palette.textMuted)
            + Text(date)
                .font(.spaceGrotesk(13.5, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            + Text(" you'll have kept ")
                .font(.spaceGrotesk(13.5))
                .foregroundStyle(Palette.textMuted)
            + Text(progress.yearlyBurn.moneyString(plan.currencyCode))
                .font(.spaceGrotesk(13.5, weight: .bold))
                .foregroundStyle(Palette.accent)
            + Text(".")
                .font(.spaceGrotesk(13.5))
                .foregroundStyle(Palette.textMuted)
        }
    }

    // MARK: - Relative cost, only when the currencies agree

    /// `nil` when the store charged in a different currency from the one the
    /// user priced their habit in. A UK App Store account with a habit priced
    /// in euros would otherwise be shown a ratio between two unrelated numbers.
    private var comparison: AnyView? {
        guard let offer,
              offer.currencyCode.caseInsensitiveCompare(plan.currencyCode) == .orderedSame,
              progress.dailyCost > 0
        else { return nil }

        let days = progress.paybackDays(yearlyPrice: offer.amount)
        return AnyView(
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Palette.accent).frame(width: 6, height: 6).padding(.top, 6)
                Text("Exhale costs ")
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
                + Text(offer.localisedPrice)
                    .font(.spaceGrotesk(13.5, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                + Text(" a year. It pays for itself in ")
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
                + Text("\(days) \(days == 1 ? "day" : "days")")
                    .font(.spaceGrotesk(13.5, weight: .bold))
                    .foregroundStyle(Palette.accent)
                + Text(" of not buying.")
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
            }
        )
    }

    // MARK: - Something that happens tonight

    private var immediacy: some View {
        let first = Milestones.forProduct(plan.product).first
        return HStack(alignment: .top, spacing: 10) {
            Circle().fill(Palette.accent).frame(width: 6, height: 6).padding(.top, 6)
            Text("Your first milestone is ")
                .font(.spaceGrotesk(13.5))
                .foregroundStyle(Palette.textMuted)
            + Text(first?.when ?? "20 min")
                .font(.spaceGrotesk(13.5, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            + Text(" away: \((first?.title ?? "your heart rate settles").lowercased()).")
                .font(.spaceGrotesk(13.5))
                .foregroundStyle(Palette.textMuted)
        }
    }
}
