import Foundation

/// The links a subscription app is required to carry, in one place so the
/// paywall and Settings cannot drift apart.
///
/// Guideline 3.1.2 asks for functional Terms of Use and Privacy Policy links
/// *inside the binary*, not only in App Store Connect metadata, alongside the
/// price and the renewal terms. Shipping without them is one of the most
/// common rejections there is, and a rejection is a slow way to find out.
enum Legal {
    /// Apple's standard EULA. Exhale has no terms of its own, and linking the
    /// standard one is exactly what Apple asks for in that case.
    static let terms = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let privacy = URL(
        string: "https://chlorinated-mustard-456.notion.site/Exhale-Privacy-Policy-3e004806c72c807b83f6e72e863b50be")!

    /// The App Store's own subscription page — where a person changes plan or
    /// cancels. Deliberately a plain URL rather than StoreKit's
    /// `manageSubscriptionsSheet`: it reaches the same screen, behaves the
    /// same whether or not a subscription is currently active, and has no
    /// sandbox quirks of its own to be surprised by on review day.
    static let manageSubscriptions = URL(
        string: "https://apps.apple.com/account/subscriptions")!

    /// Said in full, on the screen that asks for the money.
    static let renewalTerms = "Renews automatically unless you cancel at least 24 hours before the period ends. Cancel any time in Settings."
}
