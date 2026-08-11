import SwiftUI

/// Onboarding steps by name rather than by number.
///
/// Seeds addressed steps as raw integers, which was survivable while the order
/// never changed. It stopped being survivable the moment three screens were
/// inserted in the middle: "onboard-reason" would have quietly rendered the
/// amount step, captured a screenshot of the wrong screen, and passed every
/// linter in the repo, because a number is still a valid number after the
/// thing it pointed at moves.
enum OnboardingStep: Int, CaseIterable {
    case welcome, product, amount, spend, why, cravings, slips, dayOne, reminders, ready

    /// Steps that draw their own continue button and so suppress the shared
    /// footer. Everything up to and including slips uses the footer.
    var providesOwnFooter: Bool { rawValue >= Self.dayOne.rawValue }
}

/// What a craving actually is, before they meet their first one.
///
/// The button exists on every screen, and someone who has not been told what
/// it is for will read it as an emergency cord and never pull it. Naming the
/// three minutes up front turns it into a timer they are waiting out rather
/// than an admission that they are losing.
struct CravingsStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A craving lasts about three minutes.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("It arrives, it peaks, and it goes, whether you smoke or not. That's not willpower talking, it's just how they work. The trick is having somewhere to put those three minutes.")
                .font(.spaceGrotesk(14))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            // Shown rather than described. It is the real control, at the real
            // size, so it is already familiar when it matters.
            Text("I'm craving, help me through it")
                .font(.spaceGrotesk(16, weight: .bold))
                .foregroundStyle(Palette.ember)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Palette.ember.opacity(0.10))
                        .overlay(Capsule().stroke(Palette.ember, lineWidth: 1.5))
                )
                .padding(.top, 26)
                .accessibilityHidden(true)

            Text("It sits on every screen.")
                .font(.spaceGrotesk(12.5))
                .foregroundStyle(Palette.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
        }
        .padding(.top, 34)
    }
}

/// Slips, before one happens.
///
/// Said here rather than after the fact because the belief that one cigarette
/// has ruined everything is what turns a slip into a relapse, and nobody
/// absorbs that argument for the first time while they are in the middle of
/// one. Forty days is named specifically: the fear is losing a count, so the
/// count is what gets protected out loud.
struct SlipsStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("If you slip, you haven't failed.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Most people who stop for good slipped on the way. One cigarette is one cigarette, and it doesn't wipe out the forty days behind it.")
                .font(.spaceGrotesk(14))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Text("There's a button for that too. Tell the truth and carry on.")
                .font(.spaceGrotesk(14))
                .lineSpacing(3)
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Text("I slipped")
                .font(.spaceGrotesk(15, weight: .medium))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule().stroke(Palette.cardBorder, lineWidth: 1.5)
                )
                .padding(.top, 24)
                .accessibilityHidden(true)
        }
        .padding(.top, 34)
    }
}

/// The last screen before the paywall: what is actually coming.
///
/// Everything on it is read off the same tables the rest of the app uses, so
/// it cannot drift from the Milestones tab or The Bill. It deliberately
/// computes nothing bespoke and promises no plan.
struct ReadyStep: View {
    @Environment(AppModel.self) private var model

    private var plan: QuitPlan? { model.draft }

    private var summary: ReadySummary? {
        plan.map { ReadySummary(plan: $0, now: model.clock.now) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("That's everything.")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)

            if let summary {
                Text(summary.headline)
                    .font(.spaceGrotesk(40, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.accent)
                    .padding(.top, 18)

                Text(summary.caption)
                    .font(.spaceGrotesk(14))
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(summary.rows) { row in
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.label)
                                .font(.spaceGrotesk(14))
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(row.value)
                                .font(.spaceGrotesk(13, weight: .medium))
                                .foregroundStyle(Palette.textMuted)
                        }
                        .padding(.vertical, 13)
                        Divider().overlay(Palette.cardBorder)
                    }
                }
                .padding(.top, 22)
            }

            Spacer(minLength: 18)

            PillButton(summary?.cta ?? "Start", style: .accent) {
                model.completeOnboarding()
                Task { await NotificationScheduler.shared.reschedule(state: model.state) }
            }
        }
        .padding(.top, 34)
    }
}

/// The numbers on the ready screen, kept out of the view so they can be tested.
///
/// The screen has to survive three different starting positions, and a
/// hardcoded "20 minutes until your heart rate settles" is false for two of
/// them: someone who scheduled Friday is not twenty minutes from anything, and
/// someone who backdated a month is long past it.
struct ReadySummary {
    struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    let headline: String
    let caption: String
    let rows: [Row]
    let cta: String

    init(plan: QuitPlan, now: Date) {
        let elapsed = now.timeIntervalSince(plan.quitDate) / 3600
        let upcoming = Milestones.all
            .filter { $0.applies(to: plan.product) && $0.hours > elapsed }
        let yearly = QuitProgress(plan: plan, now: now)
            .yearlyBurn.moneyString(plan.currencyCode)

        let listed: [Milestone]
        if plan.quitDate > now {
            // Scheduled. The first true thing is the day itself.
            headline = plan.quitDate.formatted(.dateTime.weekday(.wide))
            caption = "when day one starts. Everything below follows from it."
            cta = "That's the plan"
            listed = Array(upcoming.prefix(2))
        } else if let next = upcoming.first, elapsed < 1 {
            // Starting now: the nearest mark is minutes away and worth naming,
            // so it becomes the hero and drops out of the list below it.
            headline = next.when
            caption = "until \(next.title.lowercased()). Then:"
            cta = "Start day one"
            listed = Array(upcoming.dropFirst().prefix(2))
        } else {
            // Already stopped, possibly weeks ago.
            headline = "Day \(max(1, Int(elapsed / 24) + 1))"
            caption = upcoming.isEmpty
                ? "and every mark in the app is already behind you."
                : "already behind you. Still ahead:"
            cta = "Pick up from here"
            listed = Array(upcoming.prefix(2))
        }

        rows = listed.map { Row(label: $0.title, value: $0.when) }
            + [Row(label: "A year of \(plan.product.config.displayName.lowercased())",
                   value: yearly)]
    }
}
