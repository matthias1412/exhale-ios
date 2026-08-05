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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared: Date?

    private let duration: Double = 2.4

    var body: some View {
        ZStack {
            Palette.background.opacity(0.97).ignoresSafeArea()

            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = progress(at: timeline.date)

                ZStack {
                    Burst(progress: t, colour: milestone.colour)
                        .frame(width: 320, height: 320)

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

                PillButton("Good", style: .accent, action: onDismiss)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .task { appeared = .now }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Milestone reached. \(milestone.when), \(milestone.title). \(milestone.body)")
        .accessibilityAddTraits(.isModal)
    }

    private func progress(at date: Date) -> Double {
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

    private let count = 64

    var body: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            // Ease out hard, so it leaps and then settles rather than drifting.
            let eased = 1 - pow(1 - progress, 3)

            for i in 0..<count {
                let angle = Double(i) * SpiralGeometry.goldenAngle
                // Staggered so the ring doesn't move as one rigid disc.
                let stagger = Double(i % 7) / 7 * 0.18
                let local = min(1, max(0, (eased - stagger) / (1 - stagger)))
                guard local > 0 else { continue }

                let reach = (size.width / 2) * 0.92
                let radius = reach * local
                let diameter = 7 * (1 - local * 0.55)
                // Fades as it travels, so the edge dissolves instead of stopping.
                let opacity = local < 0.15 ? local / 0.15 : (1 - local) * 0.9

                let point = CGPoint(
                    x: centre.x + radius * cos(angle),
                    y: centre.y + radius * sin(angle)
                )
                let rect = CGRect(
                    x: point.x - diameter / 2, y: point.y - diameter / 2,
                    width: diameter, height: diameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(colour.opacity(opacity)))
            }

            // The milestone's own dot, arriving last and staying.
            let coreScale = 1 + sin(min(1, progress * 1.6) * .pi) * 0.6
            let core = 16 * coreScale
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: colour.opacity(0.7), radius: 22))
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
