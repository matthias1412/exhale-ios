import SwiftUI

/// Routes phase → screen, and layers the overlays on top.
///
/// Overlays are positioned by **layout**, never by reading `safeAreaInsets`.
/// A `GeometryReader` combined with `.ignoresSafeArea()` reports zero insets,
/// which is how overlays end up sliding under the Dynamic Island.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            Group {
                switch model.state.phase {
                case .onboarding:
                    OnboardingFlow()
                case .paywall:
                    PaywallScreen()
                case .app:
                    MainShell()
                }
            }
            // Onboarding into paywall into the app used to be three hard cuts.
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 14)),
                removal: .opacity
            ))
            .animation(.snappy(duration: 0.34), value: model.state.phase)

            if model.settingsOpen {
                SettingsScreen()
                    .transition(.opacity)
                    .zIndex(15)
            }

            if model.sosStartedAt != nil {
                CravingSOSScreen()
                    .transition(.opacity)
                    .zIndex(20)
            }

            if model.slipSheetOpen {
                SlipSheet()
                    .transition(.move(edge: .bottom))
                    .zIndex(25)
            }

            if let milestone = model.pendingCelebration, let progress = model.progress {
                MilestoneCelebration(
                    milestone: milestone,
                    dayNumber: progress.dayNumber
                ) {
                    model.pendingCelebration = nil
                }
                .transition(.opacity)
                .zIndex(35)
            }

            if model.debugMenuOpen {
                DebugMenu()
                    .transition(.opacity)
                    .zIndex(30)
            }
        }
        .overlay(alignment: .top) {
            // Sits in the safe area by layout, so it can never collide with
            // the Dynamic Island.
            if let banner = model.banner {
                NotificationBanner(content: banner)
                    .padding(.horizontal, 12)
                    .zIndex(40)
            }
        }
        .foregroundStyle(Palette.textPrimary)
        // One save point for the whole app, so no mutation site can forget.
        // The notification set is rebuilt from scratch here too: every fire
        // date derives from the quit date, so editing the plan has to move all
        // of them together.
        // The whole "a milestone passed while you were away" mechanic depends
        // on noticing when the user comes back. iOS keeps apps resident for a
        // long time, so cold-launch alone would have made this fire rarely.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !model.clock.isFrozen else { return }
            model.claimPendingCelebration()
        }
        .onChange(of: model.state) { _, newState in
            model.persist()
            guard !model.clock.isFrozen else { return }   // never during captures
            Task { await NotificationScheduler.shared.reschedule(state: newState) }
        }
        // Keyed on phase. Without the id this ran exactly once, at launch,
        // when a new user is still in .onboarding — so the guard failed and
        // notifications were never requested, never scheduled, and no
        // celebration was ever claimed until the app was relaunched. A brand
        // new user's entire first session had the notification system dead.
        .task(id: model.state.phase) {
            // Asking before the user has a plan is asking too early, and a
            // permission dialog would land in every screenshot.
            guard !model.clock.isFrozen, model.state.phase == .app else { return }
            // Deliberately does NOT request permission here. Firing the system
            // dialog seconds after the paywall is asking cold, right after
            // asking for money — and a denial is effectively permanent. It is
            // asked for on the Milestones tab instead, where the reason for it
            // is on screen.
            await NotificationScheduler.shared.reschedule(state: model.state)
            model.claimPendingCelebration()

            // A milestone crossed *while you are looking at the app* was
            // never celebrated. Claiming only happened on becoming active, so
            // the app had to be backgrounded and reopened first. Day one has
            // marks at 20 minutes and 12 hours, and a brand new user watching
            // the money tick is exactly who crosses them with the app open —
            // so the app's very first reward was the one most likely to be
            // silently swallowed.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard model.pendingCelebration == nil else { continue }
                model.claimPendingCelebration()
            }
        }
    }
}

/// The three-tab shell: header, content, segmented tabs.
struct MainShell: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()

            Group {
                // Before the quit date there is no bill and no healing — the
                // other two tabs would show a receipt for nothing and a
                // timeline that hasn't begun.
                if let progress = model.progress, !progress.hasStarted {
                    TodayScreen()
                } else {
                    switch model.tab {
                    case .today: TodayScreen()
                    case .bill: BillScreen()
                    case .milestones: MilestonesScreen()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Tabs used to cut hard between screens. Crossfade with a little
            // vertical travel reads as one surface changing rather than three
            // unrelated views being swapped.
            .transition(.opacity.combined(with: .offset(y: 8)))
            .animation(.snappy(duration: 0.26), value: model.tab)

            TabBar()
        }
    }
}

struct AppHeader: View {
    @Environment(AppModel.self) private var model
    @State private var wordmarkTaps = 0

    var body: some View {
        HStack {
            HStack(spacing: 9) {
                LogoMark(size: 26)
                Text("EXHALE")
                    .font(.spaceGrotesk(13, weight: .bold))
                    .tracking(2.86)
                    .foregroundStyle(Palette.accent)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Hidden debug menu: five taps on the wordmark.
                wordmarkTaps += 1
                if wordmarkTaps >= 5 {
                    wordmarkTaps = 0
                    model.debugMenuOpen = true
                }
            }
            .accessibilityLabel("Exhale")

            Spacer()

            HStack(spacing: 14) {
                if let plan = model.plan, let progress = model.progress {
                    // "since 18 Jun" for a date three days out is simply false.
                    Text(progress.hasStarted
                         ? "since \(plan.quitDate.formatted(.dateTime.day().month(.abbreviated)))"
                         : "from \(plan.quitDate.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textFaint)
                }
                Button {
                    model.settingsOpen = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Palette.stepperBorder, lineWidth: 1.5))
                }
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

/// The 55-dot mark. Same phyllotaxis as the spiral, no bloom, no glow.
struct LogoMark: View {
    var size: CGFloat = 26

    var body: some View {
        Canvas { context, _ in
            for dot in LogoGeometry.dots(box: size) {
                let d = dot.diameter
                let rect = CGRect(
                    x: dot.position.x - d / 2,
                    y: dot.position.y - d / 2,
                    width: d, height: d
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Palette.spiralDot(ramp: dot.ramp))
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
