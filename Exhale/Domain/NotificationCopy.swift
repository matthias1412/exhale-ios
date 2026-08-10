import Foundation

/// Every word the app puts on a lock screen.
///
/// Pure and free of `UserNotifications` so the wording can be unit-tested and
/// previewed, rather than discovered on a phone three days after install.
///
/// The reason the user gave is used here. It already drove the craving screen
/// and which tab opens first, but every notification was generic — so someone
/// who said they were doing this for Emma never once saw Emma's name on their
/// lock screen, which is the exact moment it would have counted.
///
/// ## Rules the wording follows
///
/// **A name is a dedication, never a witness.** "This is the one for Emma"
/// claims nothing. "Emma would say so too" claims she is watching and
/// approving, and says nothing at all; "Emma hasn't smelled it on you since"
/// assumes she is physically near you every day. Emma might be a grandparent
/// who died, or a child seen every other weekend. The app knows a first name
/// and nothing else, so it may only ever say what the *user* told it: that
/// this is for them.
///
/// **Nothing tells the user what they are feeling.** "You're not resisting it
/// any more" is a claim about someone's inner state on a morning that might be
/// going badly. Describe the body, the money and the days — those are known.
///
/// **No assumptions about the calendar.** An earlier line promised clean
/// clothes "by the weekend", which is wrong for anyone who stops on a
/// Saturday.
enum NotificationCopy {

    struct Message: Equatable, Sendable {
        let title: String
        let body: String
    }

    // MARK: - The day it starts

    /// Fired on the quit instant itself. Missing entirely before: someone who
    /// picked "Monday" got silence on Monday, which is the one morning the app
    /// most needs to be present.
    static func dayOne(reason: QuitReason?, name: String?) -> Message {
        let body: String
        switch reason {
        case .health:
            body = "From this hour your body starts putting itself back. Twenty minutes for the first change."
        case .money:
            body = "The meter starts now, and it runs in your favour from here."
        case .someone:
            body = person(name).map { "This is the one for \($0)." }
                ?? "This is the one for the person you had in mind."
        case .freedom:
            body = "Nothing owns you from here. Today is the first day of that."
        case .fitness:
            body = "Your breath starts coming back today. You'll notice it on stairs first."
        case .smell:
            body = "Give it a few days and your clothes will stop smelling of it."
        case nil:
            body = "Day one starts now. Twenty minutes to the first change."
        }
        return Message(title: "Day one", body: body)
    }

    /// The evening before a scheduled start. Only sent when the quit date was
    /// set at least a day out — there is no eve for "I just had my last one".
    static func eveOfQuit(reason: QuitReason?, name: String?) -> Message {
        let body: String
        switch reason {
        case .money:
            body = "Last night of paying for it. Tomorrow the money starts staying put."
        case .someone:
            body = person(name).map { "\($0) is the reason. Tomorrow it starts." }
                ?? "Tomorrow it starts."
        case .freedom:
            body = "Last night of needing it. Get some sleep."
        default:
            body = "Whatever's left, finish it or bin it tonight. Day one is tomorrow."
        }
        return Message(title: "Tomorrow's the day", body: body)
    }

    // MARK: - The morning nudge

    /// Deliberately about identity rather than effort past the first few days:
    /// people who come to see themselves as non-smokers stay stopped more
    /// reliably than people who see themselves as smokers resisting.
    static func morning(day: Int, reason: QuitReason?, name: String?) -> Message {
        // The first week has its own script, because what is true on day two
        // is not true on day twenty and saying otherwise is how a nudge starts
        // getting ignored.
        switch day {
        case ..<2:
            return Message(title: "Day \(day)",
                           body: "The first day is the loudest one. It gets quieter from here.")
        case 2:
            return Message(title: "Day 2",
                           body: "Day two is usually the worst of it. That's not a warning, it's the peak.")
        case 3:
            return Message(title: "Day 3",
                           body: "By tonight the nicotine is out of you. What's left after that is habit.")
        case 4...6:
            return Message(title: "Day \(day)",
                           body: "\(day - 1) days done. Today is just the next one.")
        default:
            break
        }

        // Past the first week the day count is the evidence, and the second
        // line varies with the reason so a daily nudge doesn't become wallpaper.
        let later: String
        switch reason {
        case .money:
            later = "Another day of not handing money over."
        case .someone:
            later = person(name).map { "\($0) is still the reason." }
                ?? "Still going, for the reason you gave."
        case .health:
            later = "Your lungs are further along than they were last week."
        case .fitness:
            later = "Around now, stairs start giving you less trouble."
        case .smell:
            later = "Your clothes stopped carrying it a while ago."
        case .freedom, nil:
            later = "Not smoking is turning into the ordinary thing you do."
        }
        return Message(title: "Day \(day)", body: later)
    }

    // MARK: - The weekly receipt

    /// Deliberately unpersonalised. The figure is already the user's own, and
    /// an earlier version appended "That's Emma's too" — which quietly claims
    /// the money belongs to someone who never agreed to that.
    static func weeklyBill(thisWeek: String, total: String) -> Message {
        Message(
            title: "Another week clear",
            body: "\(thisWeek) stayed in your pocket this week. \(total) since you stopped."
        )
    }

    // MARK: - Milestones

    /// Left factual on purpose. These are the one place the app makes a claim
    /// about the user's body, so they say what happened and nothing else.
    static func milestone(_ milestone: Milestone) -> Message {
        Message(title: milestone.title, body: "\(milestone.when) in. \(milestone.body)")
    }

    // MARK: -

    private static func person(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
