import SwiftUI

/// Corner radii and shape helpers, matching Android's Shape.kt (4/8/12/16/24dp).
nonisolated enum GagShapes {
    static let radiusSmall: CGFloat = 4
    static let radiusMedium: CGFloat = 8
    static let radiusLarge: CGFloat = 12
    static let radiusXLarge: CGFloat = 16
    static let radiusXXLarge: CGFloat = 24
    static let radiusPill: CGFloat = 999

    /// Standard spacing scale (Android uses 4pt grid).
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    static func cornerRadius(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}
