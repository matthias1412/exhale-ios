import XCTest
@testable import Exhale

final class SpiralGeometryTests: XCTestCase {

    func testOneDotPerDay() {
        XCTAssertEqual(SpiralGeometry.dots(forDay: 1).count, 1)
        XCTAssertEqual(SpiralGeometry.dots(forDay: 90).count, 90)
        XCTAssertEqual(SpiralGeometry.dots(forDay: 1825).count, 1825)
    }

    func testCapsAtTenYears() {
        XCTAssertEqual(SpiralGeometry.dots(forDay: 5000).count, SpiralGeometry.maxDots)
    }

    /// Dots shrink as the streak grows so the disc densifies instead of
    /// overflowing, and never leave the 3…13pt band.
    func testDotDiameterShrinksAndStaysClamped() {
        let d90 = SpiralGeometry.dotDiameter(count: 90)
        let d365 = SpiralGeometry.dotDiameter(count: 365)
        let d1825 = SpiralGeometry.dotDiameter(count: 1825)

        XCTAssertGreaterThan(d90, d365)
        XCTAssertGreaterThan(d365, d1825)
        for d in [SpiralGeometry.dotDiameter(count: 1), d90, d365, d1825,
                  SpiralGeometry.dotDiameter(count: 3650)] {
            XCTAssertGreaterThanOrEqual(d, 3)
            XCTAssertLessThanOrEqual(d, 13)
        }
    }

    /// The bloom: from day 90 onward the geometry must be identical to the
    /// original spec, so no later screen or store asset shifts.
    func testBloomIsCompleteByDayNinety() {
        XCTAssertEqual(SpiralGeometry.bloom(day: 90), 1, accuracy: 0.0001)
        XCTAssertEqual(SpiralGeometry.bloom(day: 1), 0, accuracy: 0.0001)

        let band = SpiralGeometry.band(day: 90)
        XCTAssertEqual(band.inner, 64, accuracy: 0.0001)
        XCTAssertEqual(band.outer, SpiralGeometry.maxRadius, accuracy: 0.0001)
    }

    /// The defect this guards against was measured off a real capture: dots
    /// placed under the centre veil rendered as brown mud (`#603E21`, 38%
    /// brightness), swallowing the entire ember end of the ramp.
    ///
    /// Every dot, at every streak length, must be clear of the veil entirely —
    /// not merely clear of its solid core.
    func testNoDotIsEverTouchedByTheVeil() {
        for day in [1, 2, 7, 14, 30, 60, 89, 90, 91, 365, 730, 1825, 3650] {
            let veil = SpiralGeometry.veil(day: day)
            for dot in SpiralGeometry.dots(forDay: day) {
                let dx = dot.position.x - SpiralGeometry.centre.x
                let dy = dot.position.y - SpiralGeometry.centre.y
                let innerEdge = (dx * dx + dy * dy).squareRoot() - dot.diameter / 2

                XCTAssertGreaterThanOrEqual(
                    innerEdge, veil.fade - 0.01,
                    "day \(day): a dot overlaps the veil and will render dimmed"
                )
            }
        }
    }

    /// The numeral needs room. "999" at 52pt is roughly 85pt wide, so the solid
    /// core must clear ~43pt at full bloom.
    func testVeilStillCoversTheNumeral() {
        XCTAssertGreaterThanOrEqual(SpiralGeometry.veil(day: 90).solid, 42)
        XCTAssertGreaterThanOrEqual(SpiralGeometry.veil(day: 3650).solid, 42)
    }

    /// Two different limits, because year markers are deliberately 1.6x the
    /// normal dot and so reach slightly past the nominal rim.
    ///
    /// - Ordinary dots must land inside `maxRadius` exactly.
    /// - Everything, markers included, must stay inside the canvas or it gets
    ///   clipped. (Markers peak at 147pt against a 151pt half-width.)
    func testDotsNeverEscapeTheCanvas() {
        let canvasLimit = Double(SpiralGeometry.box) / 2

        for day in [1, 30, 90, 365, 730, 1825, 3650] {
            for dot in SpiralGeometry.dots(forDay: day) {
                let dx = dot.position.x - SpiralGeometry.centre.x
                let dy = dot.position.y - SpiralGeometry.centre.y
                let edge = (dx * dx + dy * dy).squareRoot() + dot.diameter / 2

                XCTAssertLessThanOrEqual(
                    edge, canvasLimit,
                    "day \(day): a dot is clipped by the canvas edge"
                )
                if !dot.isYearMarker {
                    XCTAssertLessThanOrEqual(
                        edge, SpiralGeometry.maxRadius + 0.01,
                        "day \(day): an ordinary dot escaped the nominal rim"
                    )
                }
            }
        }
    }

    func testYearMarkersLandOnEveryThreeHundredAndSixtyFifthDay() {
        let dots = SpiralGeometry.dots(forDay: 1825)
        let markers = dots.enumerated().filter { $0.element.isYearMarker }.map(\.offset)
        XCTAssertEqual(markers, [364, 729, 1094, 1459, 1824])
    }

    func testNewestDotIsTheLastOne() {
        let dots = SpiralGeometry.dots(forDay: 90)
        XCTAssertTrue(dots.last?.isNewest == true)
        XCTAssertEqual(dots.filter(\.isNewest).count, 1)
    }

    /// One mark at every size. The header and the generated app icon have to
    /// come out of the same maths, or they are two different logos.
    func testLogoIsFiftyFiveDotsAtEverySize() {
        for box in [16.0, 26, 43.999, 44, 56, 1024] {
            XCTAssertEqual(LogoGeometry.dots(box: box).count, 55,
                           "box \(box) produced a different mark")
        }
    }

    func testLogoScalesProportionally() {
        let small = LogoGeometry.dots(box: 26)
        let large = LogoGeometry.dots(box: 104)
        XCTAssertEqual(large[10].diameter / small[10].diameter, 4, accuracy: 0.001)
    }
}

@MainActor
final class SeedTests: XCTestCase {
    /// Every advertised seed must actually resolve — otherwise the screenshot
    /// job silently captures the wrong screen.
    func testEverySeedResolves() {
        for name in SeedNames.all + SeedNames.motion + SeedNames.movies {
            XCTAssertNotNil(Seed.model(named: name), "seed '\(name)' does not resolve")
        }
    }

    func testSmokeSetIsSubsetOfAll() {
        XCTAssertTrue(Set(SeedNames.smoke).isSubset(of: Set(SeedNames.all)))
    }

    /// The motion set exists to be captured on one device instead of three, so
    /// it must not also be sitting in `all`.
    func testMotionSetIsSeparateFromAll() {
        XCTAssertTrue(Set(SeedNames.motion).isDisjoint(with: Set(SeedNames.all)))
    }

    /// A pinned frame that isn't pinned is just another capture of the settled
    /// spiral, which is the failure that would look completely fine.
    func testMotionSeedsArePinned() {
        for name in SeedNames.motion {
            XCTAssertNotNil(Seed.model(named: name)?.spiralRevealFrame,
                            "motion seed '\(name)' has no pinned frame")
        }
    }

    /// ...and the recorded ones must not be pinned, or the video is a still.
    func testMovieSeedsAreNotPinned() {
        for name in SeedNames.movies {
            XCTAssertNil(Seed.model(named: name)?.spiralRevealFrame,
                         "movie seed '\(name)' is pinned and would record a still")
        }
    }

    /// Day 8 is the "1 week" mark, so today's dot is also a milestone dot —
    /// the case where the newest-dot styling and the milestone styling collide.
    func testDayEightIsAMilestoneDay() {
        let model = Seed.model(named: "today-day8")
        XCTAssertEqual(model?.progress?.dayNumber, 8)
        XCTAssertTrue(model?.milestoneDays.contains(8) == true)
    }

    /// Seeded runs must be deterministic or the captures aren't diffable.
    func testSeededClockIsFrozen() {
        let model = Seed.model(named: "today-day90")
        XCTAssertTrue(model?.clock.isFrozen == true)
        XCTAssertEqual(model?.progress?.dayNumber, 90)
    }

    func testSosSeedsHitDistinctBreathingPhases() {
        let phases = ["sos-breathe-in", "sos-hold", "sos-let-go"].map { name -> String in
            guard let model = Seed.model(named: name), let started = model.sosStartedAt else {
                return "?"
            }
            let elapsed = model.clock.now.timeIntervalSince(started)
            return BreathPattern.standard.state(at: elapsed).phase.instruction
        }
        XCTAssertEqual(phases, ["Breathe in", "Hold it", "Let it go"])
    }
}

/// Milestone days are marked in the spiral so a celebration has somewhere
/// permanent to hand off to.
final class MilestoneDotTests: XCTestCase {

    private var cigaretteDays: Set<Int> {
        SpiralGeometry.milestoneDays(
            hours: Milestones.forProduct(.cigarettes).map(\.hours)
        )
    }

    /// 0.34h and 12h both fall on day 1; 48h is day 3, 72h is day 4.
    func testMilestoneHoursMapToTheRightDays() {
        let days = cigaretteDays
        XCTAssertTrue(days.contains(1))
        XCTAssertTrue(days.contains(3))
        XCTAssertTrue(days.contains(4))
        XCTAssertTrue(days.contains(8))       // 168h
        XCTAssertFalse(days.contains(2), "nothing lands on day 2")
    }

    /// Milestones are marked by an inner highlight, not by size — below about
    /// day 174 every dot is already at the clamp, so an enlargement would
    /// silently do nothing across the window holding most of the milestones.
    /// This pins that they stay the same size as their neighbours.
    func testMilestonesAreNotMarkedBySize() {
        for day in [90, 400] {
            let dots = SpiralGeometry.dots(forDay: day, milestoneDays: cigaretteDays)
            let plain = dots.first { !$0.isMilestone && !$0.isYearMarker }!
            let marked = dots.first { $0.isMilestone && !$0.isYearMarker }!
            XCTAssertEqual(marked.diameter, plain.diameter, accuracy: 0.0001,
                           "day \(day): marking must not change the footprint")
        }
    }

    func testNoDotEverExceedsTheClamp() {
        for day in [1, 30, 90, 174, 200, 365, 1825, 3650] {
            for dot in SpiralGeometry.dots(forDay: day, milestoneDays: cigaretteDays) {
                XCTAssertLessThanOrEqual(dot.diameter, SpiralGeometry.maxDotDiameter)
            }
        }
    }

    /// The flag is what the renderer keys off, so it has to be right in the
    /// range where size could never have carried the signal.
    func testMilestonesAreFlaggedInTheClampedRange() {
        let dots = SpiralGeometry.dots(forDay: 90, milestoneDays: cigaretteDays)
        let marked = dots.enumerated().filter { $0.element.isMilestone }.map { $0.offset + 1 }
        XCTAssertTrue(marked.contains(1))
        XCTAssertTrue(marked.contains(4))    // 72h
        XCTAssertTrue(marked.contains(8))    // 1 week
        XCTAssertTrue(marked.contains(31))   // 1 month
    }

    /// A year marker outranks a milestone — there are only five in a decade.
    func testYearMarkerWinsWhenBothLandOnTheSameDay() {
        let dots = SpiralGeometry.dots(forDay: 365, milestoneDays: [365])
        let last = dots[364]
        XCTAssertTrue(last.isYearMarker)
        XCTAssertEqual(last.diameter,
                       min(13, SpiralGeometry.dotDiameter(count: 365) * 1.6),
                       accuracy: 0.001)
    }

    /// Marking must not move anything.
    func testMarkingDoesNotChangePositions() {
        let plain = SpiralGeometry.dots(forDay: 200)
        let marked = SpiralGeometry.dots(forDay: 200, milestoneDays: cigaretteDays)
        for (a, b) in zip(plain, marked) {
            XCTAssertEqual(a.position.x, b.position.x, accuracy: 0.0001)
            XCTAssertEqual(a.position.y, b.position.y, accuracy: 0.0001)
        }
    }
}

/// The arrival's timing. Eyeballing a curve in a screenshot proves nothing —
/// these pin the properties the animation is supposed to have.
final class RevealRampTests: XCTestCase {

    func testTheNumeralLandsOnTheStreakAndNeverPastIt() {
        for day in [1, 3, 8, 90, 365, 1825] {
            XCTAssertEqual(RevealRamp.displayedDay(atProgress: 1, totalDays: day), day,
                           "day \(day) did not finish on its own number")
            for step in stride(from: 0.0, through: 1.0, by: 0.02) {
                let shown = RevealRamp.displayedDay(atProgress: step, totalDays: day)
                XCTAssertLessThanOrEqual(shown, day, "overshot the real streak at \(step)")
                XCTAssertGreaterThanOrEqual(shown, 1)
            }
        }
    }

    /// The counter deliberately runs one flight window past the streak so the
    /// final dot has somewhere to land. Without it the animation ended with
    /// its last dots frozen in mid-air, which is the failure the rewrite
    /// exists to fix — and it would have looked like a rendering bug.
    func testEveryDotHasLandedByTheEnd() {
        for day in [1, 3, 8, 90, 365, 1825] {
            let counted = RevealRamp.countedDay(atProgress: 1, totalDays: day)
            let window = RevealRamp.flightWindow(forDay: day)
            let lastDotBorn = Double(day - 1)
            let age = (counted - lastDotBorn) / window
            XCTAssertGreaterThanOrEqual(age, 1,
                "day \(day): the newest dot is still in flight when the animation ends")
        }
    }

    /// A three-day streak with a five-day flight window would finish with
    /// every dot still airborne.
    func testShortStreaksGetAShorterFlight() {
        XCTAssertLessThan(RevealRamp.flightWindow(forDay: 3), 2)
        XCTAssertEqual(RevealRamp.flightWindow(forDay: 1825), 5, accuracy: 0.0001)
    }

    func testCountOnlyEverGoesUp() {
        for day in [3, 90, 1825] {
            var previous = -1.0
            for step in stride(from: 0.0, through: 1.0, by: 0.01) {
                let now = RevealRamp.countedDay(atProgress: step, totalDays: day)
                XCTAssertGreaterThanOrEqual(now, previous, "went backwards at \(step)")
                previous = now
            }
        }
    }

    /// The whole point of the exponential: the opening has to be slow enough
    /// that the first days land as separate events, at every streak length.
    func testTheOpeningIsAlwaysSlow() {
        for day in [8, 90, 365, 1825] {
            let atTenPercent = RevealRamp.countedDay(atProgress: 0.1, totalDays: day)
            XCTAssertLessThan(atTenPercent, Double(day) * 0.10,
                              "day \(day) dumped too much of the streak up front")
        }
    }

    func testItAcceleratesRatherThanRunningFlat() {
        let day = 365
        let first = RevealRamp.countedDay(atProgress: 0.5, totalDays: day)
        let second = RevealRamp.countedDay(atProgress: 1, totalDays: day) - first
        XCTAssertGreaterThan(second, first * 2,
                             "the second half should cover far more days than the first")
    }

    /// A longer streak must visibly take longer to arrive — that is the
    /// emotional claim the whole animation rests on.
    func testLongerStreaksTakeLonger() {
        let short = RevealRamp.duration(forDay: 3)
        let medium = RevealRamp.duration(forDay: 90)
        let long = RevealRamp.duration(forDay: 1825)
        XCTAssertLessThan(short, medium)
        XCTAssertLessThan(medium, long)
        // ...but never long enough to be a wait on every cold launch.
        XCTAssertLessThanOrEqual(long, 3.0)
        XCTAssertGreaterThanOrEqual(short, 1.0)
    }
}

/// The arrival must not save half the streak for the last blink.
///
/// A pure exponential did exactly that — measured off a capture, five years
/// was only at day 907 with 90% of the animation elapsed, so 918 days landed
/// in the final third of a second. That is the same "it all appears at once"
/// the count-up replaced, moved to the end.
final class RevealTailTests: XCTestCase {

    func testTheEndDoesNotDumpTheStreak() {
        for day in [90, 365, 1825] {
            let atNinety = RevealRamp.countedDay(atProgress: 0.9, totalDays: day)
            let total = RevealRamp.countedDay(atProgress: 1, totalDays: day)
            let leftForTheLastTenth = (total - atNinety) / total
            XCTAssertLessThan(leftForTheLastTenth, 0.35,
                "day \(day): \(Int(leftForTheLastTenth * 100))% of the streak arrives in the last 10% of the time")
        }
    }

    /// ...while the opening still has to be slow enough to read.
    func testTheOpeningStaysSlowAfterTheEasing() {
        for day in [90, 365, 1825] {
            let atTenth = RevealRamp.countedDay(atProgress: 0.1, totalDays: day)
            let total = RevealRamp.countedDay(atProgress: 1, totalDays: day)
            XCTAssertLessThan(atTenth / total, 0.06,
                              "day \(day) opened too fast to read individual days")
        }
    }
}

/// The pacing of the craving screen's breath.
///
/// Two defects lived here and neither was visible in a screenshot: the curve
/// began the inhale at its fastest, so every breath opened with a lurch; and
/// it silently added about a second and a half to whatever hold was
/// prescribed.
final class BreathPatternTests: XCTestCase {

    private let pattern = BreathPattern.standard

    func testTheChosenPacing() {
        XCTAssertEqual(pattern.inhale, 4)
        XCTAssertEqual(pattern.hold, 1)
        XCTAssertEqual(pattern.exhale, 6)
        XCTAssertEqual(pattern.cycle, 11)
        XCTAssertEqual(pattern.breathsPerMinute, 60.0 / 11, accuracy: 0.001)
    }

    /// The exhale has to be longer than the inhale — that lengthening is the
    /// vagal lever, and it is the whole reason the app is called Exhale.
    func testTheExhaleIsLongerThanTheInhale() {
        XCTAssertGreaterThan(pattern.exhale, pattern.inhale)
    }

    /// The defect the user felt before any measurement found it: the old curve
    /// left the bottom at 0.549 of fullness per second, its fastest moment of
    /// the whole inhale, so the breath began with a jump. A raised cosine
    /// starts from rest and peaks in the middle, which is how lungs fill.
    func testTheInhaleStartsFromRest() {
        let step = 1.0 / 120
        let atStart = (pattern.state(at: step).fullness
            - pattern.state(at: 0).fullness) / step
        let atMiddle = (pattern.state(at: pattern.inhale / 2 + step).fullness
            - pattern.state(at: pattern.inhale / 2).fullness) / step

        XCTAssertLessThan(atStart, 0.05, "the inhale still lurches off the bottom")
        XCTAssertGreaterThan(atMiddle, atStart * 4,
                             "the breath should be quickest in the middle, not at the start")
    }

    func testItRunsEmptyToFullAndBack() {
        XCTAssertEqual(pattern.state(at: 0).fullness, 0, accuracy: 0.001)
        XCTAssertEqual(pattern.state(at: pattern.inhale).fullness, 1, accuracy: 0.001)
        XCTAssertEqual(pattern.state(at: pattern.cycle - 0.001).fullness, 0, accuracy: 0.01)
    }

    func testThePhasesLandWhereTheySay() {
        XCTAssertEqual(pattern.state(at: 1).phase, .inhale)
        XCTAssertEqual(pattern.state(at: 4.5).phase, .hold)
        XCTAssertEqual(pattern.state(at: 7).phase, .exhale)
        // ...and it wraps rather than running off the end.
        XCTAssertEqual(pattern.state(at: pattern.cycle + 1).phase, .inhale)
        XCTAssertEqual(pattern.state(at: -1).phase, .exhale)
    }

    /// Easing quietly rewrites the pattern: the time actually spent near full
    /// is longer than the prescribed hold. That is acceptable and predictable
    /// with a raised cosine — it was 1.5s with the old curve — but it must not
    /// run away.
    func testTheApexDoesNotOutstayThePattern() {
        var nearFull = 0.0
        let step = 0.01
        var t = 0.0
        while t < pattern.cycle {
            if pattern.state(at: t).fullness >= 0.97 { nearFull += step }
            t += step
        }
        XCTAssertGreaterThan(nearFull, pattern.hold,
                             "easing should soften the apex, not remove it")
        XCTAssertLessThan(nearFull, pattern.hold + 1.4,
                          "the curve is adding more hold than it was asked for")
    }

    func testTheInstructionFadesAtEveryHandover() {
        for boundary in [0.0, pattern.inhale, pattern.inhale + pattern.hold] {
            XCTAssertLessThan(pattern.instructionOpacity(at: boundary), 0.05,
                              "the word swaps in plain sight at \(boundary)s")
        }
        XCTAssertEqual(pattern.instructionOpacity(at: pattern.inhale / 2), 1, accuracy: 0.001)
    }
}
