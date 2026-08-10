import SwiftUI

// MARK: - Today (real — the spiral is the product, so it lands first)

struct TodayScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let progress = model.progress, !progress.hasStarted {
                PreQuitView(progress: progress)
            } else if let progress = model.progress {
                // The numeral is drawn inside SpiralView now: it counts up in
                // lockstep with the dots, and two sibling views cannot share
                // one animation clock without one lagging a frame behind.
                SpiralView(
                    day: progress.dayNumber,
                    milestoneDays: model.milestoneDays,
                    accessibilitySummary: model.spiralAccessibilitySummary,
                    withheldDay: model.withheldDay
                )
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)

                if progress.dayNumber > 120 {
                    Text("\(progress.dayNumber.formatted(.number)) days, one dot each")
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
            Text("I'm craving, help me through it")
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

    private static let pattern = BreathPattern.standard

    var body: some View {
        // The orb, the phase label and the timer all derive from elapsed time,
        // and nothing else on this screen changes — so without a timeline
        // driving re-evaluation SwiftUI had no reason to redraw. The body ran
        // once on open and the "breathing" orb sat frozen at the bottom of an
        // inhale with the clock stuck on 0:00 for the entire craving.
        if model.clock.isFrozen && !model.motionCapture {
            // Captures pin the phase from the seed instead, so a still is
            // reproducible.
            content(elapsed: elapsedSince(model.clock.now))
        } else if reduceMotion {
            // The orb doesn't move under Reduce Motion, but the elapsed clock
            // is information rather than decoration — "you have held out for
            // 2:40" is the whole point — so it still needs a tick.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                content(elapsed: elapsedSince(timeline.date))
            }
        } else {
            TimelineView(.animation) { timeline in
                content(elapsed: elapsedSince(timeline.date))
            }
        }
    }

    private func elapsedSince(_ now: Date) -> TimeInterval {
        model.sosStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
    }

    @ViewBuilder
    private func content(elapsed: TimeInterval) -> some View {
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

                BreathingOrb(elapsed: elapsed, reduceMotion: reduceMotion)
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
                        Text("It passed, I'm okay")
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

/// The breathing orb: a body of the app's own dots inside a fixed ring.
///
/// The ring never moves, so the *gap* between it and the body is what says how
/// full the breath is. That is the whole point of having a ring, and what the
/// old version missed — it had one, but a blurred gradient inside it that
/// never read against anything.
///
/// The body is 320 dots on the same phyllotaxis as the spiral and the logo,
/// shaded by a real sphere normal so it reads as curved rather than as a flat
/// disc. It is made of the app's material rather than painted to look like it.
struct BreathingOrb: View {
    /// Seconds since the craving started.
    let elapsed: Double
    let reduceMotion: Bool

    var pattern: BreathPattern = .standard

    /// Enough to read as a surface, few enough that a Canvas redraw at 120Hz
    /// stays free.
    private static let dotCount = 320
    /// Design units. The body reaches the ring at the top of the inhale.
    private static let ringRadius: Double = 104
    private static let emptyRadius: Double = 30

    private var state: (fullness: Double, phase: BreathPattern.Phase) {
        reduceMotion ? (0.72, .hold) : pattern.state(at: elapsed)
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            Text(state.phase.instruction)
                .font(.spaceGrotesk(17, weight: .medium))
                .foregroundStyle(Palette.textBrightest)
                // Crossfaded by hand rather than with .animation(value:).
                // Every frame inside a TimelineView is its own discrete update,
                // so an implicit animation on a changing value has nothing to
                // interpolate and the word would snap.
                .opacity(reduceMotion ? 1 : pattern.instructionOpacity(at: elapsed))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.phase.instruction)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let unit = min(size.width, size.height) / 240
        let fullness = state.fullness
        let radius = (Self.emptyRadius
            + fullness * (Self.ringRadius - Self.emptyRadius)) * unit

        // Halo first, so the body sits on top of its own light.
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(
                Path(ellipseIn: CGRect(x: centre.x - radius * 1.6,
                                       y: centre.y - radius * 1.6,
                                       width: radius * 3.2, height: radius * 3.2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Palette.accent.opacity(0.10 + 0.14 * fullness),
                        Palette.accent.opacity(0)
                    ]),
                    center: centre,
                    startRadius: radius * 0.75,
                    endRadius: radius * 1.6
                )
            )
        }

        // The body. Lit from up and to the left, as if the phone were held
        // under a window; the surface turns very slowly so the held breath is
        // never completely still.
        let lx = -0.45, ly = -0.55, lz = 0.70
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for i in 0..<Self.dotCount {
                let t = Double(i) / Double(Self.dotCount - 1)
                let q = t.squareRoot()                 // even areal spread
                let angle = Double(i) * SpiralGeometry.goldenAngle - 1.6
                    + (reduceMotion ? 0 : elapsed * 0.04)
                let dx = cos(angle) * q, dy = sin(angle) * q
                let z = max(0, 1 - q * q).squareRoot() // the sphere's normal
                let lambert = max(0, dx * lx + dy * ly + z * lz)
                let shade = 0.16 + 0.84 * pow(lambert, 0.9)

                let d = (0.9 + 1.9 * (1 - q * 0.6)) * (0.8 + 0.2 * fullness) * unit
                let x = centre.x + dx * radius
                let y = centre.y + dy * radius
                layer.opacity = 0.30 + 0.62 * shade
                layer.fill(
                    Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                    with: .color(Palette.orbDot(shade: shade))
                )
            }
        }

        // A rim brighter than the middle, which is what makes a disc read as a
        // sphere rather than a circle.
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(
                Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius,
                                       width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Palette.accent.opacity(0), location: 0),
                        .init(color: Palette.accentSoft.opacity(0.10 + 0.08 * fullness),
                              location: 0.82),
                        .init(color: Palette.textBrightest.opacity(0.26 + 0.20 * fullness),
                              location: 1)
                    ]),
                    center: centre,
                    startRadius: radius * 0.55,
                    endRadius: radius
                )
            )
        }

        // The fixed reference the body is read against.
        let rim = Self.ringRadius * unit
        context.stroke(
            Path(ellipseIn: CGRect(x: centre.x - rim, y: centre.y - rim,
                                   width: rim * 2, height: rim * 2)),
            with: .color(Palette.accent.opacity(0.16)),
            lineWidth: 1.5
        )
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
