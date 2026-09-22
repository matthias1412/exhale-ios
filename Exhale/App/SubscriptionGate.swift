import Foundation
import OSLog
import RevenueCat

/// A subscription offer with a **store-supplied, already-localised** price
/// string. Nothing in the app ever formats or converts a subscription price:
/// prices differ per country and a hardcoded one shows the wrong number to most
/// of the world.
struct SubscriptionOffer: Identifiable, Equatable, Sendable {
    enum Term: String, Sendable { case yearly, monthly }

    let id: String
    let term: Term
    /// e.g. "€19.99" — straight from the store.
    let localisedPrice: String
    /// e.g. "€1.67" — the yearly price divided by twelve, formatted by the
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

    /// `nil` means *not yet asked*, which is not the same as "no".
    ///
    /// This used to be a plain `Bool`, and the difference did not matter
    /// while nothing read it. The moment the app locks on it, a `false` that
    /// really means "the store has not answered yet" shuts a paying
    /// subscriber out of the app they paid for, every cold launch, for as
    /// long as the network takes.
    var isSubscribed: Bool? { get }

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
    /// Unknown, so seeded captures of the app are never locked behind the
    /// paywall. A screenshot run does not have a store to ask.
    private(set) var isSubscribed: Bool?

    init(state: SubscriptionState = .ready(MockSubscriptionGate.sampleOffers),
         isSubscribed: Bool? = nil) {
        self.state = state
        self.isSubscribed = isSubscribed
    }

    /// Placeholders, but not arbitrary ones: they match what App Store
    /// Connect actually charges. Every review artifact - the contact sheet,
    /// the screenshots Apple asks for alongside each subscription - is drawn
    /// from these, and a capture that quotes a price the store does not
    /// charge is a document that has to be explained rather than read.
    static let sampleOffers: [SubscriptionOffer] = [
        SubscriptionOffer(id: "exhale.yearly", term: .yearly,
                          localisedPrice: "€19.99", localisedPricePerMonth: "€1.67",
                          amount: 19.99, currencyCode: "EUR",
                          hasFreeTrial: true, trialDays: 7),
        SubscriptionOffer(id: "exhale.monthly", term: .monthly,
                          localisedPrice: "€2.99", localisedPricePerMonth: nil,
                          // No trial claimed here until App Store Connect is
                          // seen to offer one on the monthly product too.
                          amount: 2.99, currencyCode: "EUR",
                          hasFreeTrial: false, trialDays: 0)
    ]

    /// The same two offers with the free week taken off, which is what
    /// someone who has already used it is actually shown.
    static let usedTrialOffers: [SubscriptionOffer] = sampleOffers.map {
        SubscriptionOffer(id: $0.id, term: $0.term,
                          localisedPrice: $0.localisedPrice,
                          localisedPricePerMonth: $0.localisedPricePerMonth,
                          amount: $0.amount, currencyCode: $0.currencyCode,
                          hasFreeTrial: false, trialDays: 0)
    }

    func load() async {}
    func purchase(_ offer: SubscriptionOffer) async -> Bool { isSubscribed = true; return true }
    func restore() async -> Bool { isSubscribed == true }
}

/// The real implementation, wired to RevenueCat.
///
/// Deliberately thin: RevenueCat owns entitlements and receipt validation, and
/// this only translates its types into `SubscriptionOffer`. The key is read
/// from Info.plist, which xcodegen fills from the REVENUECAT_KEY environment
/// variable, which CI fills from a repository secret.
///
/// Every failure lands on `.unavailable` with a sentence a person could act
/// on. The paywall must never invent a price: a subscription screen that shows
/// a number the store did not supply is charging someone an amount nobody
/// agreed to, and in most of the world it would be the wrong currency as well.
@MainActor
final class RevenueCatSubscriptionGate: SubscriptionGate {
    private(set) var state: SubscriptionState = .loading
    private(set) var isSubscribed: Bool?

    private let entitlement = "premium"
    private let logger = Logger(subsystem: "com.matthias1412.exhale", category: "subscriptions")
    private var configured = false

    /// Whether this Apple Account has ever held the entitlement, active or
    /// not — which is the same question as "have they already used the free
    /// week", since the week is how everyone starts.
    ///
    /// `introductoryDiscount` describes the *product*, not the person: it
    /// keeps saying "7 days free" to someone who used their free week a year
    /// ago and cancelled. Offering it to them again is a promise the store
    /// will refuse to keep at the till.
    private var hasUsedTrial = false

    /// The load currently in flight, if any.
    ///
    /// Three places ask for this: the root at launch, the paywall when it
    /// appears, and every return from the background. Opening the app onto
    /// the paywall fires the first two within a frame of each other, and each
    /// one sets its own StoreKit product fetch going. Racing the store to
    /// answer a question it is already answering cannot make it quicker.
    private var inFlight: Task<Void, Never>?

    /// Nil when the build was made without a key, which is every local build
    /// and any CI build where the secret is missing.
    private var apiKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String
        else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // An unsubstituted build setting comes through as the literal
        // "$(REVENUECAT_KEY)", which is not a key and must not be handed to
        // the SDK as one.
        guard !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }

    private func configureIfNeeded() -> Bool {
        if configured { return true }
        guard let apiKey else { return false }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        configured = true
        return true
    }

    /// A second caller waits on the first rather than starting a second fetch.
    func load() async {
        if let inFlight { return await inFlight.value }
        let task = Task { await self.performLoad() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func performLoad() async {
        guard configureIfNeeded() else {
            state = .unavailable("Subscriptions are not set up in this build.")
            logger.error("no RevenueCat key in Info.plist; paywall disabled")
            return
        }
        // A refresh keeps the offers it already has. Dropping back to
        // `.loading` on every foreground would blank the prices mid-read and,
        // because a state that cannot sell anything does not lock, would
        // flash the whole app into view for someone locked out of it.
        if case .ready = state {} else { state = .loading }
        do {
            let info = try await Purchases.shared.customerInfo()
            isSubscribed = info.entitlements[entitlement]?.isActive == true
            // `.all`, not `.active`: a lapsed subscription still counts as
            // having been one.
            hasUsedTrial = info.entitlements.all[entitlement] != nil

            let offerings = try await Purchases.shared.offerings()
            guard let packages = offerings.current?.availablePackages, !packages.isEmpty else {
                state = .unavailable("No subscriptions are available right now.")
                logger.error("RevenueCat returned no current offering")
                return
            }
            let offers = packages.compactMap { Self.offer(from: $0, trialUsed: hasUsedTrial) }
            state = offers.isEmpty
                ? .unavailable("No subscriptions are available right now.")
                : .ready(offers.sorted { $0.term == .yearly && $1.term != .yearly })
        } catch {
            // Offline is the common case here, and it is temporary. A refresh
            // that fails keeps what the store last said; only a first load
            // with nothing cached has to admit it has nothing.
            if case .ready = state {} else {
                state = .unavailable("Could not reach the store. Check your connection.")
            }
            logger.error("offerings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func purchase(_ offer: SubscriptionOffer) async -> Bool {
        guard configureIfNeeded() else { return false }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages
                .first(where: { $0.storeProduct.productIdentifier == offer.id }) else {
                logger.error("no package for \(offer.id, privacy: .public)")
                return false
            }
            let result = try await Purchases.shared.purchase(package: package)
            // A user cancelling is an ordinary outcome, not an error.
            guard !result.userCancelled else { return false }
            isSubscribed = result.customerInfo.entitlements[entitlement]?.isActive == true
            return isSubscribed == true
        } catch {
            logger.error("purchase failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func restore() async -> Bool {
        guard configureIfNeeded() else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            isSubscribed = info.entitlements[entitlement]?.isActive == true
            return isSubscribed == true
        } catch {
            logger.error("restore failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Prices come from the store already localised. Nothing here formats a
    /// currency, and the per-month figure is divided and then handed back to
    /// the store's own formatter rather than assembled from a number and a
    /// symbol.
    private static func offer(from package: Package, trialUsed: Bool) -> SubscriptionOffer? {
        let product = package.storeProduct
        let term: SubscriptionOffer.Term
        switch package.packageType {
        case .annual: term = .yearly
        case .monthly: term = .monthly
        default: return nil
        }

        var perMonth: String?
        if term == .yearly {
            let monthly = product.price / 12
            perMonth = product.priceFormatter?.string(from: monthly as NSDecimalNumber)
        }

        // Only a genuine free trial counts. A discounted introductory price is
        // not a free week and must not be described as one.
        let intro = product.introductoryDiscount
        let isFreeTrial = intro?.paymentMode == .freeTrial && !trialUsed
        let trialDays = isFreeTrial ? (intro?.subscriptionPeriod.days ?? 0) : 0

        return SubscriptionOffer(
            id: product.productIdentifier,
            term: term,
            localisedPrice: product.localizedPriceString,
            localisedPricePerMonth: perMonth,
            amount: product.price,
            currencyCode: product.currencyCode ?? "",
            hasFreeTrial: isFreeTrial,
            trialDays: trialDays
        )
    }
}

private extension SubscriptionPeriod {
    /// Trial lengths are quoted in days on the paywall, whatever unit the
    /// store expressed them in.
    var days: Int {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return value
        }
    }
}
