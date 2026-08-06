import SwiftUI

/// The quit spiral. One dot per smoke-free day.
///
/// Drawn with `Canvas`, not a stack of views — at five years this is 1,825 dots
/// and it has to stay smooth while the money counter ticks beside it.
///
/// ## The arrival
///
/// The spiral is *counted*, not faded in. `RevealRamp` drives a day number
/// upward and each dot flies in from outside the frame as its day is called,
/// on a curved path with a short trail, landing with a small overshoot. Dots
/// still in flight are drawn with additive blending so overlapping trails
/// bloom rather than muddy — which is what makes a swarm read as light rather
/// than as confetti.
///
/// The numeral lives here rather than in a sibling view because it has to
/// count in lockstep with the dots; two views cannot share one animation clock
/// without one of them lagging a frame.
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

    private var duration: Double { RevealRamp.duration(forDay: day) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / SpiralGeometry.box

            TimelineView(.animation(
                paused: !isRevealing || reduceMotion || model.spiralRevealFrame != nil
            )) { timeline in
                let p = progress(at: timeline.date)
                let counted = RevealRamp.countedDay(atProgress: p, totalDays: day)

                ZStack {
                    Canvas { context, _ in
                        draw(in: &context, scale: scale, counted: counted)
                    }
                    SpiralCentreLabel(
                        day: RevealRamp.displayedDay(atProgress: p, totalDays: day),
                        veilDay: day
                    )
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
            try? await Task.sleep(for: .seconds(duration + 0.2))
            isRevealing = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Reveal

    private func progress(at date: Date) -> Double {
        if let frozen = model.spiralRevealFrame { return frozen }
        guard !reduceMotion, let start = revealStart else { return 1 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }

    // MARK: - Flight

    /// Where a dot comes from. Off the left or right edge, alternating, so the
    /// stream weaves instead of marching. Anything beyond `box` is outside the
    /// phone, so the dot genuinely enters frame rather than materialising.
    private func origin(for dot: SpiralGeometry.Dot, index: Int) -> CGPoint {
        let box = SpiralGeometry.box
        let fromLeft = index.isMultiple(of: 2)
        return CGPoint(
            x: fromLeft ? -box * 0.30 : box * 1.30,
            y: dot.position.y + (SpiralGeometry.centre.y - dot.position.y) * 0.35
        )
    }

    /// Quadratic bezier with the control point pushed off the straight line.
    /// A dot that travels in a straight line reads as dragged; an arc reads as
    /// thrown, which is the difference between a transition and an arrival.
    private func flight(from: CGPoint, to: CGPoint, t: Double, bow: Double) -> CGPoint {
        let dx = to.x - from.x, dy = to.y - from.y
        let cx = (from.x + to.x) / 2 - dy * bow
        let cy = (from.y + to.y) / 2 + dx * bow
        let u = 1 - t
        return CGPoint(
            x: u * u * from.x + 2 * u * t * cx + t * t * to.x,
            y: u * u * from.y + 2 * u * t * cy + t * t * to.y
        )
    }

    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

    /// Overshoots slightly and settles. A dot that stops dead on its mark has
    /// no weight.
    private func backOut(_ t: Double, _ s: Double = 2.4) -> Double {
        1 + (s + 1) * pow(t - 1, 3) + s * pow(t - 1, 2)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, scale: CGFloat, counted: Double) {
        let dots = SpiralGeometry.dots(forDay: day, milestoneDays: milestoneDays)
        guard !dots.isEmpty else { return }

        let window = RevealRamp.flightWindow(forDay: day)
        var inFlight: [(SpiralGeometry.Dot, Int, Double)] = []

        for (i, dot) in dots.enumerated() {
            let born = Double(i)                       // dot i is day i+1
            guard counted >= born else { continue }
            let age = min(1, (counted - born) / window)
            if age >= 1 {
                landed(dot, in: &context, scale: scale)
            } else {
                inFlight.append((dot, i, age))
            }
        }

        // Everything still moving goes in one additive layer, so overlapping
        // trails add up to light instead of stacking into mud.
        if !inFlight.isEmpty {
            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                for (dot, i, age) in inFlight {
                    flying(dot, index: i, age: age, in: &layer, scale: scale)
                }
            }
        }
    }

    /// A dot at rest — the settled spiral, unchanged from before.
    private func landed(
        _ dot: SpiralGeometry.Dot,
        in context: inout GraphicsContext,
        scale: CGFloat
    ) {
        let d = dot.diameter * scale
        let p = dot.position
        let rect = CGRect(x: p.x * scale - d / 2, y: p.y * scale - d / 2, width: d, height: d)
        let colour = dot.isYearMarker ? Palette.yearMarker : Palette.spiralDot(ramp: dot.ramp)

        if dot.isNewest || dot.isYearMarker {
            let radius: CGFloat = dot.isNewest ? 16 : 8
            let glow = dot.isNewest ? 0.5 : 0.7
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: colour.opacity(glow), radius: radius * scale))
                layer.fill(Path(ellipseIn: rect), with: .color(colour))
            }
        } else {
            context.fill(Path(ellipseIn: rect), with: .color(colour))
        }

        // A milestone reads as a bright core inside its own dot. Size cannot do
        // this job — below roughly day 174 every dot is already at the clamp.
        if dot.isMilestone && !dot.isYearMarker {
            let inner = d * 0.42
            let core = CGRect(x: p.x * scale - inner / 2, y: p.y * scale - inner / 2,
                              width: inner, height: inner)
            context.fill(Path(ellipseIn: core),
                         with: .color(Palette.spiralDot(ramp: dot.ramp, lift: 0.3)))
        }
    }

    /// A dot on its way in: trail, then the dot itself, hot and cooling.
    private func flying(
        _ dot: SpiralGeometry.Dot,
        index: Int,
        age: Double,
        in context: inout GraphicsContext,
        scale: CGFloat
    ) {
        let from = origin(for: dot, index: index)
        let to = dot.position
        let bow = 0.16
        let eased = easeOut(age)

        // Three ghosts along the path behind it. Additive, so where several
        // trails cross they brighten.
        for ghost in 1...3 {
            let back = age - Double(ghost) * 0.13
            guard back > 0 else { continue }
            let q = flight(from: from, to: to, t: easeOut(back), bow: bow)
            let d = dot.diameter * scale * 0.62 * (1 - Double(ghost) / 4)
            let rect = CGRect(x: q.x * scale - d / 2, y: q.y * scale - d / 2,
                              width: d, height: d)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Palette.spiralDot(ramp: dot.ramp, lift: 0.5)
                    .opacity(0.16 * (1 - Double(ghost) / 4) * (1 - age)))
            )
        }

        let q = flight(from: from, to: to, t: eased, bow: bow)
        // Overshoot on the size as it lands.
        let settle = min(1.2, max(0.1, backOut(min(1, age * 1.05))))
        let d = dot.diameter * scale * settle
        let rect = CGRect(x: q.x * scale - d / 2, y: q.y * scale - d / 2, width: d, height: d)
        // Fresh dots burn brighter and cool as the count leaves them behind.
        let heat = pow(1 - age, 1.5) * 0.85
        context.fill(
            Path(ellipseIn: rect),
            with: .color(Palette.spiralDot(ramp: dot.ramp, lift: heat)
                .opacity(min(1, age * 3)))
        )
    }
}

/// The centre label, sitting on the radial veil so inner dots don't collide
/// with the numeral. The veil shrinks with the bloom — see `SpiralGeometry`.
///
/// `day` is what the numeral reads, which during the arrival is the day
/// currently being counted. `veilDay` sizes the veil and stays at the real
/// total, so the hole doesn't grow while the count runs.
struct SpiralCentreLabel: View {
    let day: Int
    var veilDay: Int?

    private var years: Int { day / 365 }
    private var veilBasis: Int { veilDay ?? day }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / SpiralGeometry.box
            let veil = SpiralGeometry.veil(day: veilBasis)

            VStack(spacing: 0) {
                Text(overline)
                    .font(.spaceGrotesk(11, weight: .medium))
                    .tracking(3.3)
                    .foregroundStyle(Palette.textMuted)
                Text(value)
                    .font(.spaceGrotesk(valueSize, weight: .bold))
                    .foregroundStyle(Palette.textBrightest)
                    .monospacedDigit()
                    // Without this the numeral jitters horizontally as digits
                    // change width during the count.
                    .contentTransition(.numericText())
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
