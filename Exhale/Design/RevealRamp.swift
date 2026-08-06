import Foundation

/// The timing of the spiral's arrival.
///
/// The spiral used to fade in over a flat 1.1 seconds, which said "here is a
/// picture of your streak". The streak is the one thing in the app that cost
/// the user something, so watching it arrive should cost something too: the
/// numeral counts 1, 2, 3… and a dot flies in on each day as it is called.
///
/// The ramp is exponential rather than linear for two reasons. Linear at five
/// years is 1,825 dots a second — unreadable — and linear at three days is a
/// stutter. Exponential keeps the opening slow enough that the first days
/// register as individual events at *every* streak length, then accelerates.
///
/// Pure and free of SwiftUI so the shape of the curve can be unit-tested
/// rather than eyeballed in a screenshot.
enum RevealRamp {

    /// How long the whole count takes. Grows with the streak, so a year
    /// visibly takes longer to arrive than a week — which is the point.
    /// Capped at three seconds; this plays on every cold launch.
    static func duration(forDay day: Int) -> Double {
        let n = Double(max(day, 2))
        return min(3.0, max(1.0, 0.8 + 0.35 * log(n)))
    }

    /// Steepness. Rises with the streak so a long streak accelerates rather
    /// than merely lasting longer.
    static func steepness(forDay day: Int) -> Double {
        let n = Double(max(day, 2))
        return min(7, max(1.6, log(n) * 1.15))
    }

    /// How many counted days a dot spends in the air.
    ///
    /// Measured in *days* rather than seconds, so as the count accelerates the
    /// flights overlap into a stream on their own. Scaled down for short
    /// streaks: a flat five days would mean a three-day streak finishes with
    /// every one of its dots still in mid-air.
    static func flightWindow(forDay day: Int) -> Double {
        min(5, max(0.8, Double(day) / 3))
    }

    /// Slow at both ends, quick through the middle. Used to take the edge off
    /// the exponential's finish.
    private static func smootherStep(_ t: Double) -> Double {
        t * t * t * (t * (t * 6 - 15) + 10)
    }

    /// The internal counter. Deliberately runs one flight window *past* the
    /// streak so the last dot has somewhere to land — without the overshoot
    /// the animation ended with its final dots frozen halfway across the
    /// screen, which is the exact failure the whole rewrite is meant to fix.
    ///
    /// A pure exponential was measured on a real capture: at 90% of the way
    /// through a five-year reveal it had only reached day 907, so the last
    /// 918 days arrived in the final third of a second. That is the same
    /// "everything appears at once" the count was meant to replace, just moved
    /// to the end. Blending in a smootherstep keeps the opening slow — which
    /// is what makes the first days read as individual events — while giving
    /// the finish somewhere to decelerate, so the number *lands* on the streak
    /// instead of blurring onto it.
    static func countedDay(atProgress p: Double, totalDays day: Int) -> Double {
        guard day > 0 else { return 0 }
        let target = Double(day) + flightWindow(forDay: day)
        let k = steepness(forDay: day)
        let c = min(1, max(0, p))
        let exponential = (exp(k * c) - 1) / (exp(k) - 1)
        let eased = smootherStep(c)
        return target * (exponential * 0.6 + eased * 0.4)
    }

    /// What the numeral reads. Never overshoots the real streak, however far
    /// the internal counter has run.
    static func displayedDay(atProgress p: Double, totalDays day: Int) -> Int {
        guard day > 0 else { return 0 }
        let counted = countedDay(atProgress: p, totalDays: day)
        return max(1, min(day, Int(counted.rounded(.down))))
    }
}
