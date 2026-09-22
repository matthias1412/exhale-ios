import SwiftUI

struct PaywallScreen: View {
    @Environment(AppModel.self) private var model
    @State private var selected: SubscriptionOffer.Term = .yearly
    @State private var working = false

    /// Set once the store has had long enough. See `shown`.
    @State private var storeTookTooLong = false

    /// Deliberately generous. This exists only so the screen can never become
    /// a permanent dead end - it is not a shortcut past the paywall, and the
    /// cost of it firing early is someone being told the store is unreachable
    /// while the store is in fact about to answer.
    ///
    /// The first guess here was twelve seconds, on the reasoning that anything
    /// slower than that is broken. On a real device the offers took twenty:
    /// RevenueCat retries the StoreKit product fetch, and a cold fetch on a
    /// product that has only just become purchasable is not quick. Twelve
    /// would have called it a failure eight seconds before the prices arrived,
    /// and handed the app away free to anyone who tapped Continue in between.
    private let storeDeadline = 35.0

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

            #if DEBUG_TOOLS
            // Not in App Store builds. Three rounds of reasoning about the
            // slow paywall were wrong, so this shows the measurements.
            if let timings = model.subscriptions.timings {
                Text(timings.summary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.accentSoft)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Palette.textPrimary.opacity(0.06)))
                    .padding(.bottom, 8)
            }
            #endif

            actions
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 32)
        .task { await model.subscriptions.load() }
        // The screen must never become a dead end.
        //
        // `.loading` draws two grey placeholders and disables the button, and
        // there is deliberately no "Maybe later" any more — so a store call
        // that never returns used to leave someone staring at two empty boxes
        // with nothing on screen that does anything, forever, with the app
        // they just set up on the other side of it. A hang is not a decision
        // not to sell, but after long enough it has to be treated as one.
        .task {
            try? await Task.sleep(for: .seconds(storeDeadline))
            storeTookTooLong = true
        }
    }

    /// What the screen shows, which is not always what the gate says: a load
    /// that has outlived its deadline is shown as a store we could not reach,
    /// because that is the honest description and, unlike `.loading`, it is a
    /// state the screen has a way out of.
    private var shown: SubscriptionState {
        if case .loading = model.subscriptions.state, storeTookTooLong {
            return .unavailable("We couldn't reach the App Store. Carry on for now and we'll try again later.")
        }
        return model.subscriptions.state
    }

    @ViewBuilder
    private func offers(plan: QuitPlan) -> some View {
        switch shown {
        case .loading:
            // A placeholder, never a guessed price.
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Palette.textPrimary.opacity(0.06))
                        .frame(height: 68)
                }
                // Twenty seconds of two grey boxes reads as a broken screen.
                // Saying who we are waiting for turns the same wait into
                // something that is visibly still happening.
                Text("Checking prices with the App Store...")
                    .font(.spaceGrotesk(12))
                    .foregroundStyle(Palette.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.top, 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Checking prices with the App Store")

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
                guard case .ready(let list) = shown,
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
        if case .loading = shown { return true }
        return false
    }

    /// Reached from inside the app rather than from onboarding, which means
    /// a subscription that has lapsed rather than one never started.
    private var returning: Bool { model.state.phase == .app }

    private var yearlyOffer: SubscriptionOffer? {
        guard case .ready(let list) = shown else { return nil }
        return list.first { $0.term == .yearly }
    }

    private var primaryTitle: String {
        if case .ready(let list) = shown,
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
