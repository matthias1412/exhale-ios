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
        "paywall",
        "paywall-loading",
        "paywall-foreign-currency"

        "today-day1",                   // the bloom at its smallest
        "today-day14",
        "today-day90",                  // the App Store hero
        "today-day365",                 // first year marker
        "today-day1825",                // five years, 3pt dots
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
        "milestones-late",
        "settings"

        "sos-breathe-in",
        "sos-hold",
        "sos-let-go",
        "sos-with-reason",
        "slip-sheet",
        "today-after-relapse",
        "banner-milestone",
        "debug-menu"
    ]

    /// The cheap default set for `devices: one` — enough to catch a regression
    /// without paying for the full sweep.
    static let smoke: [String] = [
        "onboard-product",
        "onboard-product-selected",
        "onboard-reason",
        "onboard-reason-chosen",
        "paywall",
        "today-day90",
        "bill-cigarettes",
        "bill-tally-x10",
        "milestones-early",
        "sos-breathe-in",
        "settings"
    ]
}
