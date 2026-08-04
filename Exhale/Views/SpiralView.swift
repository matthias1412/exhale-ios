import SwiftUI

/// The quit spiral. One dot per smoke-free day.
///
/// Drawn with `Canvas`, not a stack of views — at five years this is 1,825 dots
/// and it has to stay smooth while the money counter ticks beside it.
struct SpiralView: View {
    let day: Int
    /// Spoken instead of the dots, which are meaningless one at a time.
    let accessibilitySummary: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            TimelineView(.animation(paused: !isRevealing || reduceMotion)) { timeline in
                Canvas { context, _ in
                    draw(in: &context, scale: scale, progress: progress(at: timeline.date))
                }
                .frame(width: side, height: side)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            guard !reduceMotion else {
                isRevealing = false
                return
            }
            revealStart = .now
            try? await Task.sleep(for: .seconds(revealDuration + 0.1))
            isRevealing = false
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Reveal

    private func progress(at date: Date) -> Double {
        guard !reduceMotion, let start = revealStart else { return 1 }
        return min(1, max(0, date.timeIntervalSince(start) / revealDuration))
    }

    /// Oldest dot first, rippling outward to today.
    private func dotProgress(index: Int, of count: Int, overall: Double) -> Double {
        guard count > 1, overall < 1 else { return 1 }
        let start = (Double(index) / Double(count - 1)) * (1 - dotFadeWindow)
        let local = min(1, max(0, (overall - start) / dotFadeWindow))
        // ease-out so dots settle rather than snap
        return 1 - pow(1 - local, 3)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, scale: CGFloat, progress overall: Double) {
        let dots = SpiralGeometry.dots(forDay: day)
        guard !dots.isEmpty else { return }

        var glowing: [(SpiralGeometry.Dot, Double)] = []

        for (i, dot) in dots.enumerated() {
            let p = dotProgress(index: i, of: dots.count, overall: overall)
            guard p > 0 else { continue }
            if dot.isNewest || dot.isYearMarker {
                glowing.append((dot, p))
                continue
            }
            fill(dot, progress: p, in: &context, scale: scale)
        }

        // Glowing dots go in their own layer so the shadow filter is applied
        // a handful of times, not eighteen hundred.
        for (dot, p) in glowing {
            let colour: Color = dot.isNewest ? Palette.accent : Palette.yearMarker
            let radius: CGFloat = dot.isNewest ? 16 : 8
            let glowOpacity = (dot.isNewest ? 0.5 : 0.7) * p
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
        let rect = CGRect(
            x: dot.position.x * scale - diameter / 2,
            y: dot.position.y * scale - diameter / 2,
            width: diameter,
            height: diameter
        )
        let colour = dot.isYearMarker ? Palette.yearMarker : Palette.spiralDot(ramp: dot.ramp)
        context.fill(Path(ellipseIn: rect), with: .color(colour.opacity(p)))
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
