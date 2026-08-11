import Foundation

/// Turns `-seed <name>` into a fully-formed `AppModel`, so every screen and
/// every *state* can be reached directly by the screenshot harness without
/// tapping through the app.
///
/// Seeded runs are deterministic: the clock is frozen at `referenceNow`, so a
/// capture taken today and one taken in six months are byte-identical and the
/// money figure never drifts between runs.
@MainActor
enum Seed {

    /// 15 June 2026, 09:41 — the traditional hour, matching the status bar
    /// override the workflow applies with `simctl status_bar`.
    static var referenceNow: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 9
        components.minute = 41
        components.second = 0
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 1_781_509_260)
    }

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel? {
        guard let index = arguments.firstIndex(of: "-seed"),
              arguments.index(after: index) < arguments.endIndex else { return nil }
        return model(named: arguments[arguments.index(after: index)])
    }

    /// Quit instant that yields exactly `day` as the day number, at 08:00 on
    /// day one, with `referenceNow` sitting at 09:41 on day `day`.
    private static func quitDate(day: Int) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceNow)
        let startOfQuitDay = calendar.date(byAdding: .day, value: -(day - 1), to: startOfToday) ?? startOfToday
        return startOfQuitDay.addingTimeInterval(8 * 3600)
    }

    private static func plan(
        _ product: NicotineProduct,
        day: Int,
        currency: String = "EUR",
        amount: Int? = nil,
        spend: Decimal? = nil
    ) -> QuitPlan {
        QuitPlan(
            product: product,
            amount: amount ?? product.config.defaultAmount,
            weeklySpend: spend ?? Self.seedSpend(for: product, currency: currency),
            currencyCode: currency,
            quitDate: quitDate(day: day)
        )
    }

    /// Weekly spend. Capture values only — the shipping app never invents one.
    private static func seedSpend(for product: NicotineProduct, currency: String) -> Decimal {
        let isk = currency == "ISK"
        switch product {
        case .cigarettes: return isk ? 9900 : 50
        case .vape:       return isk ? 6000 : 30
        case .pouches:    return isk ? 5500 : 28
        }
    }

    private static func make(
        phase: Phase,
        plan: QuitPlan? = nil,
        tab: MainTab = .today,
        cravingsWon: Int = 0,
        subscriptions: (any SubscriptionGate)? = nil,
        configure: (AppModel) -> Void = { _ in }
    ) -> AppModel {
        var state = PersistedState()
        state.phase = phase
        state.plan = plan
        state.cravingsWon = cravingsWon

        let model = AppModel(
            state: state,
            clock: AppClock(frozen: referenceNow),
            store: .ephemeral,
            persistenceEnabled: false,
            subscriptions: subscriptions ?? MockSubscriptionGate()
        )
        model.tab = tab
        configure(model)
        return model
    }

    // MARK: - Catalogue

    static func model(named name: String) -> AppModel? {
        switch name {

        // Onboarding — one seed per step, and per product where the copy differs.
        case "onboard-intro":
            return make(phase: .onboarding) { $0.onboardingStep = OnboardingStep.welcome.rawValue }

        case "onboard-product":
            return make(phase: .onboarding) { $0.onboardingStep = OnboardingStep.product.rawValue }

        case "onboard-product-selected":
            // Selected state: accent border, filled radio, tinted row.
            return onboarding(step: OnboardingStep.product.rawValue, product: .pouches)

        case "onboard-amount-cigarettes":
            return onboarding(step: OnboardingStep.amount.rawValue, product: .cigarettes)
        case "onboard-amount-vape":
            return onboarding(step: OnboardingStep.amount.rawValue, product: .vape)
        case "onboard-amount-pouches":
            return onboarding(step: OnboardingStep.amount.rawValue, product: .pouches)

        case "onboard-price-cigarettes":
            return onboarding(step: OnboardingStep.spend.rawValue, product: .cigarettes)
        case "onboard-price-vape":
            return onboarding(step: OnboardingStep.spend.rawValue, product: .vape)

        case "onboard-cravings":
            return onboarding(step: OnboardingStep.cravings.rawValue, product: .cigarettes)

        case "onboard-slips":
            return onboarding(step: OnboardingStep.slips.rawValue, product: .cigarettes)

        case "onboard-ready":
            return onboarding(step: OnboardingStep.ready.rawValue, product: .cigarettes)

        case "onboard-ready-scheduled":
            return onboarding(step: OnboardingStep.ready.rawValue, product: .cigarettes) { model in
                model.draft?.quitDate = Calendar.current.date(
                    byAdding: .day, value: 4, to: Seed.referenceNow)!
            }

        case "onboard-ready-backdated":
            return onboarding(step: OnboardingStep.ready.rawValue, product: .vape) { model in
                model.draft?.quitDate = Calendar.current.date(
                    byAdding: .day, value: -31, to: Seed.referenceNow)!
            }

        case "onboard-reminders":
            return onboarding(step: OnboardingStep.reminders.rawValue, product: .cigarettes)

        case "onboard-quit-moment":
            return onboarding(step: OnboardingStep.dayOne.rawValue, product: .cigarettes)

        case "paywall":
            return make(phase: .paywall, plan: plan(.cigarettes, day: 1))

        case "paywall-loading":
            // Prices not back from the store yet — placeholder, never a guess.
            return make(phase: .paywall, plan: plan(.cigarettes, day: 1),
                        subscriptions: MockSubscriptionGate(state: .loading))

        case "paywall-foreign-currency":
            // Store charges in EUR, habit priced in GBP. The payback comparison
            // must vanish rather than divide across currencies.
            return make(phase: .paywall,
                        plan: plan(.cigarettes, day: 1, currency: "GBP"))

        case "onboard-price-yearly":
            // The annual loss figure, which is the number that lands.
            return onboarding(step: OnboardingStep.spend.rawValue, product: .pouches)

        case "onboard-reason":
            return onboarding(step: OnboardingStep.why.rawValue, product: .cigarettes)

        case "onboard-reason-chosen":
            return onboarding(step: OnboardingStep.why.rawValue, product: .cigarettes) { model in
                var state = model.state
                state.reasons = [.someone, .money]
                state.reasonName = "Emma"
                model.state = state
            }

        case "sos-with-reason":
            return sos(secondsIn: 100) { model in
                var state = model.state
                state.reasons = [.someone]
                state.reasonName = "Emma"
                model.state = state
            }

        case "onboard-quit-time":
            // Step 4 with the time wheel open — an overlay step that was
            // previously unreachable from a seed and therefore never captured.
            return onboarding(step: OnboardingStep.dayOne.rawValue, product: .cigarettes) {
                $0.quitPickerMode = .earlierToday
            }

        case "onboard-quit-date":
            return onboarding(step: OnboardingStep.dayOne.rawValue, product: .cigarettes) {
                $0.quitPickerMode = .pickDate
            }

        // Today — the bloom across its whole range.
        case "today-day1":
            return make(phase: .app, plan: plan(.cigarettes, day: 1))
        case "today-day14":
            return make(phase: .app, plan: plan(.cigarettes, day: 14))
        case "today-day90":
            return make(phase: .app, plan: plan(.cigarettes, day: 90))
        case "today-day365":
            return make(phase: .app, plan: plan(.cigarettes, day: 365))
        case "today-day1825":
            return make(phase: .app, plan: plan(.cigarettes, day: 1825))
        case "today-day8":
            // Day 8 is the "1 week" milestone, so today's dot is a milestone
            // dot. Live rather than pinned — this is the one the recorder uses.
            return make(phase: .app, plan: plan(.cigarettes, day: 8))
        case "today-vape":
            // Stats row swaps "hours reclaimed" for "cravings beaten".
            return make(phase: .app, plan: plan(.vape, day: 90), cravingsWon: 12)

        // The arrival animation, pinned part-way through.
        //
        // Every other Today seed captures the settled spiral, so the reveal was
        // only ever verified as "it ends up right" — the shape of the ripple
        // itself, and how it reads at one dot versus eighteen hundred, was
        // never actually looked at.
        case "reveal-day1-f40":     return reveal(day: 1, frame: 0.40)
        case "reveal-day1-f75":     return reveal(day: 1, frame: 0.75)
        case "reveal-day14-f35":    return reveal(day: 14, frame: 0.35)
        case "reveal-day14-f70":    return reveal(day: 14, frame: 0.70)
        case "reveal-day90-f25":    return reveal(day: 90, frame: 0.25)
        case "reveal-day90-f55":    return reveal(day: 90, frame: 0.55)
        case "reveal-day90-f85":    return reveal(day: 90, frame: 0.85)
        case "reveal-day365-f50":   return reveal(day: 365, frame: 0.50)
        case "reveal-day1825-f45":  return reveal(day: 1825, frame: 0.45)
        case "reveal-day1825-f90":  return reveal(day: 1825, frame: 0.90)

        // Today's dot is *also* a milestone dot — day 8 is "1 week", day 91 is
        // "3 months". The newest dot is already drawn at the top of the ramp
        // with its own glow, so the question is whether the milestone marking
        // survives on it at all, mid-reveal and settled.
        case "reveal-milestone-today-f60":  return reveal(day: 8, frame: 0.60)
        case "reveal-milestone-today":      return reveal(day: 8, frame: 1.0)
        case "reveal-milestone-dense-f60":  return reveal(day: 91, frame: 0.60)
        case "reveal-milestone-dense":      return reveal(day: 91, frame: 1.0)

        // The Bill
        case "bill-cigarettes":
            // 30 days ≈ 22 packs, under the 40-glyph threshold.
            return make(phase: .app, plan: plan(.cigarettes, day: 30), tab: .bill, cravingsWon: 4)
        case "bill-tally-x10":
            // 90 days ≈ 67 packs, so glyphs collapse to ×10 with a note.
            return make(phase: .app, plan: plan(.cigarettes, day: 90), tab: .bill, cravingsWon: 11)
        case "bill-vape":
            return make(phase: .app, plan: plan(.vape, day: 60), tab: .bill, cravingsWon: 7)
        case "bill-long-money":
            // A 0-decimal currency at five years — the widest the figure gets.
            return make(phase: .app, plan: plan(.cigarettes, day: 1825, currency: "ISK"), tab: .bill)

        // Milestones
        case "milestones-early":
            return make(phase: .app, plan: plan(.cigarettes, day: 2), tab: .milestones) {
                $0.notificationsAuthorised = true
            }

        case "milestones-notifications-denied":
            // No "notification scheduled" chip — we cannot keep that promise.
            return make(phase: .app, plan: plan(.cigarettes, day: 2), tab: .milestones)

        case "slip-backdated":
            return make(phase: .app, plan: plan(.cigarettes, day: 62)) {
                $0.slipSheetOpen = true
            }
        case "onboard-price-empty":
            // Continue must stay disabled until a price is entered.
            return onboarding(step: OnboardingStep.spend.rawValue, product: .cigarettes) { model in
                model.draft?.weeklySpend = 0
            }

        case "milestones-late":
            return make(phase: .app, plan: plan(.cigarettes, day: 400), tab: .milestones)

        case "settings":
            return make(phase: .app, plan: plan(.cigarettes, day: 90)) { $0.settingsOpen = true }

        // Craving SOS — one seed per breathing phase. A bug hid in step 2 of a
        // three-step overlay last time precisely because only step 1 was shot.
        // The cycle is 11s now — 4 in, 1 held, 6 out — so these land at
        // 1s, 4s and 8s into it respectively.
        case "sos-breathe-in":
            return sos(secondsIn: 100)   // 100 % 11 = 1  → "Breathe in", clock 1:40
        case "sos-hold":
            return sos(secondsIn: 103)   // 103 % 11 = 4  → "Hold it",    clock 1:43
        case "sos-let-go":
            return sos(secondsIn: 107)   // 107 % 11 = 8  → "Let it go",  clock 1:47
        case "sos-live":
            return sos(secondsIn: 97, live: true)

        case "banner-milestone":
            return make(phase: .app, plan: plan(.cigarettes, day: 3)) {
                $0.banner = BannerContent(
                    title: "72 h · Nicotine-free body",
                    body: "The nicotine itself is out of your system. It's habit now, not chemistry."
                )
            }

        case "slip-sheet":
            return make(phase: .app, plan: plan(.cigarettes, day: 62)) {
                $0.slipSheetOpen = true
            }

        case "today-after-relapse":
            // A fresh day 1 that still remembers a 62-day run.
            return make(phase: .app, plan: plan(.cigarettes, day: 1)) { model in
                var state = model.state
                state.pastAttempts = [
                    QuitAttempt(started: quitDate(day: 1).addingTimeInterval(-62 * 86_400),
                                ended: quitDate(day: 1))
                ]
                model.state = state
            }

        case "pre-quit-countdown":
            // Quit day set three days out — no spiral yet, and we don't fake one.
            return make(phase: .app) { model in
                var state = model.state
                var future = plan(.cigarettes, day: 1)
                future.quitDate = Calendar.current.date(
                    byAdding: .day, value: 3,
                    to: Calendar.current.startOfDay(for: referenceNow)
                ) ?? referenceNow
                state.plan = future
                model.state = state
            }

        // The scheduled day arrived and nobody has said whether it happened.
        case "awaiting-start":
            return make(phase: .app) { model in
                var state = model.state
                var p = plan(.cigarettes, day: 1)
                p.quitDate = Calendar.current.date(
                    byAdding: .day, value: -2,
                    to: Calendar.current.startOfDay(for: referenceNow)
                ) ?? referenceNow
                state.plan = p
                state.awaitingStart = true
                model.state = state
            }

        case "today-imminent-milestone":
            // ~6 hours short of the 72h mark, so the near-miss nudge shows.
            return make(phase: .app) { model in
                var state = model.state
                var p = plan(.cigarettes, day: 3)
                p.quitDate = referenceNow.addingTimeInterval(-66 * 3600)
                state.plan = p
                model.state = state
            }

        case "milestone-celebration":
            return celebration(frame: nil)
        case "milestone-celebration-f20":
            return celebration(frame: 0.20)
        case "milestone-celebration-f45":
            return celebration(frame: 0.45)
        case "milestone-celebration-f70":
            return celebration(frame: 0.70)
        // For the recorder: burst runs, dismisses itself, spiral arrives behind
        // it and lands on the dot the burst was about. One per milestone,
        // because the burst colour, the wording and — crucially — how dense
        // the spiral is behind it are completely different at 72 hours and at
        // a year.
        case "celebration-handoff":       return handoff("1 week")
        case "handoff-72h":               return handoff("72 h")
        case "handoff-2weeks":            return handoff("2 weeks")
        case "handoff-1month":            return handoff("1 month")
        case "handoff-3months":           return handoff("3 months")
        case "handoff-1year":             return handoff("1 year")
        case "handoff-5years":            return handoff("5 years")

        // The arrival with the milestone's dot held back, so the celebration
        // has something to deliver. Day 8's dot is missing and the numeral
        // stops at 7 — the burst hands over both.
        case "withheld-today-f70":  return withheld(milestone: "1 week", day: 8, frame: 0.70)
        case "withheld-today":      return withheld(milestone: "1 week", day: 8, frame: 1.0)
        // Crossed three days ago: the held dot sits mid-spiral rather than at
        // the end, and the count runs all the way to today regardless.
        case "withheld-passed":     return withheld(milestone: "1 week", day: 11, frame: 1.0)

        case "debug-menu":
            return make(phase: .app, plan: plan(.cigarettes, day: 90)) { $0.debugMenuOpen = true }

        default:
            return nil
        }
    }

    private static func onboarding(
        step: Int,
        product: NicotineProduct,
        configure: @escaping (AppModel) -> Void = { _ in }
    ) -> AppModel {
        make(phase: .onboarding) { model in
            model.onboardingStep = step
            model.draft = plan(product, day: 1)
            configure(model)
        }
    }

    /// `frame` pins the spiral's arrival at a point in 0…1.
    private static func reveal(day: Int, frame: Double) -> AppModel {
        make(phase: .app, plan: plan(.cigarettes, day: day)) { model in
            model.spiralRevealFrame = frame
        }
    }

    /// `frame` pins the burst animation so a still can be inspected.
    private static func celebration(frame: Double?, autoDismissAfter: TimeInterval? = nil) -> AppModel {
        make(phase: .app, plan: plan(.cigarettes, day: 8)) { model in
            model.pendingCelebration = Milestones.all.first { $0.when == "1 week" }
            model.celebrationFrame = frame
            model.celebrationAutoDismissAfter = autoDismissAfter
        }
    }

    /// The spiral one dot short, waiting for the celebration to hand it over.
    private static func withheld(milestone when: String, day: Int, frame: Double) -> AppModel? {
        guard let mile = Milestones.forProduct(.cigarettes).first(where: { $0.when == when })
        else { return nil }
        return make(phase: .app, plan: plan(.cigarettes, day: day)) { model in
            model.pendingCelebration = mile
            model.withheldDay = Int((mile.hours / 24).rounded(.down)) + 1
            model.spiralRevealFrame = frame
        }
    }

    /// What you get for tapping the notification: the burst for the milestone
    /// you just crossed, dismissing itself, and the spiral for that many days
    /// arriving behind it.
    private static func handoff(_ when: String) -> AppModel? {
        guard let milestone = Milestones.forProduct(.cigarettes).first(where: { $0.when == when })
        else { return nil }
        let day = Int((milestone.hours / 24).rounded(.down)) + 1
        return make(phase: .app, plan: plan(.cigarettes, day: day)) { model in
            model.pendingCelebration = milestone
            model.celebrationAutoDismissAfter = 3.2
        }
    }

    private static func sos(
        secondsIn: TimeInterval,
        live: Bool = false,
        configure: @escaping (AppModel) -> Void = { _ in }
    ) -> AppModel {
        make(phase: .app, plan: plan(.cigarettes, day: 90), cravingsWon: 6) { model in
            // A live orb has to measure from real time, not the frozen
            // reference — anchoring to June would put the craving weeks long.
            model.sosStartedAt = (live ? Date() : referenceNow)
                .addingTimeInterval(-secondsIn)
            model.motionCapture = live
            configure(model)
        }
    }
}
