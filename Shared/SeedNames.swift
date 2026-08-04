import Foundation

/// Every screenshot-reachable state, by name.
///
/// This file is compiled into **both** the app and the UI test target so the
/// harness can never drift from what the app actually understands. The app
/// resolves each name in `Seed.swift`; the UI test iterates this list.
///
/// Multi-step overlays get one entry per step. The breathing cycle is the
/// obvious trap — capturing only "Breathe in" would leave two thirds of the
/// craving flow unseen.
enum SeedNames {

    /// Seeds captured on every device when `devices: all`.
    static let all: [String] = onboarding + core + overlays

    static let onboarding: [String] = [
        "onboard-product",
        "onboard-product-selected",
        "onboard-amount-cigarettes",
        "onboard-amount-vape",          // the per-week question
        "onboard-amount-pouches",
        "onboard-price-cigarettes",
        "onboard-price-vape",
        "onboard-quit-moment",
        "onboard-quit-picker",
        "paywall",
        "paywall-loading"
    ]

    static let core: [String] = [
        "today-day1",                   // the bloom at its smallest
        "today-day14",
        "today-day90",                  // the App Store hero
        "today-day365",                 // first year marker
        "today-day1825",                // five years, 3pt dots
        "today-vape",                   // product-adaptive stats row
        "bill-cigarettes",
        "bill-tally-x10",               // past 40 containers, ×10 glyphs
        "bill-vape",
        "bill-long-money",              // shrunken money figure
        "milestones-early",
        "milestones-late",
        "settings"
    ]

    static let overlays: [String] = [
        "sos-breathe-in",
        "sos-hold",
        "sos-let-go",
        "banner-milestone",
        "debug-menu"
    ]

    /// The cheap default set for `devices: one` — enough to catch a regression
    /// without paying for the full sweep.
    static let smoke: [String] = [
        "onboard-product",
        "onboard-product-selected",
        "paywall",
        "today-day90",
        "bill-cigarettes",
        "bill-tally-x10",
        "milestones-early",
        "sos-breathe-in",
        "settings"
    ]
}
