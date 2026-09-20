import SwiftUI

struct PaywallScreen: View {
    @Environment(AppModel.self) private var model
    @State private var selected: SubscriptionOffer.Term = .yearly
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                LogoMark(size: 26)
                Text("EXHALE")
                    .font(.spaceGrotesk(13, weight: .bold))
                    .tracking(2.86)
                    .foregroundStyle(Palette.accent)
            }
            .padding(.top, 8)

            Text(returning ? "Your subscription has ended." : "Your quit plan is ready.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            // Someone who has been counting for months and hits this screen
            // needs to know, in the first second, that their streak has not
            // been taken away. It is on their device; nothing was lost.
            if returning {
                Text("Your streak is safe. Pick up where you left off.")
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            if let plan = model.plan, let progress = model.progress {
                PaywallAnchor(
                    progress: progress,
                    plan: plan,
                    offer: yearlyOffer,
                    now: model.clock.now
                )
                .padding(.top, 20)

                offers(plan: plan)
            }

            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 32)
        .task { await model.subscriptions.load() }
    }

    @ViewBuilder
    private func offers(plan: QuitPlan) -> some View {
        switch model.subscriptions.state {
        case .loading:
            // A placeholder, never a guessed price.
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Palette.textPrimary.opacity(0.06))
                        .frame(height: 68)
                }
            }
            .padding(.top, 22)
            .accessibilityLabel("Loading prices")

        case .ready(let list):
            VStack(spacing: 10) {
                ForEach(list) { offer in
                    OfferRow(offer: offer, isSelected: selected == offer.term) {
                        selected = offer.term
                    }
                }
            }
            .padding(.top, 22)

        case .unavailable(let reason):
            Text(reason)
                .font(.spaceGrotesk(13))
                .foregroundStyle(Palette.textMuted)
                .padding(.top, 22)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            PillButton(primaryTitle, style: .accent) {
                guard case .ready(let list) = model.subscriptions.state,
                      let offer = list.first(where: { $0.term == selected }) else {
                    // Nothing to sell, so nothing to stand in the way. This is
                    // the same judgement as `isLocked`: no offer, no wall.
                    model.state.phase = .app
                    return
                }
                working = true
                Task {
                    let bought = await model.subscriptions.purchase(offer)
                    working = false
                    // Only a completed purchase opens the app. This used to
                    // fall through on failure *and* on cancellation, which
                    // meant tapping the button and then declining Apple's
                    // sheet was a working way to get the whole app for free.
                    if bought { model.state.phase = .app }
                }
            }
            .disabled(working || isLoadingPrices)

            Button("Restore purchases") {
                Task {
                    if await model.subscriptions.restore() { model.state.phase = .app }
                }
            }
            .font(.spaceGrotesk(12.5))
            .foregroundStyle(Palette.textMuted)
            .padding(.top, 2)

            legal.padding(.top, 4)
        }
    }

    /// Required in the binary by guideline 3.1.2, and fair to say regardless:
    /// nobody should have to go looking for what happens after the free week.
    private var legal: some View {
        VStack(spacing: 5) {
            Text(Legal.renewalTerms)
                .font(.spaceGrotesk(10.5))
                .foregroundStyle(Palette.textFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: Legal.terms)
                Text("·")
                Link("Privacy Policy", destination: Legal.privacy)
            }
            .font(.spaceGrotesk(10.5, weight: .medium))
            .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    /// True only while the store has not answered. An `.unavailable` store is
    /// not loading — it is finished, and the button has somewhere to go.
    private var isLoadingPrices: Bool {
        if case .loading = model.subscriptions.state { return true }
        return false
    }

    /// Reached from inside the app rather than from onboarding, which means
    /// a subscription that has lapsed rather than one never started.
    private var returning: Bool { model.state.phase == .app }

    private var yearlyOffer: SubscriptionOffer? {
        guard case .ready(let list) = model.subscriptions.state else { return nil }
        return list.first { $0.term == .yearly }
    }

    private var primaryTitle: String {
        if case .ready(let list) = model.subscriptions.state,
           let offer = list.first(where: { $0.term == selected }) {
            // Never offered to someone who has already had it.
            if offer.hasFreeTrial { return "Start my free week" }
            return returning ? "Start it up again" : "Continue"
        }
        return "Continue"
    }
}

struct OfferRow: View {
    let offer: SubscriptionOffer
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.term == .yearly ? "Yearly" : "Monthly")
                        .font(.spaceGrotesk(15, weight: .bold))
                    if let perMonth = offer.localisedPricePerMonth {
                        Text("\(perMonth) / month")
                            .font(.spaceGrotesk(12))
                            .foregroundStyle(Palette.textMuted)
                    }
                }

                Spacer()

                Text(offer.localisedPrice)
                    .font(.spaceGrotesk(17, weight: .bold))

                if offer.hasFreeTrial {
                    Text("\(offer.trialDays) DAYS FREE")
                        .font(.spaceGrotesk(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.accent))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Palette.accent.opacity(0.10) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? Palette.accent : Palette.cardBorder,
                                    lineWidth: 1.5)
                    )
            )
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
