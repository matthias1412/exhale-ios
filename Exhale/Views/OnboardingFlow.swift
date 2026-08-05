import SwiftUI

/// Four steps. Only step 1 is real so far; the rest still stub out.
struct OnboardingFlow: View {
    /// Index of the final step. Five steps: product, why, amount, price, moment.
    static let lastStep = 4

    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Group {
                switch model.onboardingStep {
                case 0: ProductPickerStep()
                case 1: ReasonStep()
                case 2: AmountStep()
                case 3: PriceStep()
                default: QuitMomentStep()
                }
            }
            // Steps slide in the direction of travel, so Back feels like going
            // back rather than like another forward step.
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 22)),
                removal: .opacity.combined(with: .offset(x: -22))
            ))
            .animation(.snappy(duration: 0.28), value: model.onboardingStep)

            Spacer(minLength: 0)

            if model.onboardingStep < Self.lastStep {
                footer
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .padding(.bottom, 34)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                LogoMark(size: 26)
                Text("EXHALE")
                    .font(.spaceGrotesk(13, weight: .bold))
                    .tracking(2.86)
                    .foregroundStyle(Palette.accent)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<(Self.lastStep + 1), id: \.self) { i in
                    Capsule()
                        .fill(i <= model.onboardingStep ? Palette.accent
                                                        : Palette.textPrimary.opacity(0.15))
                        .frame(width: 22, height: 4)
                }
            }
            .accessibilityLabel("Step \(model.onboardingStep + 1) of \(Self.lastStep + 1)")
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if model.onboardingStep > 0 {
                Button("Back") { model.onboardingStep -= 1 }
                    .font(.spaceGrotesk(14))
                    .foregroundStyle(Palette.textMuted)
                    .padding(10)
            }
            Button {
                if canContinue { model.onboardingStep += 1 }
            } label: {
                Text("Continue")
                    .font(.spaceGrotesk(16, weight: .bold))
                    .foregroundStyle(canContinue ? Palette.onAccent : Palette.textFaint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule().fill(canContinue ? Palette.accent
                                                   : Palette.textPrimary.opacity(0.12))
                    )
            }
            .disabled(!canContinue)
        }
    }

    private var canContinue: Bool {
        switch model.onboardingStep {
        case 0: model.draft != nil
        case 1: !model.state.reasons.isEmpty
        // The price step was skippable. It stopped being optional the moment
        // the per-country price table went away and the field started blank:
        // tapping through left unitPrice at zero, which makes The Bill a
        // receipt for nothing and the paywall read "Nicotine takes €0.00 from
        // you every year".
        case 3: (model.draft?.unitPrice ?? 0) > 0
        default: true
        }
    }
}

struct ProductPickerStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What are you quitting?")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("No judgement. We just need the shape of the habit.")
                .font(.spaceGrotesk(14))
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            NotAloneNote()
                .padding(.top, 4)

            VStack(spacing: 12) {
                ForEach(NicotineProduct.allCases) { product in
                    ProductRow(
                        product: product,
                        isSelected: model.draft?.product == product
                    ) {
                        model.draft = .starting(product: product)
                    }
                }
            }
            .padding(.top, 12)
        }
        .padding(.top, 34)
    }
}

struct ProductRow: View {
    let product: NicotineProduct
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 16) {
                ProductGlyph(product: product)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.config.displayName)
                        .font(.spaceGrotesk(16, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(product.config.pickerHint)
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                }

                Spacer()

                Circle()
                    .strokeBorder(isSelected ? Palette.accent : Palette.stepperBorder,
                                  lineWidth: 2)
                    .background(Circle().fill(isSelected ? Palette.accent : .clear))
                    .frame(width: 20, height: 20)
            }
            .padding(18)
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
        .accessibilityLabel("\(product.config.displayName), \(product.config.pickerHint)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}


/// Belonging, without inventing anything.
///
/// The obvious move here is "join millions of people who quit with Exhale",
/// and it is a lie — the app has no users, and fabricated social proof is both
/// dishonest and an App Store rejection risk. These two sentences do the same
/// emotional work and are documented facts rather than claims about us.
///
/// The second sentence is doing double duty: normalising multiple attempts up
/// front means the slip screen months later isn't the first time the user
/// hears it, which is exactly when shame does the most damage.
struct NotAloneNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            Text("You're not doing something unusual. Most people who smoke want to stop — and most who manage it needed more than one go.")
                .font(.spaceGrotesk(12.5))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Palette.accent.opacity(0.06))
        )
    }
}
