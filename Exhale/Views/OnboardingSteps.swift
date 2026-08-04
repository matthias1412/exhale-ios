import SwiftUI

// MARK: - Step 2 — amount

struct AmountStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let draft = model.draft {
            let config = draft.config
            VStack(alignment: .leading, spacing: 14) {
                Text(config.amountQuestion)
                    .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your honest average. Rough is fine.")
                    .font(.spaceGrotesk(14))
                    .foregroundStyle(Palette.textMuted)

                HStack(spacing: 26) {
                    StepperCircle(symbol: "minus", enabled: draft.amount > config.minAmount) {
                        model.draft?.amount = max(config.minAmount, draft.amount - 1)
                    }

                    VStack(spacing: 6) {
                        Text("\(draft.amount)")
                            .font(.spaceGrotesk(64, weight: .bold, relativeTo: .largeTitle))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(config.amountUnitLabel)
                            .font(.spaceGrotesk(12))
                            .tracking(0.96)
                            .foregroundStyle(Palette.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 130)

                    StepperCircle(symbol: "plus", enabled: draft.amount < config.maxAmount) {
                        model.draft?.amount = min(config.maxAmount, draft.amount + 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(config.amountQuestion)
                .accessibilityValue("\(draft.amount) \(config.amountUnitLabel.lowercased())")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.draft?.amount = min(config.maxAmount, draft.amount + 1)
                    case .decrement: model.draft?.amount = max(config.minAmount, draft.amount - 1)
                    @unknown default: break
                    }
                }
            }
            .padding(.top, 34)
        }
    }
}

// MARK: - Step 3 — price

struct PriceStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let draft = model.draft {
            let config = draft.config
            let step = Currencies.priceStep(for: draft.currencyCode)
            let progress = QuitProgress(plan: draft, now: model.clock.now)

            VStack(alignment: .leading, spacing: 14) {
                Text(config.priceQuestion)
                    .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                    .fixedSize(horizontal: false, vertical: true)

                CurrencyChips(selected: draft.currencyCode) { code in
                    model.draft?.currencyCode = code
                    // Re-seed the price: a number that made sense in euros is
                    // meaningless in yen.
                    model.draft?.unitPrice = Currencies.defaultPrice(
                        for: draft.product, currency: code
                    )
                }
                .padding(.top, 4)

                HStack(spacing: 26) {
                    StepperCircle(symbol: "minus", enabled: draft.unitPrice > step) {
                        model.draft?.unitPrice = max(step, draft.unitPrice - step)
                    }

                    Text(draft.unitPrice.currencyString(draft.currencyCode))
                        .font(.spaceGrotesk(38, weight: .bold, relativeTo: .title))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(width: 190)

                    StepperCircle(symbol: "plus", enabled: true) {
                        model.draft?.unitPrice = draft.unitPrice + step
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)

                BurnReadout(progress: progress, plan: draft, verb: config.burnVerb)
                    .padding(.top, 20)
            }
            .padding(.top, 34)
        }
    }
}

struct CurrencyChips: View {
    let selected: String
    let pick: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 7) {
            ForEach(Currencies.chips(includingSelected: selected), id: \.self) { code in
                let isOn = code == selected
                Button { pick(code) } label: {
                    Text(code)
                        .font(.spaceGrotesk(12, weight: .bold))
                        .tracking(0.48)
                        .foregroundStyle(isOn ? Palette.accentSoft : Palette.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isOn ? Palette.accent.opacity(0.12) : .clear)
                                .overlay(
                                    Capsule().stroke(
                                        isOn ? Palette.accent : Palette.textPrimary.opacity(0.2),
                                        lineWidth: 1.5
                                    )
                                )
                        )
                }
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
    }
}

// MARK: - Step 4 — the quit moment

/// The prototype had two buttons that did the same thing and recorded nothing.
/// Three real paths instead — backdating matters, because someone already forty
/// days in should not be told to start again at one.
struct QuitMomentStep: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .none
    @State private var chosen = Date()

    enum Mode { case none, earlierToday, pickDate }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("When was your last one?")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)

            Text("Day 1 starts the moment you tap.")
                .font(.spaceGrotesk(14))
                .foregroundStyle(Palette.textMuted)

            VStack(spacing: 12) {
                PillButton("Just had it — start now", style: .accent) {
                    finish(with: model.clock.now)
                }

                PillButton("Earlier today", style: .outline) {
                    chosen = model.clock.now
                    mode = .earlierToday
                }

                PillButton("I quit before today", style: .quiet) {
                    chosen = Calendar.current.date(
                        byAdding: .day, value: -7, to: model.clock.now
                    ) ?? model.clock.now
                    mode = .pickDate
                }
            }
            .padding(.top, 30)

            if mode != .none {
                VStack(spacing: 12) {
                    DatePicker(
                        "When?",
                        selection: $chosen,
                        in: range,
                        displayedComponents: mode == .earlierToday
                            ? [.hourAndMinute] : [.date]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)

                    PillButton("That's my quit moment", style: .accent) {
                        finish(with: chosen)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .padding(.top, 34)
        .animation(.snappy(duration: 0.2), value: mode)
    }

    /// Never let someone pick the future — a quit date ahead of now would make
    /// every derived number negative.
    private var range: ClosedRange<Date> {
        let now = model.clock.now
        let earliest = mode == .earlierToday
            ? Calendar.current.startOfDay(for: now)
            : (Calendar.current.date(byAdding: .year, value: -20, to: now) ?? now)
        return earliest...now
    }

    private func finish(with date: Date) {
        model.draft?.quitDate = min(date, model.clock.now)
        if let draft = model.draft {
            model.state.plan = draft
            model.state.phase = .paywall
        }
    }
}

// MARK: - Shared controls

struct StepperCircle: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(enabled ? Palette.accent : Palette.textPrimary.opacity(0.25))
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(Palette.stepperBorder, lineWidth: 1.5))
        }
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}

struct PillButton: View {
    enum Style { case accent, outline, quiet }

    let title: String
    let style: Style
    let action: () -> Void

    init(_ title: String, style: Style, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.spaceGrotesk(style == .accent ? 17 : 16,
                                    weight: style == .accent ? .bold : .medium))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: style == .quiet ? 52 : 60)
                .background(background)
        }
    }

    private var foreground: Color {
        switch style {
        case .accent: Palette.onAccent
        case .outline: Palette.textPrimary.opacity(0.85)
        case .quiet: Palette.textMuted
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .accent: Capsule().fill(Palette.accent)
        case .outline: Capsule().stroke(Palette.stepperBorder, lineWidth: 1.5)
        case .quiet: Capsule().stroke(Palette.textPrimary.opacity(0.12), lineWidth: 1)
        }
    }
}


/// What the habit costs, framed as a loss rather than a potential saving.
///
/// The annual figure carries the weight: a daily cost gets discounted to
/// nothing and a monthly one gets shrugged at, but the year total reads as a
/// holiday that didn't happen. Losses also loom larger than equivalent gains,
/// so the copy says what nicotine *takes*, not what the user could save.
///
/// Every number here is derived from what the user just typed, in the currency
/// they chose. Nothing is invented, and nothing is converted.
struct BurnReadout: View {
    let progress: QuitProgress
    let plan: QuitPlan
    let verb: String

    var body: some View {
        VStack(spacing: 6) {
            Text("≈ \(progress.monthlyBurn.moneyString(plan.currencyCode)) a month \(verb)")
                .font(.spaceGrotesk(13))
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)

            Text(progress.yearlyBurn.moneyString(plan.currencyCode))
                .font(.spaceGrotesk(36, weight: .bold, relativeTo: .title))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(Palette.emberSoft)

            Text("a year, gone")
                .font(.spaceGrotesk(13))
                .foregroundStyle(Palette.textMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "About \(progress.monthlyBurn.moneyString(plan.currencyCode)) a month, "
            + "\(progress.yearlyBurn.moneyString(plan.currencyCode)) a year"
        )
    }
}
