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

            Text("Your quit plan is ready.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

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
        VStack(spacing: 12) {
            PillButton(primaryTitle, style: .accent) {
                guard case .ready(let list) = model.subscriptions.state,
                      let offer = list.first(where: { $0.term == selected }) else {
                    model.state.phase = .app
                    return
                }
                working = true
                Task {
                    _ = await model.subscriptions.purchase(offer)
                    working = false
                    model.state.phase = .app
                }
            }
            .disabled(working)

            Button("Maybe later") { model.state.phase = .app }
                .font(.spaceGrotesk(13))
                .foregroundStyle(Palette.textFaint)

            Button("Restore purchases") {
                Task { _ = await model.subscriptions.restore() }
            }
            .font(.spaceGrotesk(12))
            .foregroundStyle(Palette.textFaint.opacity(0.7))
        }
    }

    private var yearlyOffer: SubscriptionOffer? {
        guard case .ready(let list) = model.subscriptions.state else { return nil }
        return list.first { $0.term == .yearly }
    }

    private var primaryTitle: String {
        if case .ready(let list) = model.subscriptions.state,
           let offer = list.first(where: { $0.term == selected }),
           offer.hasFreeTrial {
            return "Start my free week"
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
