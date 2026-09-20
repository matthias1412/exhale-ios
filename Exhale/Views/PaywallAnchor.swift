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
            if let immediacy { immediacy }
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

    // MARK: - Something that happens soon

    /// `nil` once every mark on the timeline is behind them — at twenty years
    /// there is no next one, and inventing one would be worse than silence.
    ///
    /// This used to hardcode the *first* milestone and describe it as "away",
    /// which is only true on day one. The paywall is also reached by someone
    /// whose subscription lapsed ninety days in, and it told them their heart
    /// rate would settle in twenty minutes — a promise their body kept three
    /// months ago. Past day one the next mark is named by its date instead,
    /// because "6 months away" is the distance from the quit date, not from
    /// today, and the difference is the entire streak.
    private var immediacy: AnyView? {
        guard let next = MilestoneImmediacy(
            product: plan.product,
            hoursElapsed: progress.hoursElapsed,
            quitDate: plan.quitDate
        ) else { return nil }
        let lede = next.lede
        let value = next.value

        return AnyView(
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(Palette.accent).frame(width: 6, height: 6).padding(.top, 6)
                Text(lede)
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
                + Text(value)
                    .font(.spaceGrotesk(13.5, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                + Text(": \(next.title).")
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
            }
        )
    }
}

/// The "something happens soon" line, kept out of the view so it can be
/// tested — the same reason `ReadySummary` lives outside its screen.
///
/// It has to be true from three very different places on the timeline: the
/// minute someone stops, a few hours in, and ninety days in when a lapsed
/// subscription puts the paywall back up. The version this replaced was only
/// true from the first of those, and said so to all three.
struct MilestoneImmediacy: Equatable {
    let lede: String
    let value: String
    /// Already lowercased for the sentence it sits in.
    let title: String

    /// `nil` once every mark on the timeline is behind them. At twenty years
    /// there is no next one, and inventing one would be worse than silence.
    init?(product: NicotineProduct, hoursElapsed: Double, quitDate: Date) {
        guard let next = Milestones.upcoming(
            for: product, hoursElapsed: hoursElapsed, limit: 1).first
        else { return nil }

        // "First" only while none have been passed. Someone ninety days in
        // has a next one, not a first one.
        let isFirst = Milestones.forProduct(product).first == next
        lede = isFirst ? "Your first milestone is " : "Your next milestone is "
        title = next.title.lowercased()

        // How far away it is *from now*, which is not what `Milestone.when`
        // says: that is the distance from the quit date, and the two stop
        // agreeing the moment anyone backdates or comes back later. Anything
        // inside a day is said as a duration, because naming a date for
        // something happening this evening reads as further off than it is.
        //
        // Computed rather than handed to a relative date formatter, which
        // measures from the real clock and would print nonsense under the
        // frozen one the captures run on.
        let hoursAway = next.hours - hoursElapsed
        if hoursAway < 1 {
            let minutes = max(1, Int((hoursAway * 60).rounded()))
            value = "\(minutes) min away"
        } else if hoursAway < 24 {
            let hours = max(1, Int(hoursAway.rounded()))
            value = "\(hours) \(hours == 1 ? "hour" : "hours") away"
        } else {
            value = next.date(from: quitDate).formatted(.dateTime.day().month(.wide))
        }
    }
}
