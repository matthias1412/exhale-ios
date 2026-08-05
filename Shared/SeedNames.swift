import Foundation

/// Every screenshot-reachable state, by name.
///
/// Single source of truth for the harness: the app resolves each name in
/// `Seed.swift`, and .github/scripts/capture.sh reads the names straight out of
/// this file — which is why it must contain no unrelated string literals.
///
/// Multi-step overlays get one entry per step. The breathing cycle is the
/// obvious trap — capturing only "Breathe in" would leave two thirds of the
/// craving flow unseen.
enum SeedNames {

    /// Seeds captured on every device when `devices: all`.
    static let all: [String] = [
        "onboard-intro",
        "onboard-product",
        "onboard-product-selected",
        "onboard-reason",
        "onboard-reason-chosen",
        "onboard-amount-cigarettes",
        "onboard-amount-vape",          // the per-week question
        "onboard-amount-pouches",
        "onboard-price-cigarettes",
        "onboard-price-vape",
        "onboard-quit-moment",
        "onboard-quit-time",
        "onboard-quit-date",
        "onboard-price-yearly",
        "onboard-price-empty",
        "paywall",
        "paywall-loading",
        "paywall-foreign-currency",

        "today-day1",                   // the bloom at its smallest
        "today-day14",
        "today-day90",                  // the App Store hero
        "today-day365",                 // first year marker
        "today-day1825",                // five years, 3pt dots
        "today-day8",                   // today's dot is also a milestone dot
        "today-vape",
        "today-imminent-milestone",
        "pre-quit-countdown",
        "milestone-celebration",
        "milestone-celebration-f20",
        "milestone-celebration-f45",
        "milestone-celebration-f70",                   // product-adaptive stats row
        "bill-cigarettes",
        "bill-tally-x10",               // past 40 containers, ×10 glyphs
        "bill-vape",
        "bill-long-money",              // shrunken money figure
        "milestones-early",
        "milestones-notifications-denied",
        "slip-backdated",
        "milestones-late",
        "settings",

        "sos-breathe-in",
        "sos-hold",
        "sos-let-go",
        "sos-with-reason",
        "slip-sheet",
        "today-after-relapse",
        "banner-milestone",
        "debug-menu"
    ]

    /// The spiral's arrival, pinned frame by frame. Its own set because it is
    /// fourteen captures of one animation — worth a single device when the
    /// motion is being worked on, not worth paying for on every sweep.
    static let motion: [String] = [
        "reveal-day1-f40",
        "reveal-day1-f75",
        "reveal-day14-f35",
        "reveal-day14-f70",
        "reveal-day90-f25",
        "reveal-day90-f55",
        "reveal-day90-f85",
        "reveal-day365-f50",
        "reveal-day1825-f45",
        "reveal-day1825-f90",
        "reveal-milestone-today-f60",
        "reveal-milestone-today",
        "reveal-milestone-dense-f60",
        "reveal-milestone-dense"
    ]

    /// Recorded as video rather than stills. A pinned frame proves the drawing
    /// is right; only motion shows whether the timing is. The breathing orb is
    /// here because a still of it is indistinguishable from the bug where it
    /// never moved at all. Durations live in capture-movies.sh.
    static let movies: [String] = [
        "today-day1",
        "today-day14",
        "today-day90",
        "today-day8",
        "today-day365",
        "today-day1825",
        "celebration-handoff",
        "handoff-72h",
        "handoff-2weeks",
        "handoff-1month",
        "handoff-3months",
        "handoff-1year",
        "handoff-5years",
        "sos-live"
    ]

    /// The cheap default set for `devices: one` — enough to catch a regression
    /// without paying for the full sweep.
    static let smoke: [String] = [
        "onboard-intro",
        "onboard-product",
        "onboard-product-selected",
        "onboard-reason",
        "onboard-reason-chosen",
        "paywall",
        "today-day90",
        "bill-cigarettes",
        "bill-tally-x10",
        "milestones-early",
        "milestones-notifications-denied",
        "slip-backdated",
        "sos-breathe-in",
        "settings"
    ]
}
