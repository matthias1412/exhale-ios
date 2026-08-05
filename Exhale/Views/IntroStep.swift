import SwiftUI

/// Onboarding step 1 — what this actually is.
///
/// Feedback from the first device test: "the app is never explained". It went
/// straight to "What are you quitting?", which assumes the user already knows
/// what a spiral of dots is for and why a receipt is involved. Nobody does.
///
/// Deliberately short. Three things, in the order they matter, using the app's
/// own visual language rather than describing it.
struct IntroStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark(size: 56)
                .padding(.top, 26)

            Text("One dot for every day you don't smoke.")
                .font(.spaceGrotesk(28, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Text("They build into a spiral. It gets denser and harder to give up the longer you go — that's rather the point.")
                .font(.spaceGrotesk(14.5))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 18) {
                point("The money adds up",
                      "Every cigarette you don't buy, counted to the penny, live.")
                point("Your body has a schedule",
                      "Twenty minutes to five years, and we'll tell you as each one passes.")
                point("Cravings pass in minutes",
                      "One button, one guided breath, for when it's bad.")
            }
            .padding(.top, 30)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private func point(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.spaceGrotesk(15, weight: .bold))
                Text(detail)
                    .font(.spaceGrotesk(13))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
