import SwiftUI

/// Two typefaces, doing deliberately different jobs.
///
/// - **Space Grotesk** everywhere in the app proper.
/// - **Archivo / Archivo Black** only inside The Bill, so the receipt reads as a
///   printed object that wandered into a digital app.
///
/// Sizes are the design's point sizes, scaled by Dynamic Type via
/// `relativeTo:` so the app still respects the user's text size.
extension Font {
    static func spaceGrotesk(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        .custom(SpaceGrotesk.name(for: weight), size: size, relativeTo: style)
    }

    static func archivo(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> Font {
        // Font.Weight isn't Comparable, so match rather than compare.
        let face: String
        switch weight {
        case .semibold, .bold, .heavy, .black: face = "Archivo-SemiBold"
        case .medium: face = "Archivo-Medium"
        default: face = "Archivo-Regular"
        }
        return .custom(face, size: size, relativeTo: style)
    }

    /// The money figure and row values on The Bill.
    static func archivoBlack(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("ArchivoBlack-Regular", size: size, relativeTo: style)
    }
}

private enum SpaceGrotesk {
    static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "SpaceGrotesk-Bold"
        case .medium, .semibold: "SpaceGrotesk-Medium"
        default: "SpaceGrotesk-Regular"
        }
    }
}

