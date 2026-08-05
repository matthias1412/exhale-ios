import SwiftUI

/// The quit spiral. One dot per smoke-free day.
///
/// Drawn with `Canvas`, not a stack of views — at five years this is 1,825 dots
/// and it has to stay smooth while the money counter ticks beside it.
struct SpiralView: View {
    let day: Int
    /// Days on which a milestone was reached, so those dots are marked for
    /// good rather than the moment vanishing with the celebration.
    var milestoneDays: Set<Int> = []
    /// Spoken instead of the dots, which are meaningless one at a time.
    let accessibilitySummary: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model

    @State private var revealStart: Date?
    @State private var isRevealing = true

    /// Total time for the spiral to arrive.
    private let revealDuration: Double = 1.1
    /// Fraction of that time any single dot spends fading in.
    private let dotFadeWindow: Double = 0.25

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / SpiralGeometry.box

            TimelineView(.animation(
                paused: !isRevealing || reduceMotion || model.spiralRevealFrame != nil
            )) { timeline in
                Canvas { context, _ in
                    draw(in: &context, scale: scale, progress: progress(at: timeline.date))
                }
                .frame(width: side, height: side)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
        // Keyed on whether a celebration is up. Opening the app on the day you
        // cross a milestone fired both at once: the spiral arrived underneath
        // an opaque full-screen celebration, and by the time that was dismissed
        // `hasRevealedSpiral` was already true, so the spiral was simply there.
        // The one launch where the animation matters most was the one launch
        // that never showed it. Now it waits, and the dots arrive into a screen
        // the user has just been told is a milestone — landing on the dot that
        // marks it.
        .task(id: model.pendingCelebration == nil) {
            guard model.pendingCelebration == nil else { return }
            // Once per session. Switching tabs recreates this view, and
            // replaying the arrival every time made a considered animation feel
            // like a glitch.
            guard !reduceMotion, !model.hasRevealedSpiral else {
                isRevealing = false
                return
            }
            model.hasRevealedSpiral = true
            revealStart = .now
            try? await Task.sleep(for: .seconds(revealDuration + 0.1))
            isRevealing = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Reveal

    private func progress(at date: Date) -> Double {
        if let frozen = model.spiralRevealFrame { return frozen }
        guard !reduceMotion, let start = revealStart else { return 1 }
        return min(1, max(0, date.timeIntervalSince(start) / revealDuration))
    }

    /// Oldest dot first, rippling outward to today.
    ///
    /// Day one is the special case: with a single dot there is nothing to
    /// stagger, and the old guard returned "already finished", so the most
    /// important screen in the app — the one someone sees the moment they
    /// commit — was the only one that didn't animate. A lone dot gets the whole
    /// window to arrive instead.
    private func dotProgress(index: Int, of count: Int, overall: Double) -> Double {
        guard overall < 1 else { return 1 }
        let window = count > 1 ? dotFadeWindow : 1
        let start = count > 1
            ? (Double(index) / Double(count - 1)) * (1 - dotFadeWindow)
            : 0
        let local = min(1, max(0, (overall - start) / window))
        // ease-out so dots settle rather than snap
        return 1 - pow(1 - local, 3)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, scale: CGFloat, progress overall: Double) {
        let dots = SpiralGeometry.dots(forDay: day, milestoneDays: milestoneDays)
        guard !dots.isEmpty else { return }

        var glowing: [(SpiralGeometry.Dot, Double)] = []

        for (i, dot) in dots.enumerated() {
            let p = dotProgress(index: i, of: dots.count, overall: overall)
            guard p > 0 else { continue }
            if dot.isNewest || dot.isYearMarker || dot.isMilestone {
                glowing.append((dot, p))
                continue
            }
            fill(dot, progress: p, in: &context, scale: scale)
        }

        // Glowing dots go in their own layer so the shadow filter is applied
        // a handful of times, not eighteen hundred.
        for (dot, p) in glowing {
            // A milestone dot glows in its own colour but more quietly than
            // today's dot or a year marker — it is a record, not an alert.
            let colour: Color = dot.isNewest ? Palette.accent
                              : (dot.isYearMarker ? Palette.yearMarker
                                                  : Palette.spiralDot(ramp: dot.ramp))
            let radius: CGFloat = dot.isNewest ? 16 : (dot.isYearMarker ? 8 : 6)
            let baseGlow = dot.isNewest ? 0.5 : (dot.isYearMarker ? 0.7 : 0.45)
            let glowOpacity = baseGlow * p
            context.drawLayer { layer in
                layer.addFilter(
                    .shadow(color: colour.opacity(glowOpacity), radius: radius * scale)
                )
                fill(dot, progress: p, in: &layer, scale: scale)
            }
        }
    }

    private func fill(
        _ dot: SpiralGeometry.Dot,
        progress p: Double,
        in context: inout GraphicsContext,
        scale: CGFloat
    ) {
        // Dots arrive slightly small and settle to full size.
        let diameter = dot.diameter * scale * (0.6 + 0.4 * p)

        // ...and arrive from slightly inboard, drifting out into place. Fading
        // in on the spot reads as materialising; travelling the last few points
        // outward reads as the spiral growing, which is what it is. The offset
        // is deliberately small — a couple of points at most — because at this
        // dot density anything larger turns into visible churn.
        let centre = SpiralGeometry.centre
        let dx = dot.position.x - centre.x
        let dy = dot.position.y - centre.y
        let travel = 1 - 0.055 * (1 - p)
        let x = (centre.x + dx * travel) * scale
        let y = (centre.y + dy * travel) * scale

        let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2,
                          width: diameter, height: diameter)

        // A brief lift as each dot lands, decaying to nothing — an ember
        // catching rather than a light switching on. Done as brightness rather
        // than a shadow filter: a filter per dot would mean eighteen hundred
        // layers, and this costs nothing.
        // Year markers already carry their own glow, so only ordinary dots
        // get the flash — doubling up would make them strobe.
        let flash = p >= 1 ? 0 : sin(min(1, max(0, (p - 0.45) / 0.55)) * .pi) * 0.22
        let colour = dot.isYearMarker
            ? Palette.yearMarker
            : Palette.spiralDot(ramp: dot.ramp, lift: flash)

        context.fill(Path(ellipseIn: rect), with: .color(colour.opacity(p)))

        // A milestone reads as a bright core inside its own dot. Size cannot do
        // this job — below roughly day 174 every dot is already at the clamp —
        // and a ring would overlap its neighbours once the spiral is dense.
        if dot.isMilestone && !dot.isYearMarker {
            let inner = diameter * 0.42
            let core = CGRect(x: x - inner / 2, y: y - inner / 2,
                              width: inner, height: inner)
            context.fill(
                Path(ellipseIn: core),
                with: .color(Palette.spiralDot(ramp: dot.ramp, lift: 0.3).opacity(p))
            )
        }
    }
}

/// The centre label, sitting on the radial veil so inner dots don't collide
/// with the numeral. The veil shrinks with the bloom — see `SpiralGeometry`.
struct SpiralCentreLabel: View {
    let day: Int

    private var years: Int { day / 365 }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / SpiralGeometry.box
            let veil = SpiralGeometry.veil(day: day)

            VStack(spacing: 0) {
                Text(overline)
                    .font(.spaceGrotesk(11, weight: .medium))
                    .tracking(3.3)
                    .foregroundStyle(Palette.textMuted)
                Text(value)
                    .font(.spaceGrotesk(valueSize, weight: .bold))
                    .foregroundStyle(Palette.textBrightest)
                    .monospacedDigit()
                if let sub {
                    Text(sub)
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.top, 5)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(
                RadialGradient(
                    stops: [
                        .init(color: Palette.background, location: 0),
                        .init(color: Palette.background, location: veil.solid * scale / (geo.size.width / 2)),
                        .init(color: Palette.background.opacity(0), location: veil.fade * scale / (geo.size.width / 2))
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: geo.size.width / 2
                )
            )
            .allowsHitTesting(false)
        }
    }

    private var overline: String {
        years >= 1 ? (years == 1 ? "YEAR" : "YEARS") : "DAY"
    }

    private var value: String {
        years >= 1 ? "\(years)" : "\(day)"
    }

    private var valueSize: CGFloat {
        years >= 1 ? 52 : (day > 99 ? 46 : 52)
    }

    private var sub: String? {
        guard years >= 1 else { return nil }
        let remainder = day - years * 365
        return remainder > 0 ? "+ \(remainder) days" : "to the day"
    }
}
