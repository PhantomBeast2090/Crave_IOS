import SwiftUI

/// Typography scale used across the app (FontFamily.Default in Android terms).
///
/// All slots use TextStyles (not fixed sizes) so they follow Dynamic Type.
/// Default-size mapping preserves the previous fixed sizes, except for three
/// ±1pt approximations noted below (22→24 had no matching style, etc.).
nonisolated enum GagTypography {
    // Display
    static let displayLarge = Font.system(.largeTitle).weight(.bold) // 34
    static let displayMedium = Font.system(.title).weight(.bold) // 28
    static let displaySmall = Font.system(.title2).weight(.bold) // 22 (was 24)

    // Titles
    static let titleLarge = Font.system(.title2).weight(.semibold) // 22
    static let titleMedium = Font.system(.headline).weight(.semibold) // 17 (was 18)
    static let titleSmall = Font.system(.callout).weight(.semibold) // 16

    // Body
    static let bodyLarge = Font.system(.callout) // 16
    static let bodyMedium = Font.system(.subheadline) // 15 (was 14)
    static let bodySmall = Font.system(.caption) // 12

    // Labels
    static let labelLarge = Font.system(.subheadline).weight(.medium) // 15 (was 14)
    static let labelMedium = Font.system(.caption).weight(.medium) // 12
    static let labelSmall = Font.system(.caption2).weight(.medium) // 11 (was 10)
}
