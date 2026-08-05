import Foundation

/// A finished run at quitting.
///
/// Kept forever. Relapse is the norm rather than the exception — most people
/// who quit for good do it across several attempts — so an app that erases the
/// previous 40 days the moment someone slips is teaching them the days didn't
/// count. They did.
struct QuitAttempt: Codable, Equatable, Sendable, Identifiable {
    let started: Date
    let ended: Date

    var id: Date { started }

    func days(calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: started)
        let to = calendar.startOfDay(for: ended)
        return max(1, (calendar.dateComponents([.day], from: from, to: to).day ?? 0) + 1)
    }
}

/// A single cigarette/pod/pouch during an otherwise intact run.
///
/// Deliberately distinct from a relapse. A slip that resets a 60-day streak to
/// zero is a punishment the evidence doesn't support, and it hands the user a
/// reason to give up entirely — the abstinence violation effect. The streak
/// survives; the slip is recorded honestly and shows on The Bill.
struct Slip: Codable, Equatable, Sendable, Identifiable {
    let date: Date
    var id: Date { date }
}

extension PersistedState {
    /// Longest run so far, current attempt included.
    func bestStreakDays(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let past = pastAttempts.map { $0.days(calendar: calendar) }.max() ?? 0
        let current = plan.map {
            QuitProgress(plan: $0, now: now, calendar: calendar).dayNumber
        } ?? 0
        return max(past, current)
    }

    var totalAttempts: Int { pastAttempts.count + (plan == nil ? 0 : 1) }

    /// Slips inside the current run only — earlier ones belong to earlier runs.
    func slipsInCurrentAttempt() -> [Slip] {
        guard let start = plan?.quitDate else { return [] }
        return slips.filter { $0.date >= start }
    }

    /// Close the current run and begin a new one. The old attempt is preserved.
    mutating func recordRelapse(at date: Date = Date()) {
        guard var plan else { return }
        pastAttempts.append(QuitAttempt(started: plan.quitDate, ended: date))
        plan.quitDate = date
        self.plan = plan
        // Reset the celebration watermark, or the new run inherits the old
        // one's and every early milestone is silently suppressed. Someone
        // starting again at day 1 would get nothing until they passed whatever
        // they'd already reached — exactly when encouragement matters most.
        lastCelebratedHours = 0
    }

    /// One slip, streak intact.
    mutating func recordSlip(at date: Date = Date()) {
        slips.append(Slip(date: date))
    }
}
