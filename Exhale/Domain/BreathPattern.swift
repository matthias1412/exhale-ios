import Foundation

/// The pacing of the craving screen's breath.
///
/// Separated from the view so the shape of the curve can be tested rather than
/// eyeballed, because two things about the old one were wrong and neither was
/// visible in a screenshot.
///
/// **The timing.** It was 4-4-6 — fourteen seconds, about 4.3 breaths a
/// minute — chosen by feel. Roughly six breaths a minute is where baroreflex
/// gain and heart-rate variability peak for most adults, so we were slower
/// than the rate with the best evidence behind it. And a four-second hold is
/// the weakest beat available: holds raise CO2, and for someone already
/// agitated that can add to the panic rather than settle it. The holds in box
/// breathing were developed for focus under pressure, not for calming down.
/// What does the work is an exhale longer than the inhale, which is the vagal
/// lever — convenient, for an app called Exhale.
///
/// **The easing.** The inhale ran `1 - (1-t)^2.2`, whose fastest moment is the
/// very first instant. Measured, it left the bottom at 0.549 of fullness per
/// second against sine's 0.003 — so every breath began with a lurch the user
/// had to catch up with, which is exactly how it was described. A raised
/// cosine starts from rest, peaks mid-breath and settles at the top, which is
/// how lungs actually fill: airflow tapers as elastic recoil resists.
///
/// The curve also quietly rewrote the pattern. Time spent near full was about
/// 1.5s longer than prescribed at every setting, so 4-4-6 held the user at the
/// top for 5.55 seconds. Sine adds a predictable ~1.1s instead.
struct BreathPattern: Equatable, Sendable {
    /// Seconds.
    let inhale: Double
    let hold: Double
    let exhale: Double

    /// 11 seconds, 5.5 breaths a minute, exhale half as long again as the
    /// inhale, and a beat at the top short enough not to load CO2.
    static let standard = BreathPattern(inhale: 4, hold: 1, exhale: 6)

    var cycle: Double { inhale + hold + exhale }
    var breathsPerMinute: Double { 60 / cycle }

    /// Raised cosine: zero velocity at both ends, peak in the middle.
    private static func sine(_ t: Double) -> Double {
        0.5 - 0.5 * cos(.pi * min(1, max(0, t)))
    }

    enum Phase: Equatable, Sendable {
        case inhale, hold, exhale

        var instruction: String {
            switch self {
            case .inhale: "Breathe in"
            case .hold: "Hold it"
            case .exhale: "Let it go"
            }
        }
    }

    /// Where the breath is at `elapsed` seconds into the craving.
    ///
    /// `fullness` runs 0 (empty) to 1 (full) — the view maps it to a radius, so
    /// the pacing and the drawing can be reasoned about separately.
    func state(at elapsed: Double) -> (fullness: Double, phase: Phase) {
        var t = elapsed.truncatingRemainder(dividingBy: cycle)
        if t < 0 { t += cycle }

        if t < inhale {
            return (Self.sine(t / inhale), .inhale)
        }
        t -= inhale
        if t < hold {
            // Not perfectly still: a held breath is not a frozen one.
            return (1 + sin(t / max(hold, 0.001) * .pi) * 0.008, .hold)
        }
        t -= hold
        return (1 - Self.sine(t / exhale), .exhale)
    }

    /// Fades to nothing as each phase hands over, so the word changes while it
    /// is invisible rather than swapping under the reader.
    func instructionOpacity(at elapsed: Double) -> Double {
        var t = elapsed.truncatingRemainder(dividingBy: cycle)
        if t < 0 { t += cycle }
        let fade = 0.35
        let boundaries = [0, inhale, inhale + hold, cycle]
        let distance = boundaries.map { abs(t - $0) }.min() ?? fade
        return min(1, distance / fade)
    }
}
