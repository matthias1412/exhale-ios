import SwiftUI

/// Asks for notification permission where the reason for it is visible.
///
/// It used to fire the system dialog automatically, seconds after the paywall.
/// That is the worst possible moment: the user has just been asked for money,
/// has seen nothing of the app, and a denial is effectively permanent — iOS
/// won't show the prompt twice, and the entire milestone feature depends on it.
///
/// Here it sits at the top of the healing timeline, so the thing being offered
/// is the list directly underneath. No dialog appears until the user has
/// agreed in principle by tapping.
struct NotificationPrimer: View {
    @Environment(AppModel.self) private var model
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Group {
            if status == .notDetermined {
                content
            }
        }
        .task {
            guard !model.clock.isFrozen else { return }
            status = await NotificationScheduler.shared.authorisationStatus()
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Want to know when you hit these?")
                .font(.spaceGrotesk(14, weight: .bold))
            Text("We'll tell you the moment your body passes each one. Nothing else. No daily nagging unless you ask for it.")
                .font(.spaceGrotesk(12.5))
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    _ = await NotificationScheduler.shared.requestAuthorisation()
                    await NotificationScheduler.shared.reschedule(state: model.state)
                    status = await NotificationScheduler.shared.authorisationStatus()
                }
            } label: {
                Text("Tell me")
                    .font(.spaceGrotesk(14, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Palette.accent))
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Palette.accent.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Palette.accent.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.bottom, 16)
    }
}
