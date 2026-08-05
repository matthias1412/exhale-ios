import SwiftUI

/// What happens after a cigarette.
///
/// The design problem: the moment someone slips is the moment they are most
/// likely to delete the app. The *abstinence violation effect* — "I've broken
/// it, so it's broken, so why bother" — is what turns one cigarette into a
/// relapse. Everything here is built to interrupt that:
///
/// - **A slip does not have to reset the streak.** Offering "it was one" as the
///   first, easiest option is the whole point. Zeroing a 60-day spiral over one
///   cigarette is a punishment the evidence doesn't support.
/// - **No shame language.** Not "you failed", not "start over". The days
///   already earned are stated plainly, because they still happened.
/// - **Relapse keeps its history.** Choosing to reset preserves the old attempt
///   and the app says what the previous run was worth.
struct SlipSheet: View {
    @Environment(AppModel.self) private var model
    /// People do not open the app at the moment they smoke. Recording "now"
    /// when it happened on Tuesday puts a wrong date in a permanent record,
    /// and — for a relapse — starts the new streak from the wrong day.
    @State private var when: Date?

    var body: some View {
        let progress = model.progress

        VStack(alignment: .leading, spacing: 0) {
            Text("It happened.")
                .font(.spaceGrotesk(28, weight: .bold, relativeTo: .title))
                .padding(.top, 30)

            Text("That's not the end of anything. What you do next is the part that matters.")
                .font(.spaceGrotesk(14))
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            if let progress {
                Text("You're \(progress.dayNumber) \(progress.dayNumber == 1 ? "day" : "days") in. Those days are still yours.")
                    .font(.spaceGrotesk(13.5, weight: .medium))
                    .foregroundStyle(Palette.accentSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            if let reason = model.state.reasons.primary {
                Text(reason.affirmation(name: model.state.reasonName))
                    .font(.spaceGrotesk(14, weight: .medium))
                    .foregroundStyle(Palette.accentSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            Text("WHEN")
                .font(.spaceGrotesk(11, weight: .medium))
                .tracking(1.98)
                .foregroundStyle(Palette.textFaint)
                .padding(.top, 22)

            DayChipRow(
                selection: Binding(
                    get: { when ?? model.clock.now },
                    set: { when = min($0, model.clock.now) }
                ),
                now: model.clock.now,
                allowsFuture: false
            )
            .padding(.top, 8)

            VStack(spacing: 12) {
                // Listed first, and styled as the primary action, on purpose.
                choice(
                    title: "It was one — I'm still going",
                    detail: "Your streak and your spiral stay exactly as they are.",
                    style: .accent
                ) {
                    model.state.recordSlip(at: effectiveDate)
                    model.slipSheetOpen = false
                }

                choice(
                    title: "I've started smoking again",
                    detail: "Begins a new day 1. Your \(bestLine) is kept.",
                    style: .outline
                ) {
                    model.state.recordRelapse(at: effectiveDate)
                    model.slipSheetOpen = false
                }

                choice(title: "Never mind", detail: nil, style: .quiet) { model.slipSheetOpen = false }
            }
            .padding(.top, 26)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.background)
    }

    /// Never later than now — a slip in the future is not a thing.
    private var effectiveDate: Date {
        min(when ?? model.clock.now, model.clock.now)
    }

    private var bestLine: String {
        let best = model.state.bestStreakDays(now: model.clock.now)
        return "best run of \(best) \(best == 1 ? "day" : "days")"
    }

    @ViewBuilder
    private func choice(
        title: String,
        detail: String?,
        style: PillButton.Style,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.spaceGrotesk(16, weight: .bold))
                    .foregroundStyle(style == .accent ? Palette.onAccent : Palette.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(style == .accent
                                         ? Palette.onAccent.opacity(0.75)
                                         : Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(style == .accent ? Palette.accent : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(style == .quiet
                                    ? Palette.textPrimary.opacity(0.12)
                                    : Palette.cardBorder,
                                    lineWidth: style == .accent ? 0 : 1.5)
                    )
            )
        }
        .accessibilityLabel(detail.map { "\(title). \($0)" } ?? title)
    }
}
