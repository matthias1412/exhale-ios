import CoreGraphics
import Foundation

/// The phyllotaxis maths behind the quit spiral. Pure and free of SwiftUI so it
/// can be unit-tested and rendered identically at any size.
///
/// One dot = one smoke-free day, always. The spiral only ever grows.
///
/// ## Deviation from the handoff spec — the bloom
///
/// The spec placed every dot with `r = holeR + span * sqrt(i/(n-1))`, which
/// stretches the dots across the *whole* annulus no matter how few there are.
/// Rendered, that means day 1 is a single dot stranded at the rim and days 7–30
/// are scattered confetti with no legible spiral — the signature visual doesn't
/// exist until roughly day 60, which is exactly the stretch where someone
/// quitting is most fragile.
///
/// Instead the radius *band* opens outward over the first 90 days: the inner
/// edge travels 92 → 44pt and the outer edge 92 → 145pt. From day 90 the output
/// is identical to the spec, so no later screen or store asset is affected.
/// The centre veil scales with the band so early dots are never swallowed by
/// the day numeral.
enum SpiralGeometry {

    static let goldenAngle: Double = 2.399963
    /// Design-space box. Everything below is in these units; scale to fit.
    static let box: CGFloat = 302
    static let centre = CGPoint(x: 151, y: 151)
    static let holeRadius: Double = 44
    static let maxRadius: Double = 145
    /// Day at which the band finishes opening and the spec takes over exactly.
    static let bloomCompletesOnDay = 90
    /// Ten years of dots. Past this the spiral stops adding.
    static let maxDots = 3650

    struct Dot: Equatable, Sendable {
        let position: CGPoint
        let diameter: Double
        /// 0 = oldest day, 1 = newest. Drives the ember → sea-glass ramp.
        let ramp: Double
        let isYearMarker: Bool
        let isNewest: Bool
    }

    static func dotCount(forDay day: Int) -> Int {
        min(max(day, 0), maxDots)
    }

    /// Largest a dot ever gets, so the veil can be kept clear of dot edges.
    static let maxDotDiameter: Double = 13

    /// Dots shrink as the streak grows so the disc densifies instead of
    /// overflowing. Clamped to 3…13pt.
    static func dotDiameter(count: Int) -> Double {
        let annulus = Double.pi * (maxRadius * maxRadius - holeRadius * holeRadius)
        let n = Double(max(count, 40))
        let raw = 2 * (annulus / (n * Double.pi)).squareRoot() * 0.62
        return min(maxDotDiameter, max(3, (raw * 10).rounded() / 10))
    }

    /// 0 on day 1, 1 from day 90 onward.
    static func bloom(day: Int) -> Double {
        guard bloomCompletesOnDay > 1 else { return 1 }
        return min(1, max(0, Double(day - 1) / Double(bloomCompletesOnDay - 1)))
    }

    /// Radial extent of the dot band for a given day.
    ///
    /// The band bottoms out at 64, not at `holeRadius`. Measured off a real
    /// day-90 capture, dots placed from 44 sat under the centre veil and
    /// rendered as brown mud — `#603E21` at 38% brightness — because the veil
    /// was solid to 58 and faded to 82. That swallowed the whole ember end of
    /// the ramp, which is the emotionally loaded part: the innermost dots are
    /// the user's first and hardest days.
    static func band(day: Int) -> (inner: Double, outer: Double) {
        let p = bloom(day: day)
        return (
            inner: 92 - (92 - 64) * p,
            outer: 92 + (maxRadius - 92) * p
        )
    }

    /// The radial fade the day numeral sits on, so inner dots don't collide
    /// with the text.
    ///
    /// Derived from the band rather than tuned independently, so that **no dot
    /// can ever sit under the veil** — the fade reaches zero opacity a full dot
    /// radius before the innermost dot's edge. Enforced by
    /// `testNoDotIsEverTouchedByTheVeil`.
    static func veil(day: Int) -> (solid: Double, fade: Double) {
        let fade = band(day: day).inner - maxDotDiameter / 2
        return (solid: fade * 0.75, fade: fade)
    }

    static func dots(forDay day: Int) -> [Dot] {
        let n = dotCount(forDay: day)
        guard n > 0 else { return [] }

        let size = dotDiameter(count: n)
        let (inner, outer) = band(day: day)
        let span = outer - inner - size / 2

        return (0..<n).map { i in
            let ramp = n > 1 ? Double(i) / Double(n - 1) : 1
            let radius = inner + span * (n > 1 ? ramp.squareRoot() : 0)
            let angle = Double(i) * goldenAngle - 1.6
            let isYear = (i + 1) % 365 == 0

            return Dot(
                position: CGPoint(
                    x: centre.x + radius * cos(angle),
                    y: centre.y + radius * sin(angle)
                ),
                diameter: isYear ? min(13, size * 1.6) : size,
                ramp: ramp,
                isYearMarker: isYear,
                isNewest: i == n - 1
            )
        }
    }
}

/// The 55-dot logo mark — same phyllotaxis, small box, no year markers, no
/// glow, and no bloom (it's a fixed mark, not a streak). Locked config 1b.
enum LogoGeometry {
    static let dotCount = 55
    static let box: CGFloat = 26

    struct Dot: Equatable, Sendable {
        let position: CGPoint
        let diameter: Double
        let ramp: Double
    }

    static func dots(box: CGFloat = box) -> [Dot] {
        let scale = Double(box) / 26
        let centre = 13.0 * scale
        let hole = 3.1 * scale
        let maxR = 12.4 * scale

        return (0..<dotCount).map { i in
            let ramp = Double(i) / Double(dotCount - 1)
            let radius = hole + (maxR - hole) * ramp.squareRoot()
            let angle = Double(i) * SpiralGeometry.goldenAngle - 1.6
            return Dot(
                position: CGPoint(
                    x: centre + radius * cos(angle),
                    y: centre + radius * sin(angle)
                ),
                diameter: (1.3 + ramp * 1.2) * scale,
                ramp: ramp
            )
        }
    }
}
