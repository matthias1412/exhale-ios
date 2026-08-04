import SwiftUI

/// Routes phase → screen, and layers the overlays on top.
///
/// Overlays are positioned by **layout**, never by reading `safeAreaInsets`.
/// A `GeometryReader` combined with `.ignoresSafeArea()` reports zero insets,
/// which is how overlays end up sliding under the Dynamic Island.
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            switch model.state.phase {
            case .onboarding:
                OnboardingFlow()
            case .paywall:
                PaywallScreen()
            case .app:
                MainShell()
            }

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
    }
}

/// The three-tab shell: header, content, segmented tabs.
struct MainShell: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            AppHeader()

            Group {
                switch model.tab {
                case .today: TodayScreen()
                case .bill: BillScreen()
                case .milestones: MilestonesScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                if let plan = model.plan {
                    Text("since \(plan.quitDate.formatted(.dateTime.day().month(.abbreviated)))")
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

struct TabBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                let selected = model.tab == tab
                Button {
                    model.tab = tab
                } label: {
                    Text(tab.title)
                        .font(.spaceGrotesk(13, weight: .bold))
                        .foregroundStyle(selected ? Palette.accentSoft : Palette.textFaint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            Capsule().fill(
                                selected ? Palette.accent.opacity(0.14) : .clear
                            )
                        )
                }
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
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
