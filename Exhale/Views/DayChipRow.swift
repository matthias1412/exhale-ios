import SwiftUI

/// Picking the quit day, a week either side of today.
///
/// A wheel picker is the wrong control here. Nobody quitting smoking needs to
/// select a date in 2019, and scrolling three components to land on "Tuesday"
/// is friction at the exact moment we want none. Real answers cluster in a
/// handful of days: just now, this morning, last Thursday, or "I'm starting on
/// Monday" — so those are the only options offered.
///
/// The window is deliberately one week in each direction. Further back and the
/// number is a guess; further forward and it isn't a decision, it's a delay.
struct DayChipRow: View {
    @Binding var selection: Date
    let now: Date
    /// Slips only ever happened in the past; a quit day can be scheduled.
    var allowsFuture: Bool = true

    private var calendar: Calendar { .current }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(offsets, id: \.self) { offset in
                        chip(offset: offset)
                            .id(offset)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(0, anchor: .center) }
            // Chips run past both edges; a hard clip mid-word looks like a bug,
            // a fade reads as "there is more this way".
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.06),
                        .init(color: .black, location: 0.94),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        }
    }

    private var offsets: [Int] { Array(-6...(allowsFuture ? 6 : 0)) }

    private func date(for offset: Int) -> Date {
        let start = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        // Past and today keep a plausible hour; future days start at midnight,
        // because a quit that hasn't happened has no time of day yet.
        return offset < 0 ? day.addingTimeInterval(12 * 3600)
             : offset == 0 ? min(now, day.addingTimeInterval(12 * 3600))
             : day
    }

    private func isSelected(_ offset: Int) -> Bool {
        calendar.isDate(selection, inSameDayAs: date(for: offset))
    }

    private func chip(offset: Int) -> some View {
        let selected = isSelected(offset)
        return Button {
            selection = date(for: offset)
        } label: {
            VStack(spacing: 2) {
                Text(label(for: offset))
                    .font(.spaceGrotesk(13, weight: .bold))
                Text(date(for: offset).formatted(.dateTime.day().month(.abbreviated)))
                    .font(.spaceGrotesk(10))
                    .foregroundStyle(selected ? Palette.onAccent.opacity(0.7) : Palette.textFaint)
            }
            .foregroundStyle(selected ? Palette.onAccent : Palette.textPrimary)
            .frame(minWidth: 74)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Palette.accent : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? .clear : Palette.cardBorder, lineWidth: 1.5)
                    )
            )
        }
        .accessibilityLabel(label(for: offset))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func label(for offset: Int) -> String {
        switch offset {
        case 0: "Today"
        case -1: "Yesterday"
        case 1: "Tomorrow"
        default: date(for: offset).formatted(.dateTime.weekday(.wide))
        }
    }
}

/// For someone who stopped longer ago than the chips reach.
///
/// The chips cover "just now" through "last Thursday", which is where honest
/// answers cluster. They do not cover the person who quit in the spring and is
/// installing this in August, and that person exists: the welcome screen offers
/// them a way in, so the app has to have somewhere to put them.
///
/// A year back is the limit. Past that the app would be a record of something
/// finished rather than a tool for something in progress.
struct PastQuitDatePicker: View {
    let now: Date
    let pick: (Date) -> Void

    @State private var date: Date
    @Environment(\.dismiss) private var dismiss

    init(now: Date, pick: @escaping (Date) -> Void) {
        self.now = now
        self.pick = pick
        _date = State(initialValue: Calendar.current.date(
            byAdding: .day, value: -30, to: now
        ) ?? now)
    }

    private var range: ClosedRange<Date> {
        let earliest = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        return earliest...now
    }

    private var dayCount: Int {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.startOfDay(for: now)
        ).day ?? 0
        return max(1, days + 1)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    DatePicker(
                        "Last one",
                        selection: $date,
                        in: range,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Palette.accent)
                    .padding(.horizontal, 8)

                    Text("That puts you on day \(dayCount).")
                        .font(.spaceGrotesk(15, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)

                    Text("Everything before today is already behind you, so nothing will be celebrated retrospectively.")
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                        .padding(.top, 6)

                    Spacer()

                    PillButton("That's when I stopped", style: .accent) {
                        pick(Calendar.current.startOfDay(for: date).addingTimeInterval(12 * 3600))
                    }
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
