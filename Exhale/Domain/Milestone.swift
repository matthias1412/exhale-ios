import Foundation
import SwiftUI

/// A point on the healing timeline.
///
/// Copy is descriptive, taken from widely published smoking-cessation
/// timelines. It is **not** medical advice and should be reviewed before
/// shipping — see `docs/health-claims.md`.
struct Milestone: Identifiable, Equatable, Sendable {
    /// Hours after the quit instant.
    let hours: Double
    /// "20 min", "3 months" — shown right-aligned.
    let when: String
    let title: String
    let body: String
    /// `nil` applies to every product.
    let product: NicotineProduct?

    var id: String { "\(hours)-\(title)" }

    func applies(to candidate: NicotineProduct) -> Bool {
        self.product == nil || self.product == candidate
    }

    func date(from quitDate: Date) -> Date {
        quitDate.addingTimeInterval(hours * 3600)
    }
}

enum Milestones {

    static let all: [Milestone] = [
        Milestone(hours: 0.34, when: "20 min",
                  title: "Heart rate settles",
                  body: "Pulse and blood pressure drift back toward normal.",
                  product: nil),
        Milestone(hours: 12, when: "12 h",
                  title: "Carbon monoxide clears",
                  body: "Oxygen levels in your blood return to normal.",
                  product: .cigarettes),
        Milestone(hours: 48, when: "48 h",
                  title: "Taste & smell sharpen",
                  body: "Nerve endings start repairing. Food gets better.",
                  product: .cigarettes),
        Milestone(hours: 72, when: "72 h",
                  title: "Nicotine-free body",
                  body: "The nicotine itself is out of your system. It's habit now, not chemistry.",
                  product: nil),
        Milestone(hours: 168, when: "1 week",
                  title: "Peak cravings behind you",
                  body: "The worst of the urges is statistically over.",
                  product: nil),
        Milestone(hours: 336, when: "2 weeks",
                  title: "Gums healing",
                  body: "The spot where the pouch sat stops feeling raw and tender.",
                  product: .pouches),
        Milestone(hours: 336, when: "2 weeks",
                  title: "Circulation improving",
                  body: "Walking and exercise start feeling easier.",
                  product: .cigarettes),
        Milestone(hours: 504, when: "3 weeks",
                  title: "Breathing easier",
                  body: "Airway irritation from vapour settles down.",
                  product: .vape),
        Milestone(hours: 720, when: "1 month",
                  title: "Energy stabilises",
                  body: "Sleep, focus and mood level out without the spikes.",
                  product: nil),
        Milestone(hours: 2160, when: "3 months",
                  title: "The grip is broken",
                  body: "Cravings become rare visitors, not roommates.",
                  product: nil),
        Milestone(hours: 4320, when: "6 months",
                  title: "Half a year yours",
                  body: "Stress without reaching for it is your new normal.",
                  product: nil),
        Milestone(hours: 8760, when: "1 year",
                  title: "One full year",
                  body: "The odds of staying quit for good are now heavily on your side.",
                  product: nil),
        Milestone(hours: 17520, when: "2 years",
                  title: "Two years free",
                  body: "Relapse risk is a fraction of what it was. This is who you are now.",
                  product: nil),
        Milestone(hours: 43800, when: "5 years",
                  title: "Five years out",
                  body: "For smokers: stroke risk has fallen back to that of a non-smoker.",
                  product: nil)
    ]

    static func forProduct(_ product: NicotineProduct) -> [Milestone] {
        all.filter { $0.applies(to: product) }
    }

    /// State of each milestone for a given elapsed time.
    enum State: Equatable, Sendable {
        case passed
        case next(fractionComplete: Double)
        case future
    }

    static func states(
        for product: NicotineProduct,
        hoursElapsed: Double
    ) -> [(milestone: Milestone, state: State)] {
        let list = forProduct(product)
        var foundNext = false

        return list.map { milestone in
            if hoursElapsed >= milestone.hours {
                return (milestone, .passed)
            }
            guard !foundNext else { return (milestone, .future) }
            foundNext = true

            let previous = list
                .filter { $0.hours < milestone.hours }
                .map(\.hours)
                .max() ?? 0
            let span = milestone.hours - previous
            let fraction = span > 0
                ? min(0.99, max(0.01, (hoursElapsed - previous) / span))
                : 0.01
            return (milestone, .next(fractionComplete: fraction))
        }
    }

    static func upcoming(
        for product: NicotineProduct,
        hoursElapsed: Double,
        limit: Int = 3
    ) -> [Milestone] {
        forProduct(product)
            .filter { $0.hours > hoursElapsed }
            .prefix(limit)
            .map { $0 }
    }
}

extension Milestone {
    /// Each milestone owns a colour, so the dot it leaves in the spiral is
    /// individually recognisable rather than one of a thousand identical ones.
    /// Walks the same ember → sea-glass ramp the spiral uses, so a milestone
    /// dot always looks like it belongs to the streak it sits in.
    var colour: Color {
        let ramp = min(1, log(hours + 1) / log(43_800 + 1))
        return Palette.spiralDot(ramp: ramp)
    }
}

extension Milestones {
    /// Milestones passed since `lastSeen` — what the user has "earned" while
    /// the app was closed and hasn't been shown yet.
    static func unseen(
        for product: NicotineProduct,
        quitDate: Date,
        lastSeenHours: Double,
        now: Date
    ) -> [Milestone] {
        let elapsed = max(0, now.timeIntervalSince(quitDate)) / 3600
        return forProduct(product).filter { $0.hours > lastSeenHours && $0.hours <= elapsed }
    }

    /// The next milestone, and how close it is — used for the near-miss nudge.
    /// Effort rises sharply near a goal, so "one more day" is worth saying.
    static func imminent(
        for product: NicotineProduct,
        hoursElapsed: Double
    ) -> (milestone: Milestone, hoursAway: Double)? {
        guard let next = forProduct(product).first(where: { $0.hours > hoursElapsed }) else {
            return nil
        }
        let away = next.hours - hoursElapsed
        return away <= 24 ? (next, away) : nil
    }
}
