import SwiftUI

// MARK: - Today (real — the spiral is the product, so it lands first)

struct TodayScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let progress = model.progress {
                ZStack {
                    SpiralView(
                        day: progress.dayNumber,
                        accessibilitySummary: model.spiralAccessibilitySummary
                    )
                    SpiralCentreLabel(day: progress.dayNumber)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)

                if progress.dayNumber > 120 {
                    Text("\(progress.dayNumber.formatted(.number)) days — one dot each")
                        .font(.spaceGrotesk(11))
                        .tracking(0.66)
                        .foregroundStyle(Palette.textFaint)
                        .padding(.bottom, 10)
                }

                StatsRow(progress: progress)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                CravingButton()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
            }
        }
    }
}

struct StatsRow: View {
    @Environment(AppModel.self) private var model
    let progress: QuitProgress

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(stats, id: \.label) { stat in
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.value)
                        .font(.spaceGrotesk(21, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accentSoft)
                    Text(stat.label)
                        .font(.spaceGrotesk(11))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var stats: [(value: String, label: String)] {
        guard let plan = model.plan else { return [] }
        let third: (String, String) = plan.product == .cigarettes
            ? ("\(progress.hoursReclaimed.formatted(.number)) h", "of life reclaimed")
            : ("\(model.state.cravingsWon)", "cravings beaten")
        return [
            (progress.moneyKept.moneyString(plan.currencyCode), "kept in your pocket"),
            (progress.unitsAvoided.formatted(.number),
             "\(progress.unitsAvoided == 1 ? plan.config.unitNounSingular : plan.config.unitNoun) avoided"),
            third
        ]
    }
}

struct CravingButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.sosStartedAt = model.clock.now
        } label: {
            Text("I'm craving — help me through it")
                .font(.spaceGrotesk(16, weight: .medium))
                .foregroundStyle(Palette.emberSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Palette.ember.opacity(0.12))
                        .overlay(Capsule().stroke(Palette.ember.opacity(0.65), lineWidth: 1.5))
                )
        }
    }
}

// MARK: - Craving SOS (breathing logic real, visuals to be finished)

struct CravingSOSScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 4s in, 4s hold, 6s out.
    private static let cycle: Double = 14

    var body: some View {
        let elapsed = model.sosStartedAt.map { model.clock.now.timeIntervalSince($0) } ?? 0
        let phasePosition = elapsed.truncatingRemainder(dividingBy: Self.cycle)

        ZStack {
            Palette.cravingOverlay.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("CRAVING · \(clockString(elapsed))")
                    .font(.spaceGrotesk(13, weight: .medium))
                    .tracking(3.12)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .padding(.top, 20)

                Spacer()

                BreathingOrb(phasePosition: phasePosition, reduceMotion: reduceMotion)
                    .frame(width: 240, height: 240)

                Spacer()

                Text("Most cravings die in under 3 minutes.\nYou only have to outlast this one.")
                    .font(.spaceGrotesk(14.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundStyle(Palette.textMuted)
                    .frame(maxWidth: 270)

                VStack(spacing: 12) {
                    Button {
                        model.state.cravingsWon += 1
                        model.sosStartedAt = nil
                    } label: {
                        Text("It passed — I'm okay")
                            .font(.spaceGrotesk(16, weight: .bold))
                            .foregroundStyle(Palette.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Palette.accent))
                    }
                    Button("Back") { model.sosStartedAt = nil }
                        .font(.spaceGrotesk(13))
                        .foregroundStyle(Palette.textFaint)
                }
                .padding(.top, 28)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }

    private func clockString(_ elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

struct BreathingOrb: View {
    let phasePosition: Double
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Palette.accent.opacity(0.25), lineWidth: 1.5)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.accent.opacity(0.5), Palette.accent.opacity(0.12)],
                        center: UnitPoint(x: 0.5, y: 0.42),
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(reduceMotion ? 1 : scale)
                .overlay(
                    Text(label)
                        .font(.spaceGrotesk(17, weight: .medium))
                        .foregroundStyle(Palette.textBrightest)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// 0–4s in, 4–8s hold, 8–14s out — matching the phase label exactly.
    private var scale: Double {
        switch phasePosition {
        case ..<4: 0.7 + 0.3 * (phasePosition / 4)
        case ..<8: 1.0
        default: 1.0 - 0.3 * ((phasePosition - 8) / 6)
        }
    }

    var label: String {
        switch phasePosition {
        case ..<4: "Breathe in"
        case ..<8: "Hold it"
        default: "Let it go"
        }
    }
}

// MARK: - Not yet built
//
// Placeholders so routing and the screenshot harness are verifiable from day
// one. Each is replaced by the real screen in build order:
// Bill → Milestones → Settings → Onboarding → Paywall.

struct NotificationBanner: View {
    @Environment(AppModel.self) private var model
    let content: BannerContent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            LogoMark(size: 26)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 9).fill(Palette.bannerIconTile))

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(content.title)
                        .font(.spaceGrotesk(13, weight: .bold))
                    Spacer()
                    Text("now")
                        .font(.spaceGrotesk(11))
                        .foregroundStyle(Palette.textFaint)
                }
                Text(content.body)
                    .font(.spaceGrotesk(12.5))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Palette.bannerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Palette.textPrimary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 17, y: 12)
        )
        .onTapGesture { model.banner = nil }
    }
}

struct ScreenStub: View {
    let name: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.spaceGrotesk(22, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.spaceGrotesk(13))
                    .foregroundStyle(Palette.textMuted)
            }
            Text("not built yet")
                .font(.spaceGrotesk(11))
                .tracking(1.5)
                .foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
