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
                    Burst(progress: t, colour: milestone.colour)
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
private struct Burst: View {
    let progress: Double
    let colour: Color

    private let count = 56

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let eased = 1 - pow(1 - progress, 3)
            let ringRadius = (size.width / 2) * 0.86

            for i in 0..<count {
                let angle = Double(i) * SpiralGeometry.goldenAngle
                // Staggered so it doesn't travel as one rigid disc.
                let stagger = Double(i % 7) / 7 * 0.18
                let local = min(1, max(0, (eased - stagger) / (1 - stagger)))
                guard local > 0 else { continue }

                // Overshoot slightly, then settle back onto the ring — dots
                // that simply stop look mechanical.
                let overshoot = sin(local * .pi) * 0.09
                let radius = ringRadius * (local + overshoot)
                // They arrive and *stay*. The earlier version faded them to
                // nothing by the halfway point, which left the last second of
                // the animation as static text and no resting composition.
                let diameter = 6.5 * (0.55 + 0.45 * local)
                let opacity = min(1, local / 0.2) * 0.85

                let point = CGPoint(
                    x: centre.x + radius * cos(angle),
                    y: centre.y + radius * sin(angle)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - diameter / 2,
                                           y: point.y - diameter / 2,
                                           width: diameter, height: diameter)),
                    with: .color(colour.opacity(opacity))
                )
            }

            // The milestone's own dot, held at the centre of its own ring.
            let pulse = 1 + sin(min(1, progress * 1.5) * .pi) * 0.7
            let core = 20 * pulse
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: colour.opacity(0.8), radius: 26))
                layer.fill(
                    Path(ellipseIn: CGRect(x: centre.x - core / 2, y: centre.y - core / 2,
                                           width: core, height: core)),
                    with: .color(colour)
                )
            }
        }
        .allowsHitTesting(false)
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
