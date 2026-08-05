import SwiftUI

/// What Today shows when the quit date is still ahead.
///
/// There is no spiral yet — drawing one would be a lie, and a fake day 1 is
/// exactly the kind of thing that makes an app feel cheap. So the screen shows
/// the one honest thing there is: how long until it starts, and what the first
/// hours will do.
///
/// The countdown is doing real work. A committed future date with a visible
/// clock against it is an implementation intention — deciding *when* in advance
/// is one of the better-evidenced predictors of actually following through.
struct PreQuitView: View {
    @Environment(AppModel.self) private var model
    let progress: QuitProgress

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            LogoMark(size: 44)
                .opacity(0.35)
                .padding(.bottom, 26)

            Text(progress.daysUntilStart == 0 ? "STARTS TODAY" : "STARTS IN")
                .font(.spaceGrotesk(11, weight: .medium))
                .tracking(1.98)
                .foregroundStyle(Palette.textMuted)

            if progress.daysUntilStart > 0 {
                Text("\(progress.daysUntilStart)")
                    .font(.spaceGrotesk(72, weight: .bold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textBrightest)
                Text(progress.daysUntilStart == 1 ? "day" : "days")
                    .font(.spaceGrotesk(15))
                    .foregroundStyle(Palette.textMuted)
            }

            if let plan = model.plan {
                Text(plan.quitDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.spaceGrotesk(14, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .padding(.top, progress.daysUntilStart > 0 ? 10 : 6)

                // Something concrete waiting on the other side.
                if let first = Milestones.forProduct(plan.product).first {
                    Text("\(first.when) after that, \(first.title.lowercased()).")
                        .font(.spaceGrotesk(13.5))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textMuted)
                        .padding(.top, 22)
                        .padding(.horizontal, 40)
                }
            }

            Spacer(minLength: 0)

            // Changing your mind toward "sooner" should always be one tap.
            Button("Actually, I've already stopped") {
                model.state.plan?.quitDate = model.clock.now
            }
            .font(.spaceGrotesk(13.5, weight: .medium))
            .foregroundStyle(Palette.accent)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// "One more day until…" on the Today screen.
///
/// The goal-gradient effect: effort rises sharply as a goal comes into reach.
/// Being told the nicotine is out of your system tomorrow is a materially
/// better reason not to smoke tonight than a generic streak count.
struct ImminentMilestoneNote: View {
    let milestone: Milestone
    let hoursAway: Double

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(milestone.colour)
                .frame(width: 6, height: 6)
            Text("\(timing) — \(milestone.title.lowercased())")
                .font(.spaceGrotesk(12))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(milestone.colour.opacity(0.10))
                .overlay(Capsule().stroke(milestone.colour.opacity(0.25), lineWidth: 1))
        )
        .accessibilityLabel("Coming up \(timing): \(milestone.title)")
    }

    private var timing: String {
        if hoursAway <= 1 { return "Within the hour" }
        if hoursAway < 12 { return "In \(Int(hoursAway.rounded())) hours" }
        return "Tomorrow"
    }
}
