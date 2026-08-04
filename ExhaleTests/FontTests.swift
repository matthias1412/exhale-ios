import XCTest
import UIKit
@testable import Exhale

/// `Font.custom` fails **silently** — a wrong PostScript name falls back to the
/// system face, which looks almost right and is therefore easy to ship.
///
/// This nearly happened: Space Grotesk and Archivo ship from Google Fonts as
/// variable fonts whose named instances expose no usable PostScript names, so
/// every `SpaceGrotesk-*` call in the app would have rendered in San Francisco.
/// These tests turn that into a build failure.
final class FontTests: XCTestCase {

    private let required = [
        "SpaceGrotesk-Regular",
        "SpaceGrotesk-Medium",
        "SpaceGrotesk-Bold",
        "Archivo-Regular",
        "Archivo-Medium",
        "Archivo-SemiBold",
        "ArchivoBlack-Regular"
    ]

    func testEveryCustomFontResolves() {
        for name in required {
            let font = UIFont(name: name, size: 17)
            XCTAssertNotNil(
                font,
                "'\(name)' did not register — Font.custom will silently fall back to the system face"
            )
            XCTAssertEqual(font?.fontName, name, "'\(name)' resolved to something else")
        }
    }

    /// The bundled files must actually be in the app bundle, not merely on disk.
    func testFontFilesAreBundled() {
        for name in required {
            XCTAssertNotNil(
                Bundle.main.url(forResource: name, withExtension: "ttf"),
                "\(name).ttf is missing from the bundle"
            )
        }
    }

    /// The Bill's money figure and every ticking counter must be monospaced or
    /// they jitter while counting up.
    func testArchivoBlackHasTabularFigures() throws {
        let font = try XCTUnwrap(UIFont(name: "ArchivoBlack-Regular", size: 54))
        let tabular = UIFont(
            descriptor: font.fontDescriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
                ]]
            ]),
            size: 54
        )
        let one = ("1" as NSString).size(withAttributes: [.font: tabular])
        let eight = ("8" as NSString).size(withAttributes: [.font: tabular])
        XCTAssertEqual(one.width, eight.width, accuracy: 0.5,
                       "digits are not tabular — the money figure will jitter as it ticks")
    }
}
