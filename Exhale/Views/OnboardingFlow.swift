import SwiftUI

/// Four steps. Only step 1 is real so far; the rest still stub out.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            switch model.onboardingStep {
            case 0: ProductPickerStep()
            case 1: AmountStep()
            case 2: PriceStep()
            default: QuitMomentStep()
            }

            Spacer(minLength: 0)

            if model.onboardingStep < 3 {
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
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= model.onboardingStep ? Palette.accent
                                                        : Palette.textPrimary.opacity(0.15))
                        .frame(width: 22, height: 4)
                }
            }
            .accessibilityLabel("Step \(model.onboardingStep + 1) of 4")
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
        model.onboardingStep != 0 || model.draft != nil
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
