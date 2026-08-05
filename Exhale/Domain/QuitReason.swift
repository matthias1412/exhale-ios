import Foundation

/// Why the user is quitting.
///
/// This is not a survey question — nothing is collected for its own sake. It
/// changes the app:
///
/// - **Which tab opens first.** Someone quitting to save money should land on
///   The Bill, not the spiral.
/// - **What the craving screen says.** At 2am the most useful sentence is the
///   user's own reason, in their own words, handed back to them. Reminding
///   someone of a self-chosen goal at the moment of temptation is a commitment
///   device; a generic "stay strong" is not.
/// - **Which milestones lead.**
///
/// Autonomous motivation ("I want to be around for my kids") predicts success
/// far better than controlled motivation ("my doctor told me to"), so the
/// options are all phrased as the user's own choice.
enum QuitReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case health
    case money
    case someone
    case freedom
    case fitness
    case smell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "My health"
        case .money: "The money"
        case .someone: "Someone in particular"
        case .freedom: "Being free of it"
        case .fitness: "Fitness and breath"
        case .smell: "The smell of it"
        }
    }

    var subtitle: String {
        switch self {
        case .health: "Lungs, heart, the long game"
        case .money: "It adds up to real things"
        case .someone: "A partner, a child, a parent"
        case .freedom: "Not needing anything"
        case .fitness: "Stairs, sport, sleep"
        case .smell: "Clothes, breath, hands"
        }
    }

    /// Shown on the craving screen. `name` is only ever non-nil for `.someone`.
    func affirmation(name: String?) -> String {
        switch self {
        case .health:
            "You're doing this for your health. This craving doesn't change that."
        case .money:
            "You're doing this for the money. Every one you don't buy is yours."
        case .someone:
            if let name, !name.isEmpty {
                "You're doing this for \(name)."
            } else {
                "You're doing this for someone who matters to you."
            }
        case .freedom:
            "You're doing this to not need it. Right now is the needing talking."
        case .fitness:
            "You're doing this to breathe easier. This passes; that lasts."
        case .smell:
            "You're doing this to be rid of the smell of it. Three minutes."
        }
    }

    /// Where the app opens. The headline number should be the one they care about.
    var preferredTab: MainTab {
        switch self {
        case .money: .bill
        case .health, .fitness: .milestones
        case .someone, .freedom, .smell: .today
        }
    }

}

extension Array where Element == QuitReason {
    /// The first one chosen carries the personalisation.
    var primary: QuitReason? { first }
}
