import Foundation
import OSLog

/// A subscription offer with a **store-supplied, already-localised** price
/// string. Nothing in the app ever formats or converts a subscription price:
/// prices differ per country and a hardcoded one shows the wrong number to most
/// of the world.
struct SubscriptionOffer: Identifiable, Equatable, Sendable {
    enum Term: String, Sendable { case yearly, monthly }

    let id: String
    let term: Term
    /// e.g. "€29.99" — straight from the store.
    let localisedPrice: String
    /// e.g. "€2.49" — the yearly price divided by twelve, formatted by the
    /// store in the same currency. Nil for monthly.
    let localisedPricePerMonth: String?
    /// Raw amount, used only for the "pays for itself in N days" anchor.
    let amount: Decimal
    /// The currency the *store* charged in — which is not necessarily the
    /// currency the user priced their habit in. Comparing the two without
    /// checking this shows a garbage number to anyone whose App Store region
    /// differs from where they buy cigarettes.
    let currencyCode: String
    let hasFreeTrial: Bool
    let trialDays: Int
}

enum SubscriptionState: Equatable, Sendable {
    case loading
    case ready([SubscriptionOffer])
    case unavailable(String)
}

/// Everything the paywall needs, behind a protocol so screenshot seeds and
/// tests never touch the network or StoreKit.
@MainActor
protocol SubscriptionGate: AnyObject {
    var state: SubscriptionState { get }
    var isSubscribed: Bool { get }

    func load() async
    func purchase(_ offer: SubscriptionOffer) async -> Bool
    func restore() async -> Bool
}

/// Used by seeded screenshot runs and unit tests. Deterministic, offline.
///
/// The prices here are **placeholders for captures only** and must never reach
/// a user — which is also why marketing screenshots are taken from screens
/// without a price on them.
@MainActor
final class MockSubscriptionGate: SubscriptionGate {
    private(set) var state: SubscriptionState
    private(set) var isSubscribed: Bool

    init(state: SubscriptionState = .ready(MockSubscriptionGate.sampleOffers),
         isSubscribed: Bool = false) {
        self.state = state
        self.isSubscribed = isSubscribed
    }

    static let sampleOffers: [SubscriptionOffer] = [
        SubscriptionOffer(id: "exhale.yearly", term: .yearly,
                          localisedPrice: "€29.99", localisedPricePerMonth: "€2.49",
                          amount: 29.99, currencyCode: "EUR",
                          hasFreeTrial: true, trialDays: 7),
        SubscriptionOffer(id: "exhale.monthly", term: .monthly,
                          localisedPrice: "€4.99", localisedPricePerMonth: nil,
                          amount: 4.99, currencyCode: "EUR",
                          hasFreeTrial: false, trialDays: 0)
    ]

    func load() async {}
    func purchase(_ offer: SubscriptionOffer) async -> Bool { isSubscribed = true; return true }
    func restore() async -> Bool { isSubscribed }
}

/// The real implementation, wired to RevenueCat.
///
/// Deliberately thin: RevenueCat owns entitlements and receipt validation, and
/// this only translates its types into `SubscriptionOffer`. Configured at
/// launch from `RevenueCatKey` — see docs/signing.md for how the key is
/// injected, and note it is a *public* SDK key, not a secret.
@MainActor
final class RevenueCatSubscriptionGate: SubscriptionGate {
    private(set) var state: SubscriptionState = .loading
    private(set) var isSubscribed = false

    private let entitlement = "premium"
    private let logger = Logger(subsystem: "com.matthias.exhale", category: "subscriptions")

    func load() async {
        // Implemented once the RevenueCat products exist in the dashboard —
        // see README "What I need from you". Until then the app runs on
        // MockSubscriptionGate, and the paywall shows its unavailable state
        // rather than inventing prices.
        state = .unavailable("Subscriptions are not configured yet.")
        logger.notice("RevenueCat gate not configured; running without offers")
    }

    func purchase(_ offer: SubscriptionOffer) async -> Bool { false }
    func restore() async -> Bool { false }
}
