import Foundation

/// The closing line of the reminders step, which names a real day.
///
/// It was written as "Let today reach next Tuesday" and shipped that way, which
/// is wrong twice over. It is wrong on a Monday, when next Tuesday is
/// tomorrow and the sentence promises nothing. It is wrong for anyone who
/// scheduled a date or backdated one, because the day that matters to them is
/// not the day that matters to someone starting now.
///
/// So the line names the day their resolve actually has to survive to, and
/// that day is different depending on where they are:
///
/// - **Scheduled ahead.** The risk is not day three, it is that the decision
///   quietly dissolves before the date arrives. The day to reach is the date
///   itself.
/// - **Starting now, or already stopped.** The date is behind them and the
///   risk is withdrawal, which peaks around the third day. The day to reach is
///   three days out.
///
/// The weekday named is never today's weekday, so "Thursday" can never be read
/// as the Thursday that is already happening.
enum ReminderHorizon {

    /// A date far enough out that a weekday name stops being unambiguous.
    /// "Monday" said eleven days early means the wrong Monday to most people.
    private static let namedWeekdayLimit = 6

    static func line(quitDate: Date, now: Date, calendar: Calendar = .current) -> String {
        "Let today reach \(target(quitDate: quitDate, now: now, calendar: calendar))."
    }

    /// Split out so the tests can assert the noun without the sentence.
    static func target(quitDate: Date, now: Date, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let daysAhead = calendar.dateComponents(
            [.day], from: today, to: calendar.startOfDay(for: quitDate)
        ).day ?? 0

        // Scheduled for a later day: that day is the thing to reach.
        if quitDate > now && daysAhead >= 1 {
            return daysAhead > namedWeekdayLimit
                ? "the day you picked"
                : weekday(quitDate, calendar)
        }

        // Started now, starting later today, or backdated. Three days out is
        // both the worst of withdrawal and, for someone weeks in, simply an
        // ordinary day on which they will not feel like this.
        let third = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        return weekday(third, calendar)
    }

    private static func weekday(_ date: Date, _ calendar: Calendar) -> String {
        date.formatted(
            .dateTime.weekday(.wide).locale(calendar.locale ?? .current)
        )
    }
}
