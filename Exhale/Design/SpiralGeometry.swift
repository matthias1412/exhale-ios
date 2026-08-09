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
        /// This dot is the day a healing milestone was reached. The celebration
        /// hands off to it: the burst ends, and this is where that moment
        /// permanently lives.
        let isMilestone: Bool
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

    /// Day numbers on which a milestone falls, so the spiral can mark them.
    /// Several early milestones share day 1, hence a set.
    static func milestoneDays(hours: [Double]) -> Set<Int> {
        Set(hours.map { Int(($0 / 24).rounded(.down)) + 1 })
    }

    static func dots(forDay day: Int, milestoneDays: Set<Int> = []) -> [Dot] {
        let n = dotCount(forDay: day)
        guard n > 0 else { return [] }

        let size = dotDiameter(count: n)
        let (inner, outer) = band(day: day)

        // The `size / 2` inset keeps the outermost dot's edge inside `outer`.
        // In the first fortnight the band is narrower than half a dot, which
        // made the inset negative and dragged every dot *inward* past
        // `inner` — under the veil, dimmed. Clamped, the early days simply
        // sit on a single ring, which is what they should look like anyway.
        let span = max(0, outer - inner - size / 2)

        return (0..<n).map { i in
            let ramp = n > 1 ? Double(i) / Double(n - 1) : 1
            let radius = inner + span * (n > 1 ? ramp.squareRoot() : 0)
            let angle = Double(i) * goldenAngle - 1.6
            let isYear = (i + 1) % 365 == 0

            // Dot i is day i+1.
            let isMilestone = milestoneDays.contains(i + 1)
            // Milestones are deliberately NOT marked by size. Until about day
            // 174 every dot is already at the 13pt clamp, so an enlargement
            // silently does nothing — and that window holds eight of the
            // twelve milestones, the ones that matter most. They are drawn
            // with an inner highlight instead, which reads at any density and
            // never exceeds the dot's own footprint.
            let diameter = isYear ? min(13, size * 1.6) : size

            return Dot(
                position: CGPoint(
                    x: centre.x + radius * cos(angle),
                    y: centre.y + radius * sin(angle)
                ),
                diameter: diameter,
                ramp: ramp,
                isYearMarker: isYear,
                isNewest: i == n - 1,
                isMilestone: isMilestone
            )
        }
    }
}

/// The 55-dot logo mark — same phyllotaxis, small box, no year markers, no
/// glow, and no bloom (it's a fixed mark, not a streak). Locked config 1b.
enum LogoGeometry {
    static let box: CGFloat = 26

    /// Always 55, at every size.
    ///
    /// This was briefly made to thin out below 44pt, on the theory that 55 dots
    /// at 26pt would read as noise. Rendering it proved the opposite: at the
    /// header's real size — 26pt is 78 device pixels on a 3x screen — 55 dots
    /// resolve into the double-armed rosette that is the whole point of the
    /// mark, and 26 dots collapse into a plain ring of dots with no spiral in
    /// it at all. It also silently split the brand in two, because the app icon
    /// is generated at 1024 and stayed at 55 — so the mark in the header and
    /// the icon on the home screen were visibly different marks.
    static let dotCount = 55

    /// One diameter for every dot, in the 26-unit design space.
    ///
    /// It used to grow outward, 1.3 at the core to 2.5 at the rim, on the idea
    /// that swelling dots would read as growth. Measured, that was the whole
    /// problem. Phyllotaxis places dots an even 2.6 units apart at every
    /// radius, so a diameter that grows is a gap that shrinks: clear space
    /// between neighbours fell from 101% of a dot at the centre to 11% at the
    /// rim. Worse, the icon generator multiplied every dot by a further 1.35
    /// to keep the mark weighty when downsampled — which tipped it over, and
    /// **26 dots on the home-screen icon genuinely overlapped**. The rim
    /// fused into a solid ring, and a bloom is only legible through the spiral
    /// arms that ring was covering.
    ///
    /// 2.0 everywhere: 36% ink coverage, so it keeps its weight down to 40px
    /// without the icon needing to fatten anything, and a 31% clear gap at the
    /// rim, so the arms read. Growth is the colour ramp's job — ember at the
    /// core to sea-glass at the edge — and it was always doing that already.
    static let dotDiameter: Double = 2.0

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
                diameter: dotDiameter * scale,
                ramp: ramp
            )
        }
    }
}
