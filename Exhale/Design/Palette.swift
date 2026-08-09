import SwiftUI

/// Design tokens from the handoff. The app is dark-only by design — there is no
/// light theme and none should be added.
enum Palette {
    // Surfaces
    static let background = Color(hex: 0x081A1D)
    static let cravingOverlay = Color(hex: 0x051417).opacity(0.98)
    static let bannerBackground = Color(hex: 0x162A2D).opacity(0.96)
    static let bannerIconTile = Color(hex: 0x0C2225)

    // Text
    static let textPrimary = Color(hex: 0xE9F5F3)
    static let textBrightest = Color(hex: 0xEFFCF9)
    static let textMuted = Color(hex: 0xE9F5F3).opacity(0.55)
    static let textFaint = Color(hex: 0xE9F5F3).opacity(0.40)

    // Brand
    static let accent = Color(hex: 0x7FD8CB)
    static let onAccent = Color(hex: 0x06181B)
    static let accentSoft = Color(hex: 0xBDEDE4)

    // Ember
    static let ember = Color(hex: 0xE8743B)
    static let emberSoft = Color(hex: 0xE8A87F)

    // Lines
    static let hairline = Color(hex: 0xE9F5F3).opacity(0.08)
    static let cardBorder = Color(hex: 0xE9F5F3).opacity(0.15)
    static let stepperBorder = Color(hex: 0xE9F5F3).opacity(0.30)

    // The Bill — printed receipt, deliberately a different world
    static let paper = Color(hex: 0xF4EFE4)
    static let ink = Color(hex: 0x1A1714)
    static let paperAccent = Color(hex: 0xB8542C)

    /// The spiral's ember → sea-glass ramp, `t` from 0 (oldest) to 1 (newest).
    /// Source is HSL; SwiftUI takes HSB, so convert rather than eyeball it.
    ///
    /// `lift` brightens the dot without shifting its hue, used for the brief
    /// flash as each one lands during the reveal. Done here rather than with
    /// `Color.mix(with:by:)`, which is iOS 18 and would not compile against our
    /// iOS 17 target.
    static func spiralDot(ramp t: Double, lift: Double = 0) -> Color {
        Color(
            hslHue: 18 + t * 154,
            saturation: (85 - t * 25) / 100,
            lightness: min(1, (54 + t * 8) / 100 + lift)
        )
    }

    /// A dot on the breathing orb's surface, lit by `shade` (0 = facing away
    /// from the light, 1 = facing it). Fixed hue, so the body reads as one
    /// object under one light rather than as a colour ramp.
    static func orbDot(shade: Double) -> Color {
        Color(hslHue: 170, saturation: 0.52,
              lightness: min(1, (46 + shade * 44) / 100))
    }

    static let yearMarker = Color(hex: 0xE8A87F)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// HSL → HSB. The design tokens are authored in CSS `hsl()`, which is *not*
    /// what `Color(hue:saturation:brightness:)` expects; using them directly
    /// would wash every dot out.
    init(hslHue degrees: Double, saturation s: Double, lightness l: Double) {
        let v = l + s * min(l, 1 - l)
        let sv = v <= 0 ? 0 : 2 * (1 - l / v)
        self.init(
            hue: (degrees.truncatingRemainder(dividingBy: 360)) / 360,
            saturation: sv,
            brightness: v
        )
    }
}
