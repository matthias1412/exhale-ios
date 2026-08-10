import SwiftUI

/// Onboarding step 1 — what this actually is.
///
/// Feedback from the first device test: "the app is never explained". It went
/// straight to "What are you quitting?", which assumes the user already knows
/// what a spiral of dots is for and why a receipt is involved. Nobody does.
///
/// The craving button gets shown rather than described. It is the one control
/// in the app that has to be found in a hurry, by someone who is not in a
/// state to go looking — so it is introduced here, in the shape and colour it
/// will have on Today, before it is ever needed.
struct IntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark(size: 56)
                .padding(.top, 26)

            Text("One dot for every day you don't smoke.")
                .font(.spaceGrotesk(28, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Text("It gets denser the longer you go.")
                .font(.spaceGrotesk(14.5))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 18) {
                point("The money adds up",
                      "Counted to the penny, ticking up while you watch.")
                point("Your body keeps a schedule",
                      "Twenty minutes to twenty years. You'll hear about each one.")
            }
            .padding(.top, 30)

            // Shown, not described.
            VStack(alignment: .leading, spacing: 10) {
                Text("And when it's bad, this is on every screen:")
                    .font(.spaceGrotesk(14))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text("I'm craving, help me through it")
                    .font(.spaceGrotesk(16, weight: .medium))
                    .foregroundStyle(Palette.emberSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(Palette.ember.opacity(0.12))
                            .overlay(Capsule().stroke(Palette.ember.opacity(0.65), lineWidth: 1.5))
                    )

                Text("It starts a timer and a breath. Most cravings are over in three minutes.")
                    .font(.spaceGrotesk(13))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 30)
            // Decorative here — the real one is on Today. Announced as a
            // description so VoiceOver doesn't offer a button that isn't one.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "On every screen there is a button reading, I'm craving, help me through it. "
                + "It starts a timer and a breathing exercise. Most cravings are over in three minutes."
            )

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
