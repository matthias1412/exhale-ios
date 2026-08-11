import SwiftUI

/// The first screen.
///
/// It used to open with "One dot for every day you don't smoke", explain the
/// money and the milestones, and demonstrate the craving button. All of that
/// was true and none of it was what somebody opening this app needs in the
/// first four seconds. They have just decided to stop, or are deciding, and a
/// feature tour is an answer to a question they have not asked.
///
/// So it opens on where they actually are. The three days are named because
/// they are the honest hard part, and naming them is what makes the rest of
/// the sentence believable: an app that opens by promising this will be easy
/// has already lost the person who tried last year.
///
/// Cravings, slips and what is coming each get their own step further in,
/// which is where the tour material went.
struct IntroStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LogoMark(size: 56)
                .padding(.top, 26)

            Text("Your last one is behind you.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            Text("The first three days are the hard part. After that the nicotine is gone and what's left is habit, and habit is beatable.")
                .font(.spaceGrotesk(15))
                .lineSpacing(4)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Text("Those three days are the ones this is for, and every one after.")
                .font(.spaceGrotesk(15))
                .lineSpacing(4)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }
}
