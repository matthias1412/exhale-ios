import SwiftUI

/// The scheduled day has arrived. Did it happen?
///
/// Nothing here existed before, and the count simply began on the stroke of the
/// chosen date. Someone who set Monday, kept smoking, and opened the app on
/// Wednesday was told they were on day three. The number the entire product
/// rests on was being asserted by a clock rather than reported by a person.
///
/// Three answers, because there are three real situations: it happened, it
/// happened but later than planned, or it did not happen yet. None of them is
/// a failure and none of them is worded as one. "Not yet" in particular has to
/// be an ordinary option rather than a confession, because someone who feels
/// caught out by their own app closes it.
struct StartConfirmationView: View {
    @Environment(AppModel.self) private var model

    @State private var pickingLater = false
    @State private var pickingNewDay = false
    @State private var laterMoment = Date()

    private var scheduled: Date { model.plan?.quitDate ?? model.clock.now }

    private var whenPhrase: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(scheduled) { return "today" }
        if calendar.isDateInYesterday(scheduled) { return "yesterday" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: scheduled),
            to: calendar.startOfDay(for: model.clock.now)
        ).day ?? 0
        return days < 7
            ? scheduled.formatted(.dateTime.weekday(.wide))
            : scheduled.formatted(.dateTime.day().month(.wide))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            LogoMark(size: 44)
                .opacity(0.35)
                .padding(.bottom, 24)

            Text(whenPhrase.uppercased())
                .font(.spaceGrotesk(11, weight: .medium))
                .tracking(1.98)
                .foregroundStyle(Palette.textMuted)

            Text("Did you stop?")
                .font(.spaceGrotesk(34, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(Palette.textBrightest)
                .padding(.top, 6)

            Text("Nothing counts until you say so.")
                .font(.spaceGrotesk(13.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textMuted)
                .padding(.top, 10)
                .padding(.horizontal, 40)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                PillButton("Yes, \(whenPhrase)", style: .accent) {
                    model.confirmStart()
                }

                Button("I stopped, but later than that") {
                    laterMoment = scheduled
                    pickingLater = true
                }
                .font(.spaceGrotesk(13.5, weight: .medium))
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)

                Button("Not yet, move it") { pickingNewDay = true }
                    .font(.spaceGrotesk(13.5))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $pickingLater) {
            LaterMomentSheet(
                earliest: scheduled,
                now: model.clock.now,
                moment: $laterMoment
            ) {
                model.confirmStart(at: laterMoment)
                pickingLater = false
            }
        }
        .sheet(isPresented: $pickingNewDay) {
            RescheduleSheet(now: model.clock.now) { date in
                model.rescheduleStart(to: date)
                pickingNewDay = false
            }
        }
    }
}

/// "I stopped, but later than that." Anything between the scheduled moment and
/// now, because the honest answer is often "Tuesday afternoon, not Monday".
private struct LaterMomentSheet: View {
    let earliest: Date
    let now: Date
    @Binding var moment: Date
    let confirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    DatePicker(
                        "When",
                        selection: $moment,
                        in: earliest...now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(Palette.accent)
                    .padding(.horizontal, 8)

                    Spacer()

                    PillButton("That's when I stopped", style: .accent, action: confirm)
                        .padding(.horizontal, 26)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("When was your last one?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
    }
}

/// Moving the day, from either the countdown or the confirmation.
///
/// Deliberately not routed back through onboarding: that path ends at the
/// paywall, which is not where someone changing a date should land.
struct RescheduleSheet: View {
    let now: Date
    let pick: (Date) -> Void

    @State private var chosen: Date
    @Environment(\.dismiss) private var dismiss

    init(now: Date, pick: @escaping (Date) -> Void) {
        self.now = now
        self.pick = pick
        _chosen = State(initialValue: Calendar.current.date(
            byAdding: .day, value: 1, to: now
        ) ?? now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pick a day you'll keep. Moving it is not a failure, and it beats a date that quietly passed.")
                        .font(.spaceGrotesk(13.5))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 26)
                        .padding(.top, 18)

                    DayChipRow(selection: $chosen, now: now)
                        .padding(.top, 22)

                    Spacer()

                    PillButton("Set that as my quit day", style: .accent) { pick(chosen) }
                        .padding(.horizontal, 26)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("When instead?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textMuted)
                }
            }
        }
    }
}
