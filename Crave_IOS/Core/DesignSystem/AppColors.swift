import SwiftUI
import UIKit

// =============================================================================
// Color palette ported 1:1 from the Android app (core/ui/theme/Color.kt).
// Static colors are fixed hex values; adaptive colors switch with dark/light.
// =============================================================================

nonisolated extension Color {
    /// Initialize from a 0xRRGGBB hex value.
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Initialize with separate light/dark hex values that adapt to the trait collection.
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Central colour catalogue for Crave.
nonisolated enum GagColors {
    // ─── Brand ────────────────────────────────────────────────────
    static let brandOrange = Color(hex: 0xE8431A)
    static let brandOrangeLight = Color(hex: 0xFF6B3D)
    static let brandOrangeDark = Color(hex: 0xC4320E)
    static let brandOrangeContainer = Color(hex: 0xFFD9CF)
    static let onBrandOrangeContainer = Color(hex: 0x3B0900)

    static let amber = Color(hex: 0xF59E0B)
    static let amberLight = Color(hex: 0xFBBF24)
    static let amberDark = Color(hex: 0xD97706)

    // ─── Adaptive surfaces (dark + light) ─────────────────────────
    static let background = Color(light: 0xF9FAFB, dark: 0x0F0F0F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1A1A)
    static let surfaceVariant = Color(light: 0xF3F4F6, dark: 0x252525)
    static let surfaceHighest = Color(light: 0xE5E7EB, dark: 0x2E2E2E)
    static let outline = Color(light: 0xD1D5DB, dark: 0x3D3D3D)
    static let outlineVariant = Color(light: 0xE5E7EB, dark: 0x2A2A2A)

    // ─── Adaptive text ────────────────────────────────────────────
    static let onBackground = Color(light: 0x111827, dark: 0xF5F5F5)
    static let onSurface = Color(light: 0x1F2937, dark: 0xEEEEEE)
    static let onSurfaceVariant = Color(light: 0x4B5563, dark: 0xAAAAAA)
    static let onSurfaceDim = Color(light: 0x9CA3AF, dark: 0x6B6B6B)

    // ─── Semantic (adaptive: darker hues on light, vivid on dark) ──
    static let success = Color(light: 0x16A34A, dark: 0x22C55E)
    static let successContainer = Color(light: 0xDCFCE7, dark: 0x0D2818)
    static let error = Color(light: 0xDC2626, dark: 0xEF4444)
    static let errorContainer = Color(light: 0xFEE2E2, dark: 0x2D0000)
    static let warning = Color(light: 0xD97706, dark: 0xF59E0B)
    static let warningContainer = Color(light: 0xFEF3C7, dark: 0x2D1900)
    static let info = Color(light: 0x2563EB, dark: 0x3B82F6)

    // ─── Order status (adaptive; text + 12% tint in OrderStatusBadge) ──
    static let statusCreated = Color(light: 0x64748B, dark: 0x94A3B8)
    static let statusPlaced = Color(light: 0x2563EB, dark: 0x3B82F6)
    static let statusAccepted = Color(light: 0x7C3AED, dark: 0x8B5CF6)
    static let statusPreparing = Color(light: 0xD97706, dark: 0xF59E0B)
    static let statusReady = Color(light: 0x16A34A, dark: 0x22C55E)
    static let statusPickedUp = Color(hex: 0x6B7280)
    static let statusCancelled = Color(light: 0xDC2626, dark: 0xEF4444)
    static let statusRejected = Color(light: 0xDC2626, dark: 0xEF4444)
    static let statusExpired = Color(hex: 0x6B7280)
    static let statusRefunded = Color(light: 0x0891B2, dark: 0x06B6D4)

    // ─── Pickup slots (adaptive) ────────────────────────────────
    static let slotAvailable = Color(light: 0x16A34A, dark: 0x22C55E)
    static let slotLimited = Color(light: 0xD97706, dark: 0xF59E0B)
    static let slotFull = Color(light: 0xDC2626, dark: 0xEF4444)

    // ─── Food categories ──────────────────────────────────────────
    static let categoryMeals = Color(hex: 0xE8431A)
    static let categoryFastFood = Color(hex: 0xF59E0B)
    static let categoryBeverages = Color(hex: 0x3B82F6)
    static let categoryPizza = Color(hex: 0xEC4899)
    static let categorySnacks = Color(hex: 0x10B981)
    static let categoryChinese = Color(hex: 0x8B5CF6)
    static let categoryDesserts = Color(hex: 0xF97316)

    // ─── Veg / non-veg (adaptive; always paired with shape/label, never color-only)
    static let vegGreen = Color(light: 0x16A34A, dark: 0x22C55E)
    static let nonVegRed = Color(light: 0xDC2626, dark: 0xEF4444)

    // ─── Gradients ────────────────────────────────────────────────
    static let gradientStart = Color(hex: 0xE8431A)
    static let gradientEnd = Color(hex: 0xF59E0B)
    static let gradientDarkStart = Color(hex: 0x0F0F0F)
    static let gradientDarkEnd = Color(hex: 0x1A0A00)

    // ─── Crave 2.0 brand tokens ─────────────────────────────────
    // Warm cream/charcoal identity. Contrast-verified pairs (AA normal):
    // ink (18.1) + primary deep red (7.8) on craveBackground light;
    // craveAccent (#EA2A2A, 3.7) is GRAPHICS-ONLY — never body text.
    // Dark variants are deliberate (warm charcoal), not inversions.
    static let craveBackground = Color(light: 0xF4ECEC, dark: 0x171111)
    static let craveSurface = Color(light: 0xFFFFFF, dark: 0x241C1C)
    static let craveSurfaceVariant = Color(light: 0xEADDDD, dark: 0x322828)
    static let craveInk = Color(light: 0x000000, dark: 0xFFF7F5)
    static let craveMuted = Color(light: 0x4A3F3F, dark: 0xD8C4C2)
    static let cravePrimary = Color(light: 0x8D1B1B, dark: 0xFF8A5C)
    static let cravePrimaryContainer = Color(light: 0xF5C9B8, dark: 0x4A1E0A)
    static let craveOnPrimary = Color(light: 0xFFFFFF, dark: 0x1A0A00)
    /// Brand red for large display type, icons, illustration fills ONLY.
    /// 3.7:1 on cream — fails AA body text by design. Never body/label text.
    static let craveAccent = Color(light: 0xEA2A2A, dark: 0xFF5A5A)
    static let craveDeepRed = Color(light: 0x8D1B1B, dark: 0xB6503C)

    // ─── Overlays & chrome ────────────────────────────────────────
    static let cardOverlayDark = Color(hex: 0x000000, opacity: 0.8)
    static let cardOverlayLight = Color(hex: 0xFFFFFF, opacity: 0.1)
    static let bottomNavBackground = Color(light: 0xFFFFFF, dark: 0x141414)
    static let bottomNavBorder = Color(light: 0xE5E7EB, dark: 0x252525)
}
