import Foundation
import Observation

enum Phase: String, Codable, Sendable {
    case onboarding, paywall, app
}

enum MainTab: String, Codable, Sendable, CaseIterable {
    case today, bill, milestones

    var title: String {
        switch self {
        case .today: "Today"
        case .bill: "The Bill"
        case .milestones: "Milestones"
        }
    }
}

/// What gets written to disk. Everything else is derived or ephemeral.
struct PersistedState: Codable, Equatable, Sendable {
    var phase: Phase = .onboarding
    var plan: QuitPlan?
    var cravingsWon: Int = 0
    var notifyMilestones = true
    var notifyWeeklyBill = true
    var notifyMorningCheckIn = false
    /// Why they're quitting, in the order chosen. The first drives the
    /// personalisation — see QuitReason.
    var reasons: [QuitReason] = []
    /// Only ever set when `.someone` is chosen. Stays on the device.
    var reasonName: String?
    /// Hours-elapsed mark of the last milestone actually shown to the user.
    /// Anything past this that has since been crossed is owed to them.
    var lastCelebratedHours: Double = 0
    /// Finished runs, kept forever — see QuitAttempt for why.
    var pastAttempts: [QuitAttempt] = []
    /// Individual slips that did not end a run.
    var slips: [Slip] = []
}

/// A frozen clock in seeded runs, so screenshots are byte-identical between
/// runs and usable as store assets. Real time otherwise.
struct AppClock: Sendable {
    private let frozen: Date?
    init(frozen: Date? = nil) { self.frozen = frozen }
    var now: Date { frozen ?? Date() }
    var isFrozen: Bool { frozen != nil }
}

@Observable
@MainActor
final class AppModel {

    /// Persisted. Written to disk by `persist()` rather than a `didSet` — the
    /// `@Observable` macro rewrites stored properties into computed accessors,
    /// and property observers on them are not something to rely on.
    var state: PersistedState

    // Ephemeral — never written to disk
    var tab: MainTab = .today
    var settingsOpen = false
    var debugMenuOpen = false
    var slipSheetOpen = false
    /// The spiral's arrival animation is a first-impression, not a transition.
    /// Without this it replayed on every tab switch back to Today.
    var hasRevealedSpiral = false
    /// A milestone crossed while the app was closed, waiting to be revealed.
    var pendingCelebration: Milestone?
    /// Screenshot-harness only: pins the celebration animation to a point in
    /// 0…1 so its frames can be captured rather than only its end state.
    var celebrationFrame: Double?
    var sosStartedAt: Date?
    var banner: BannerContent?
    var onboardingStep = 0
    /// Draft plan being assembled during onboarding.
    var draft: QuitPlan?
    /// Which date picker the quit-moment step has open. Lives here rather than
    /// in @State so the screenshot harness can seed it — an overlay step that
    /// can't be captured is an overlay step that hides bugs.
    var quitPickerMode: QuitPickerMode = .none

    let clock: AppClock
    /// Behind a protocol so seeded runs and tests never touch StoreKit.
    let subscriptions: any SubscriptionGate

    private let store: StateStore
    private let persistenceEnabled: Bool

    init(
        state: PersistedState = PersistedState(),
        clock: AppClock = AppClock(),
        store: StateStore = .applicationSupport,
        persistenceEnabled: Bool = true,
        subscriptions: (any SubscriptionGate)? = nil
    ) {
        self.state = state
        self.clock = clock
        self.store = store
        self.persistenceEnabled = persistenceEnabled
        self.subscriptions = subscriptions
            ?? (clock.isFrozen ? MockSubscriptionGate() : RevenueCatSubscriptionGate())
    }

    /// Normal launch: load from disk.
    static func loaded() -> AppModel {
        let store = StateStore.applicationSupport
        return AppModel(state: store.load() ?? PersistedState(), store: store)
    }

    /// Called from a single `.onChange(of: model.state)` at the root, so no
    /// mutation site has to remember to save. Seeded runs never write.
    func persist() {
        guard persistenceEnabled else { return }
        store.save(state)
    }

    var plan: QuitPlan? { state.plan }

    var progress: QuitProgress? {
        state.plan.map { QuitProgress(plan: $0, now: clock.now) }
    }

    /// "Day 90 of your quit, 1,350 cigarettes avoided" — what VoiceOver reads
    /// instead of ninety unlabelled dots.
    /// Called on launch and on return to the foreground. Holds back at most one
    /// at a time — three celebrations in a row is a queue, not a reward.
    func claimPendingCelebration() {
        guard let plan = state.plan else { return }
        let unseen = Milestones.unseen(
            for: plan.product,
            quitDate: plan.quitDate,
            lastSeenHours: state.lastCelebratedHours,
            now: clock.now
        )
        guard let latest = unseen.last else { return }
        pendingCelebration = latest
        state.lastCelebratedHours = latest.hours
    }

    var spiralAccessibilitySummary: String {
        guard let plan = state.plan, let p = progress else { return "Your quit spiral" }
        let units = p.unitsAvoided.formatted(.number)
        return "Day \(p.dayNumber) of your quit, \(units) \(plan.config.unitNoun) avoided"
    }
}

enum QuitPickerMode: String, Sendable {
    case none, earlierToday, pickDate
}

struct BannerContent: Equatable, Sendable {
    let title: String
    let body: String
}
