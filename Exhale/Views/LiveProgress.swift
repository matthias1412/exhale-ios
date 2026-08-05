import SwiftUI

/// Drives anything that has to move on its own.
///
/// The design brief's second pillar is watching the money count up *in real
/// time*, and it wasn't happening: nothing in the app caused a re-render on a
/// timer, so `QuitProgress` was recomputed only when some unrelated piece of
/// state changed. The counter sat frozen — often for the entire session — and
/// the one screen whose whole promise is a number ticking upward showed a
/// number that didn't.
///
/// Seeded runs deliberately skip the timeline and use the frozen clock, so
/// screenshots stay byte-identical between captures.
struct LiveProgress<Content: View>: View {
    let plan: QuitPlan
    let clock: AppClock
    @ViewBuilder var content: (QuitProgress) -> Content

    var body: some View {
        if clock.isFrozen {
            content(QuitProgress(plan: plan, now: clock.now))
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                content(QuitProgress(plan: plan, now: timeline.date))
            }
        }
    }
}
