import CoreText
import SwiftUI

/// Brand typeface wiring.
///
/// Orbit Regular (Sooun Cho / JAMO Typeface) is SIL OFL 1.1 — bundling in the
/// app is explicitly permitted; `OFL.txt` ships alongside and Settings →
/// About attributes it (see `SettingsView`). Single weight: do NOT request
/// bold/black cuts (they don't exist — use size and color for emphasis).
/// Body/UI text stays on system TextStyles for Dynamic Type; Orbit is for
/// display roles only (heroes, category titles, large prices, brand moments).
nonisolated enum CraveFonts {
    static let orbitName = "Orbit-Regular"

    static func register() {
        guard let url = Bundle.main.url(forResource: "Orbit-Regular", withExtension: "ttf") else {
            print("⚠️ [Fonts] Orbit-Regular.ttf missing from bundle")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            print("⚠️ [Fonts] Orbit registration failed: \(String(describing: error))")
        }
    }

    /// Display font at an explicit size. Sizes here are design sizes; prefer
    /// `orbitScaled` where the text must grow with Dynamic Type.
    static func orbit(size: CGFloat) -> Font {
        Font.custom(orbitName, size: size)
    }

    /// Display font honoring Dynamic Type via a scaled metric.
    static func orbitScaled(size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        Font.custom(orbitName, size: size, relativeTo: style)
    }
}
