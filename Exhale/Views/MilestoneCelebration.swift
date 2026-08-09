import SwiftUI

/// The reward for coming back.
///
/// A milestone crossed while the app is closed is *held* rather than silently
/// ticked off, and revealed the next time the user opens Exhale. That is the
/// point: it gives the app something to owe you. A notification you dismissed
/// on the lock screen is not an experience; discovering that your body passed
/// a mark while you weren't looking is.
///
/// Every milestone owns a colour, so the dot it leaves behind in the spiral is
/// individually recognisable rather than one of a thousand identical dots.
struct MilestoneCelebration: View {
    let milestone: Milestone
    let dayNumber: Int
    let onDismiss: () -> Void

    /// Set while the dot is travelling to its slot in the spiral.
    @State private var settling = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var model
    @State private var appeared: Date?

    private let duration: Double = 2.4

    /// Where this milestone's dot sits in the spiral, as a fraction of the
    /// burst canvas. The gather lands here so the burst resolves into the dot
    /// it is about rather than dissolving in the middle of the screen.
    private var spiralSlot: UnitPoint {
        let day = max(1, Int((milestone.hours / 24).rounded(.down)) + 1)
        let dots = SpiralGeometry.dots(forDay: day)
        guard let last = dots.last else { return .center }
        return UnitPoint(x: last.position.x / SpiralGeometry.box,
                         y: last.position.y / SpiralGeometry.box)
    }

    var body: some View {
        ZStack {
            // Fully opaque. At 0.97 the stats row and tab bar showed through,
            // which made a moment that should feel like an event look like a
            // dialog laid over a screen.
            Palette.background.ignoresSafeArea()

            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = progress(at: timeline.date)

                // Burst above, words below. Overlapping them meant the
                // milestone's own dot ended up behind its own title.
                VStack(spacing: 26) {
                    Burst(progress: t, colour: milestone.colour, target: spiralSlot)
                        .frame(width: 210, height: 210)

                    VStack(spacing: 0) {
                        Text(milestone.when.uppercased())
                            .font(.spaceGrotesk(11, weight: .medium))
                            .tracking(1.98)
                            .foregroundStyle(milestone.colour)

                        Text(milestone.title)
                            .font(.spaceGrotesk(26, weight: .bold, relativeTo: .title))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.textBrightest)
                            .padding(.top, 8)
                            .padding(.horizontal, 30)

                        Text(milestone.body)
                            .font(.spaceGrotesk(14))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .foregroundStyle(Palette.textMuted)
                            .padding(.top, 10)
                            .padding(.horizontal, 34)
                    }
                    .opacity(reduceMotion ? 1 : min(1, max(0, (t - 0.25) / 0.35)))
                }
            }

            VStack {
                Spacer()
                Text("Day \(dayNumber)")
                    .font(.spaceGrotesk(13))
                    .foregroundStyle(Palette.textFaint)
                    .padding(.bottom, 14)

                PillButton("Good", style: .accent) { settle() }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .opacity(settling ? 0 : 1)
            }
        }
        // The dot flies to the exact place it will live in the spiral, then
        // hands over to the Canvas that draws it from then on. You cannot
        // matchedGeometryEffect into a Canvas — its dots are drawn pixels, not
        // views — but SpiralGeometry knows precisely where day N sits, so a
        // real Circle can be flown to that point and faded out as the spiral
        // takes over.
        .overlay {
            if settling {
                GeometryReader { geo in
                    SettlingDot(
                        colour: milestone.colour,
                        target: spiralPoint(in: geo.size),
                        from: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.34)
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .task {
            appeared = .now
            // Fires as the burst launches, not on dismiss — the tap should
            // coincide with the thing it is marking.
            if !model.clock.isFrozen { Feedback.milestone() }

            // Harness only. simctl can record video but cannot tap, so the
            // handoff from the burst to the spiral arriving behind it — the
            // one sequence that is entirely about timing — could not otherwise
            // be watched at all.
            if let after = model.celebrationAutoDismissAfter {
                try? await Task.sleep(for: .seconds(after))
                onDismiss()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone reached. \(milestone.when), \(milestone.title). \(milestone.body)")
        .accessibilityAddTraits(.isModal)
    }

    /// Where day `dayNumber`'s dot lives on the Today screen, in this view's
    /// coordinates. The spiral is a square centred horizontally, inset 24pt,
    /// so its geometry maps directly.
    private func spiralPoint(in size: CGSize) -> CGPoint {
        let side = size.width - 48
        let scale = side / SpiralGeometry.box
        let dots = SpiralGeometry.dots(forDay: dayNumber)
        guard let dot = dots.last else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        return CGPoint(
            x: 24 + dot.position.x * scale,
            // The spiral occupies the flexible middle of Today; this lands it
            // in the same band without needing that view's exact layout.
            y: size.height * 0.42 - side / 2 + dot.position.y * scale
        )
    }

    private func settle() {
        guard !model.clock.isFrozen else { onDismiss(); return }
        withAnimation(.easeInOut(duration: 0.55)) { settling = true }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            onDismiss()
        }
    }

    private func progress(at date: Date) -> Double {
        // Seeded runs pin the animation so individual frames can be captured
        // and inspected — otherwise every screenshot is the resting state and
        // the motion is never actually verified.
        if let frozen = model.celebrationFrame { return frozen }
        guard !reduceMotion, let appeared else { return 1 }
        return min(1, max(0, date.timeIntervalSince(appeared) / duration))
    }
}

/// Dots thrown outward and settling — the spiral's own vocabulary, moving.
///
/// Drawn in a single `Canvas` rather than as views, for the same reason the
/// spiral is: this runs alongside everything else on screen.
/// The burst: flare, bloom, gather.
///
/// Three acts of one thing rather than three effects stacked.
///
/// **Flare** — a white punch at the core, the moment of impact.
/// **Bloom** — the app's own phyllotaxis opening outward, unwinding as it
/// goes. This is the part that is *ours*; the flare and the gather are both
/// borrowed grammar. An earlier attempt randomised each dot's radius and
/// departure time to make it feel organic and destroyed the golden-angle
/// lattice in the process — what came out was a scatter running on a bloom's
/// schedule. Radius and order are exact here for that reason.
/// **Gather** — everything converges on the dot's position in the spiral, so
/// the burst becomes the thing it is about instead of dissipating in place.
///
/// Ignite's contribution is the flare and a gravity pull applied to the whole
/// field at once, which breathes the bloom back inward without breaking it.
private struct Burst: View {
    let progress: Double
    let colour: Color
    /// Where this milestone's dot lives in the spiral, in unit coordinates
    /// (0...1 of the canvas). The gather lands here.
    var target: UnitPoint = .center

    private let count = 90

    // Variant L: a fast, tight bloom and heavy gravity, so it leaves like a
    // firework and is hauled back into place.
    private let bloomEnd = 0.50
    private let gatherAt = 0.44
    private let stagger = 0.26
    private let unwind = 0.7
    private let gravity = 30.0

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let unit = min(size.width, size.height) / 302
            let landing = CGPoint(x: size.width * target.x, y: size.height * target.y)

            let bloom = clamp((progress - 0.03) / (bloomEnd - 0.03))
            let gather = clamp((progress - gatherAt) / (1 - gatherAt))
            let g = easeInOut(gather)

            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                for i in 0..<count {
                    let t = Double(i) / Double(count - 1)
                    // Ordered departure: inner dots leave first and the outer
                    // ones follow, which is what draws the arms.
                    let start = t * stagger
                    let local = clamp((bloom - start) / max(0.001, 1 - start))
                    guard local > 0 else { continue }
                    let e = easeOutQuint(local)

                    var radius = (26 + 72 * t.squareRoot()) * e * unit
                    let angle = Double(i) * SpiralGeometry.goldenAngle - 1.6 - (1 - e) * unwind
                    radius -= pow(clamp((progress - 0.40) / 0.60), 2) * gravity * unit

                    let bx = centre.x + cos(angle) * radius
                    let by = centre.y + sin(angle) * radius
                    let x = bx + (landing.x - bx) * g
                    let y = by + (landing.y - by) * g

                    let d = (2.2 + t * 3.4) * (0.5 + 0.5 * local) * (1 - g * 0.75) * unit
                    layer.opacity = min(1, local * 3) * (1 - pow(g, 1.4)) * 0.95
                    layer.fill(
                        Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                        with: .color(progress < 0.09 ? Palette.textBrightest : colour)
                    )
                }
            }

            // The core: white flare, then it shrinks and rides in to the slot.
            let flare = progress < 0.09 ? backOut(progress / 0.09, 3.4) : 1
            let cx = centre.x + (landing.x - centre.x) * g
            let cy = centre.y + (landing.y - centre.y) * g
            let cd = (30 * max(0.12, flare) + (9 - 30 * max(0.12, flare)) * g) * unit
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: colour.opacity(0.8), radius: 26 * (1 - g)))
                layer.fill(
                    Path(ellipseIn: CGRect(x: cx - cd / 2, y: cy - cd / 2,
                                           width: cd, height: cd)),
                    with: .color(progress < 0.11 ? Palette.textBrightest : colour)
                )
            }

            // The ring that marks where the moment now lives.
            if gather > 0.55 {
                let k = (gather - 0.55) / 0.45
                let r = (10 + k * 8) * unit
                context.stroke(
                    Path(ellipseIn: CGRect(x: landing.x - r, y: landing.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(colour.opacity(k * 0.55)),
                    lineWidth: 1.2
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func clamp(_ t: Double) -> Double { min(1, max(0, t)) }
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
    private func easeOutQuint(_ t: Double) -> Double { 1 - pow(1 - t, 5) }
    private func backOut(_ t: Double, _ s: Double) -> Double {
        1 + (s + 1) * pow(t - 1, 3) + s * pow(t - 1, 2)
    }
}

/// The dot in transit: leaves the celebration, lands where it will live.
private struct SettlingDot: View {
    let colour: Color
    let target: CGPoint
    let from: CGPoint

    @State private var arrived = false

    var body: some View {
        Circle()
            .fill(colour)
            .frame(width: arrived ? 9 : 20, height: arrived ? 9 : 20)
            .shadow(color: colour.opacity(0.8), radius: arrived ? 6 : 22)
            .position(arrived ? target : from)
            .opacity(arrived ? 0 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55)) { arrived = true }
            }
    }
}
