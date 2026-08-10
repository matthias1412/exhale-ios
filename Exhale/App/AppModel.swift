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
    /// When this state was last written. Used only to decide which copy wins
    /// between a device and iCloud — and excluded from `==` below, so stamping
    /// it on save can't re-trigger the very save that set it.
    var updatedAt: Date = .distantPast
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
    /// Set when a start is scheduled for the future, and cleared once the user
    /// says they actually stopped.
    ///
    /// Without it the count began on the stroke of the chosen date whether or
    /// not anything happened: schedule Monday, carry on smoking, open the app
    /// on Wednesday and it read "Day 3". A streak the user never earned is
    /// worse than no streak, because the whole product is that number being
    /// true.
    ///
    /// Optional so state written before this existed still decodes. There is
    /// no custom decoder here, and a non-optional addition would throw on
    /// every saved file and take the streak with it. A missing key means no
    /// confirmation was ever pending, which is true of every plan that began
    /// immediately or was backdated.
    var awaitingStart: Bool?

    static func == (a: Self, b: Self) -> Bool {
        a.phase == b.phase && a.plan == b.plan
            && a.cravingsWon == b.cravingsWon
            && a.notifyMilestones == b.notifyMilestones
            && a.notifyWeeklyBill == b.notifyWeeklyBill
            && a.notifyMorningCheckIn == b.notifyMorningCheckIn
            && a.reasons == b.reasons && a.reasonName == b.reasonName
            && a.lastCelebratedHours == b.lastCelebratedHours
            && a.pastAttempts == b.pastAttempts && a.slips == b.slips
    }
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
    /// Whether iOS has actually granted permission. The scheduled-notification
    /// chips claimed an alert was coming regardless, which is a promise the app
    /// cannot keep once permission is denied.
    var notificationsAuthorised = false
    /// A milestone crossed while the app was closed, waiting to be revealed.
    var pendingCelebration: Milestone?
    /// Screenshot-harness only: pins the celebration animation to a point in
    /// 0…1 so its frames can be captured rather than only its end state.
    var celebrationFrame: Double?
    /// Screenshot-harness only: same idea for the spiral's arrival, which is
    /// otherwise only ever captured in its finished state.
    var spiralRevealFrame: Double?
    /// Screenshot-harness only: dismisses the celebration on a timer, because
    /// the recorder cannot tap.
    var celebrationAutoDismissAfter: TimeInterval?
    /// The day whose dot the spiral is holding back so the celebration can
    /// deliver it. Nil unless a celebration is queued *and* the arrival is
    /// going to play — withholding a dot from a spiral already on screen would
    /// just look like one vanishing.
    var withheldDay: Int?
    /// The arrival has finished, so a queued celebration may appear.
    ///
    /// Without this the celebration opens on top of the arrival and the whole
    /// point — watching the streak build to one dot short, then being handed
    /// the last one — never happens. It is armed rather than timed, because
    /// the arrival's length depends on the streak.
    var arrivalFinished = false
    /// Screenshot-harness only: run animations in real time even though the
    /// clock is frozen. A frozen clock is what makes stills reproducible, but
    /// it is also what stops anything time-driven from moving — so a recording
    /// of a seeded run would otherwise be a still that lasts ten seconds.
    var motionCapture = false
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
    private let cloud = CloudMirror()
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

    /// Normal launch: whichever of disk and iCloud was written last.
    ///
    /// A reinstall finds nothing on disk and everything in iCloud, which is the
    /// case this exists for.
    static func loaded() -> AppModel {
        let store = StateStore.applicationSupport
        let restored = CloudMirror.newer(store.load(), CloudMirror().load())
        return AppModel(state: restored ?? PersistedState(), store: store)
    }

    /// Wipes local and iCloud state and returns to onboarding.
    ///
    /// Restoring across a reinstall is deliberate, but without this there was
    /// no way back to a clean slate at all — deleting the app just restored it
    /// again, which is baffling if you actually wanted to start over.
    func resetEverything() {
        state = PersistedState()
        draft = nil
        onboardingStep = 0
        tab = .today
        hasRevealedSpiral = false
        pendingCelebration = nil
        withheldDay = nil
        arrivalFinished = false
        cloud.clear()
        persist()
    }

    /// Called from a single `.onChange(of: model.state)` at the root, so no
    /// mutation site has to remember to save. Seeded runs never write.
    func persist() {
        guard persistenceEnabled else { return }
        state.updatedAt = Date()
        store.save(state)
        cloud.save(state)
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
        // Only the most recent is celebrated even when several were crossed —
        // four bursts in a row after a fortnight away would cheapen all of
        // them. The rest are still marked in the spiral.
        guard let latest = unseen.last else { return }
        pendingCelebration = latest
        state.lastCelebratedHours = latest.hours
        tab = .today
        withheldDay = withholdable(latest)
        // If the arrival is not going to play — the spiral is already on
        // screen, or motion is off — there is nothing to wait for, so arm the
        // celebration now. Missing this is how the celebration would never
        // appear at all for someone who crossed a milestone mid-session.
        arrivalFinished = (withheldDay == nil)
    }

    /// Which dot, if any, the spiral should hold back for this celebration.
    ///
    /// Nil in every case where withholding would misfire:
    ///
    /// - the arrival has already played this session, so the spiral is on
    ///   screen and a dot would visibly disappear;
    /// - the milestone lands on day 1 of a one-day streak, where holding the
    ///   only dot back leaves an empty disc;
    /// - the day is somehow outside the streak, which should not happen but
    ///   would otherwise silently withhold nothing and never re-appear.
    ///
    /// A milestone crossed days ago is fine: its dot sits mid-spiral rather
    /// than at the end, the arrival draws every dot except that one, and the
    /// burst delivers it into the gap it left.
    private func withholdable(_ milestone: Milestone) -> Int? {
        guard !hasRevealedSpiral, let progress else { return nil }
        let day = Int((milestone.hours / 24).rounded(.down)) + 1
        guard day >= 1, day <= progress.dayNumber else { return nil }
        guard progress.dayNumber > 1 else { return nil }
        return day
    }

    /// The scheduled moment has arrived but the user has not yet said whether
    /// they went through with it.
    var awaitingStartConfirmation: Bool {
        guard let plan = state.plan else { return false }
        return (state.awaitingStart ?? false) && plan.quitDate <= clock.now
    }

    /// They stopped when they said they would.
    func confirmStart(at date: Date? = nil) {
        guard var plan = state.plan else { return }
        if let date { plan.quitDate = date }
        state.plan = plan
        state.awaitingStart = false
        // Anything crossed between the scheduled moment and confirming is not
        // celebrated: they were not using the app for it.
        let elapsed = clock.now.timeIntervalSince(plan.quitDate) / 3600
        if elapsed > 0 { state.lastCelebratedHours = elapsed }
    }

    /// They did not, and want a new date.
    func rescheduleStart(to date: Date) {
        guard var plan = state.plan else { return }
        plan.quitDate = date
        state.plan = plan
        state.awaitingStart = date > clock.now
        state.lastCelebratedHours = 0
    }

    /// Days carrying a milestone, for marking them in the spiral.
    var milestoneDays: Set<Int> {
        guard let plan = state.plan else { return [] }
        return SpiralGeometry.milestoneDays(
            hours: Milestones.forProduct(plan.product).map(\.hours)
        )
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
