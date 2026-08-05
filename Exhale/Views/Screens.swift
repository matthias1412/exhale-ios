import SwiftUI

// MARK: - Today (real — the spiral is the product, so it lands first)

struct TodayScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let progress = model.progress, !progress.hasStarted {
                PreQuitView(progress: progress)
            } else if let progress = model.progress {
                ZStack {
                    SpiralView(
                        day: progress.dayNumber,
                        milestoneDays: model.milestoneDays,
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

                if let plan = model.plan,
                   let soon = Milestones.imminent(
                       for: plan.product, hoursElapsed: progress.hoursElapsed
                   ) {
                    ImminentMilestoneNote(
                        milestone: soon.milestone, hoursAway: soon.hoursAway
                    )
                    .padding(.bottom, 12)
                }

                // The money has to move on its own — see LiveProgress.
                if let plan = model.plan {
                    LiveProgress(plan: plan, clock: model.clock) { live in
                        StatsRow(progress: live)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                CravingButton()
                    .padding(.horizontal, 24)

                SlipLink()
                    // Clearance for the floating tab bar, which now sits over
                    // the content rather than below it.
                    .padding(.bottom, 62)
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

                BreathingOrb(phasePosition: phasePosition, reduceMotion: reduceMotion, elapsed: elapsed)
                    .frame(width: 240, height: 240)

                Spacer()

                if let reason = model.state.reasons.primary {
                    // Their own stated reason, handed back at the moment it is
                    // hardest to remember. A self-chosen goal recalled under
                    // temptation is a commitment device; "stay strong" is not.
                    Text(reason.affirmation(name: model.state.reasonName))
                        .font(.spaceGrotesk(15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .foregroundStyle(Palette.accentSoft)
                        .frame(maxWidth: 280)
                        .padding(.bottom, 14)
                }

                // Self-efficacy — believing you can actually do the thing — is
                // among the strongest predictors of staying stopped, and the
                // count of cravings already outlasted is direct evidence of it.
                // It was sitting on The Bill, where nobody mid-craving looks.
                if model.state.cravingsWon > 0 {
                    Text("You've outlasted \(model.state.cravingsWon) of these.")
                        .font(.spaceGrotesk(13.5, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.bottom, 10)
                }

                Text("Most cravings die in under 3 minutes.\nYou only have to outlast this one.")
                    .font(.spaceGrotesk(14.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundStyle(Palette.textMuted)
                    .frame(maxWidth: 270)

                VStack(spacing: 12) {
                    Button {
                        Feedback.cravingBeaten()
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
    /// Drives the shader. Separate from `phasePosition` so the shimmer keeps
    /// drifting through the hold, when the orb itself is nearly still.
    var elapsed: Double = 0

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
                // A caustic drift across the surface, so breath looks like it
                // moves *through* the orb rather than just resizing it. Off
                // entirely under Reduce Motion.
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.orbShimmer(
                            .float2(proxy.size),
                            .float(reduceMotion ? 0 : elapsed),
                            .float(reduceMotion ? 0 : 0.055)
                        )
                    )
                }
                .scaleEffect(reduceMotion ? 1 : scale)
                .shadow(color: Palette.accent.opacity(reduceMotion ? 0.2 : 0.35),
                        radius: reduceMotion ? 30 : glowRadius)
                .overlay(
                    Text(label)
                        .font(.spaceGrotesk(17, weight: .medium))
                        .foregroundStyle(Palette.textBrightest)
                        .id(label)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.45), value: label)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// 0–4s in, 4–8s hold, 8–14s out.
    ///
    /// Eased, not linear. A linear scale reads as a machine and is genuinely
    /// harder to breathe along with — real breath accelerates then slows.
    /// The inhale eases *out* (quick off the mark, settling at the top, which
    /// is how a full lung feels) and the exhale eases *in and out* so the long
    /// six seconds don't feel like a stall.
    private var scale: Double {
        let low = 0.68, high = 1.0
        switch phasePosition {
        case ..<4:
            let t = phasePosition / 4
            return low + (high - low) * (1 - pow(1 - t, 2.2))
        case ..<8:
            // Not perfectly still: a held breath is not a frozen one.
            let t = (phasePosition - 4) / 4
            return high + sin(t * .pi) * 0.012
        default:
            let t = (phasePosition - 8) / 6
            return high - (high - low) * (t < 0.5
                ? 2 * t * t
                : 1 - pow(-2 * t + 2, 2) / 2)
        }
    }

    /// The glow tightens as the lungs fill, which gives the orb some weight
    /// rather than it just being a circle that changes size.
    private var glowRadius: Double { 46 - (scale - 0.68) / 0.32 * 22 }

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

/// The quiet way out. Deliberately understated and placed below the craving
/// button — someone who has already smoked doesn't need a loud button about it,
/// but they do need to find one rather than just closing the app.
struct SlipLink: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("I slipped") { model.slipSheetOpen = true }
            .font(.spaceGrotesk(12))
            .foregroundStyle(Palette.textFaint)
            .padding(.vertical, 6)
            .accessibilityHint("Record a cigarette without necessarily ending your streak")
    }
}
