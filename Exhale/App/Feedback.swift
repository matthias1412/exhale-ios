import UIKit

/// Haptics.
///
/// You're right that the sensory channel matters — a reward you *feel* lands
/// differently from one you only read. On iOS haptics are the stronger half of
/// that: sound gets silenced, muted, or is simply antisocial (a lot of craving
/// moments happen in public, at work, or at 2am next to someone asleep), while
/// the Taptic Engine works in a pocket with the ringer off.
///
/// Used sparingly and only where something was genuinely earned. A quit app
/// that buzzes on every tap is a toy; one that taps you exactly when you
/// outlast a craving is telling you something.
enum Feedback {

    /// A milestone revealed. The heaviest thing in the app, used a dozen times
    /// in five years.
    static func milestone() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A craving outlasted. Earned, but it happens often enough that the
    /// milestone weight would cheapen both.
    static func cravingBeaten() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// A choice landing during onboarding — product, reason, day.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Deliberately absent: tab changes, scrolling, and anything the user does
    /// dozens of times a session. Constant feedback is noise, and noise is what
    /// makes people turn haptics off system-wide.
}
