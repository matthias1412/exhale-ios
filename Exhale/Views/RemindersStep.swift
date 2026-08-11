import SwiftUI

/// The last onboarding step: permission, asked where it means something.
///
/// It sits immediately after the date is chosen and before the paywall, which
/// is the one moment in the whole flow where the user has just committed to
/// something and has not yet been asked for money. A denial is close to
/// permanent, since iOS will not show the system dialog twice, so the ask gets
/// the best moment available rather than a convenient one.
///
/// The closing line names a real day, and which day depends on where they
/// are: see ReminderHorizon.
///
/// The screen argues for the user's goal instead of listing what arrives.
/// Naming the payload ("milestone alerts, a weekly summary") turns a decision
/// about whether they will still be quit in a fortnight into a decision about
/// inbox volume, and the second question has an obvious cheap answer.
///
/// Nothing is committed here either. The plan is held in the draft
/// until then, because `onboardingStep` and `draft` are not persisted while
/// `phase` is: writing the plan here and leaving the phase behind would mean a
/// relaunch mid-step restarted onboarding on top of a saved plan.
struct RemindersStep: View {
    @Environment(AppModel.self) private var model
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Deciding is the easy part.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Everyone who has ever quit had a moment like this one: clear, sure, done deliberating. What separates the ones who keep it is having something on their side on the days they don't feel like this.")
                .font(.spaceGrotesk(14))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Text(ReminderHorizon.line(
                quitDate: model.draft?.quitDate ?? model.clock.now,
                now: model.clock.now
            ))
                .font(.spaceGrotesk(16, weight: .bold))
                .foregroundStyle(Palette.textBrightest)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 0)

            PillButton("Turn on reminders", style: .accent) { grant() }
                .disabled(asking)

            Button("Not now") { model.onboardingStep += 1 }
                .font(.spaceGrotesk(13.5))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
        .padding(.top, 34)
    }

    private func grant() {
        // Frozen clock means a seeded screenshot run. Touching the real
        // notification centre there would put a system dialog over the capture.
        guard !model.clock.isFrozen else {
            model.onboardingStep += 1
            return
        }
        asking = true
        Task {
            _ = await NotificationScheduler.shared.requestAuthorisation()
            // Scheduling happens on the ready screen, once the plan is saved.
            model.onboardingStep += 1
        }
    }
}
