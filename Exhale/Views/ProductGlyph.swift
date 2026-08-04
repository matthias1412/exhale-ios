import SwiftUI

/// Marks for the three products, used **only** on onboarding step 1.
///
/// Deliberately geometric rather than illustrative. Smoking-related imagery is
/// a craving cue — cue reactivity is one of the better-established findings in
/// the cessation literature — so a quit app showing a convincing cigarette is
/// working against itself.
///
/// The job here is disambiguation, once: three shapes distinct enough to pick
/// between, abstract enough not to read as the thing itself. After this screen
/// the app never depicts the product again. Resist any drift toward realism.
struct ProductGlyph: View {
    let product: NicotineProduct
    var size: CGFloat = 36

    var body: some View {
        Group {
            switch product {
            case .cigarettes: cigarette
            case .vape: pod
            case .pouches: tin
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)      // the row's own label says the name
    }

    /// Two bars: a short ember-tipped one, a longer pale one.
    private var cigarette: some View {
        HStack(spacing: 0) {
            UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 2,
                bottomTrailingRadius: 0, topTrailingRadius: 0
            )
            .fill(Palette.ember)
            .frame(width: size * 0.22, height: size * 0.25)

            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 3, topTrailingRadius: 3
            )
            .fill(Palette.textPrimary)
            .frame(width: size * 0.67, height: size * 0.25)
        }
    }

    /// An upright capsule with a sea-glass base.
    private var pod: some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(Palette.textPrimary)
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 7,
                bottomTrailingRadius: 7, topTrailingRadius: 0
            )
            .fill(Palette.accent)
            .frame(height: size * 0.28)
        }
        .frame(width: size * 0.36, height: size * 0.89)
    }

    /// A ring with a lozenge inside — a tin seen from above.
    private var tin: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.textPrimary, lineWidth: size * 0.083)
            Capsule()
                .fill(Palette.accent)
                .frame(width: size * 0.28, height: size * 0.17)
        }
        .frame(width: size * 0.78, height: size * 0.78)
    }
}

#Preview {
    HStack(spacing: 28) {
        ForEach(NicotineProduct.allCases) { ProductGlyph(product: $0, size: 44) }
    }
    .padding(40)
    .background(Palette.background)
}
