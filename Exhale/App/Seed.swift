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
        price: Decimal? = nil
    ) -> QuitPlan {
        QuitPlan(
            product: product,
            amount: amount ?? product.config.defaultAmount,
            unitPrice: price ?? Currencies.defaultPrice(for: product, currency: currency),
            currencyCode: currency,
            quitDate: quitDate(day: day)
        )
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
        case "onboard-product":
            return make(phase: .onboarding) { $0.onboardingStep = 0 }

        case "onboard-product-selected":
            // Selected state: accent border, filled radio, tinted row.
            return onboarding(step: 0, product: .pouches)

        case "onboard-amount-cigarettes":
            return onboarding(step: 1, product: .cigarettes)
        case "onboard-amount-vape":
            return onboarding(step: 1, product: .vape)
        case "onboard-amount-pouches":
            return onboarding(step: 1, product: .pouches)

        case "onboard-price-cigarettes":
            return onboarding(step: 2, product: .cigarettes)
        case "onboard-price-vape":
            return onboarding(step: 2, product: .vape)

        case "onboard-quit-moment":
            return onboarding(step: 3, product: .cigarettes)

        case "paywall":
            return make(phase: .paywall, plan: plan(.cigarettes, day: 1))

        case "paywall-loading":
            // Prices not back from the store yet — placeholder, never a guess.
            return make(phase: .paywall, plan: plan(.cigarettes, day: 1),
                        subscriptions: MockSubscriptionGate(state: .loading))

        case "onboard-quit-picker":
            return onboarding(step: 3, product: .cigarettes)

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
        case "today-vape":
            // Stats row swaps "hours reclaimed" for "cravings beaten".
            return make(phase: .app, plan: plan(.vape, day: 90), cravingsWon: 12)

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
            return make(phase: .app, plan: plan(.cigarettes, day: 2), tab: .milestones)
        case "milestones-late":
            return make(phase: .app, plan: plan(.cigarettes, day: 400), tab: .milestones)

        case "settings":
            return make(phase: .app, plan: plan(.cigarettes, day: 90)) { $0.settingsOpen = true }

        // Craving SOS — one seed per breathing phase. A bug hid in step 2 of a
        // three-step overlay last time precisely because only step 1 was shot.
        case "sos-breathe-in":
            return sos(secondsIn: 100)   // 100 % 14 = 2  → "Breathe in", clock 1:40
        case "sos-hold":
            return sos(secondsIn: 103)   // 103 % 14 = 5  → "Hold it",    clock 1:43
        case "sos-let-go":
            return sos(secondsIn: 107)   // 107 % 14 = 9  → "Let it go",  clock 1:47

        case "banner-milestone":
            return make(phase: .app, plan: plan(.cigarettes, day: 3)) {
                $0.banner = BannerContent(
                    title: "72 h — Nicotine-free body",
                    body: "The nicotine itself is out of your system. It's habit now, not chemistry."
                )
            }

        case "debug-menu":
            return make(phase: .app, plan: plan(.cigarettes, day: 90)) { $0.debugMenuOpen = true }

        default:
            return nil
        }
    }

    private static func onboarding(step: Int, product: NicotineProduct) -> AppModel {
        make(phase: .onboarding) { model in
            model.onboardingStep = step
            model.draft = plan(product, day: 1)
        }
    }

    private static func sos(secondsIn: TimeInterval) -> AppModel {
        make(phase: .app, plan: plan(.cigarettes, day: 90), cravingsWon: 6) { model in
            model.sosStartedAt = referenceNow.addingTimeInterval(-secondsIn)
        }
    }
}
