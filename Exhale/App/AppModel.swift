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
final class AppModel {

    /// Persisted. Written to disk by `persist()` rather than a `didSet` — the
    /// `@Observable` macro rewrites stored properties into computed accessors,
    /// and property observers on them are not something to rely on.
    var state: PersistedState

    // Ephemeral — never written to disk
    var tab: MainTab = .today
    var settingsOpen = false
    var debugMenuOpen = false
    var sosStartedAt: Date?
    var banner: BannerContent?
    var onboardingStep = 0
    /// Draft plan being assembled during onboarding.
    var draft: QuitPlan?

    let clock: AppClock
    private let store: StateStore
    private let persistenceEnabled: Bool

    init(
        state: PersistedState = PersistedState(),
        clock: AppClock = AppClock(),
        store: StateStore = .applicationSupport,
        persistenceEnabled: Bool = true
    ) {
        self.state = state
        self.clock = clock
        self.store = store
        self.persistenceEnabled = persistenceEnabled
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

    var progress: Progress? {
        state.plan.map { Progress(plan: $0, now: clock.now) }
    }

    /// "Day 90 of your quit, 1,350 cigarettes avoided" — what VoiceOver reads
    /// instead of ninety unlabelled dots.
    var spiralAccessibilitySummary: String {
        guard let plan = state.plan, let p = progress else { return "Your quit spiral" }
        let units = p.unitsAvoided.formatted(.number)
        return "Day \(p.dayNumber) of your quit, \(units) \(plan.config.unitNoun) avoided"
    }
}

struct BannerContent: Equatable, Sendable {
    let title: String
    let body: String
}
