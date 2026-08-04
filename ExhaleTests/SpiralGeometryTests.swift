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
        XCTAssertEqual(band.inner, SpiralGeometry.holeRadius, accuracy: 0.0001)
        XCTAssertEqual(band.outer, SpiralGeometry.maxRadius, accuracy: 0.0001)
    }

    /// The bug the bloom exists to fix: on day 1 the spec put the only dot out
    /// at the rim. It should sit clear of the numeral instead.
    func testEarlyDotsAreVisibleAndClearOfTheCentreLabel() {
        for day in 1...14 {
            let veil = SpiralGeometry.veil(day: day)
            for dot in SpiralGeometry.dots(forDay: day) {
                let dx = dot.position.x - SpiralGeometry.centre.x
                let dy = dot.position.y - SpiralGeometry.centre.y
                let radius = (dx * dx + dy * dy).squareRoot()

                XCTAssertGreaterThan(
                    radius, veil.solid,
                    "day \(day): a dot sits inside the solid centre veil and is invisible"
                )
                XCTAssertLessThanOrEqual(
                    radius, SpiralGeometry.maxRadius,
                    "day \(day): a dot escaped the disc"
                )
            }
        }
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

    func testLogoIsFiftyFiveDots() {
        XCTAssertEqual(LogoGeometry.dots().count, 55)
    }

    func testLogoScalesProportionally() {
        let small = LogoGeometry.dots(box: 26)
        let large = LogoGeometry.dots(box: 104)
        XCTAssertEqual(large[10].diameter / small[10].diameter, 4, accuracy: 0.001)
    }
}

final class SeedTests: XCTestCase {
    /// Every advertised seed must actually resolve — otherwise the screenshot
    /// job silently captures the wrong screen.
    func testEverySeedResolves() {
        for name in SeedNames.all {
            XCTAssertNotNil(Seed.model(named: name), "seed '\(name)' does not resolve")
        }
    }

    func testSmokeSetIsSubsetOfAll() {
        XCTAssertTrue(Set(SeedNames.smoke).isSubset(of: Set(SeedNames.all)))
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
            return BreathingOrb(
                phasePosition: elapsed.truncatingRemainder(dividingBy: 14),
                reduceMotion: true
            ).label
        }
        XCTAssertEqual(phases, ["Breathe in", "Hold it", "Let it go"])
    }
}
