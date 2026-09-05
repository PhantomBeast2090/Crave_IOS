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

    // ─── Semantic ─────────────────────────────────────────────────
    static let success = Color(hex: 0x22C55E)
    static let successContainer = Color(hex: 0x0D2818)
    static let error = Color(hex: 0xEF4444)
    static let errorContainer = Color(hex: 0x2D0000)
    static let warning = Color(hex: 0xF59E0B)
    static let warningContainer = Color(hex: 0x2D1900)
    static let info = Color(hex: 0x3B82F6)

    // ─── Order status ─────────────────────────────────────────────
    static let statusCreated = Color(hex: 0x94A3B8)
    static let statusPlaced = Color(hex: 0x3B82F6)
    static let statusAccepted = Color(hex: 0x8B5CF6)
    static let statusPreparing = Color(hex: 0xF59E0B)
    static let statusReady = Color(hex: 0x22C55E)
    static let statusPickedUp = Color(hex: 0x6B7280)
    static let statusCancelled = Color(hex: 0xEF4444)
    static let statusRejected = Color(hex: 0xEF4444)
    static let statusExpired = Color(hex: 0x6B7280)
    static let statusRefunded = Color(hex: 0x06B6D4)

    // ─── Pickup slots ─────────────────────────────────────────────
    static let slotAvailable = Color(hex: 0x22C55E)
    static let slotLimited = Color(hex: 0xF59E0B)
    static let slotFull = Color(hex: 0xEF4444)

    // ─── Food categories ──────────────────────────────────────────
    static let categoryMeals = Color(hex: 0xE8431A)
    static let categoryFastFood = Color(hex: 0xF59E0B)
    static let categoryBeverages = Color(hex: 0x3B82F6)
    static let categoryPizza = Color(hex: 0xEC4899)
    static let categorySnacks = Color(hex: 0x10B981)
    static let categoryChinese = Color(hex: 0x8B5CF6)
    static let categoryDesserts = Color(hex: 0xF97316)

    // ─── Veg / non-veg ────────────────────────────────────────────
    static let vegGreen = Color(hex: 0x22C55E)
    static let nonVegRed = Color(hex: 0xEF4444)

    // ─── Gradients ────────────────────────────────────────────────
    static let gradientStart = Color(hex: 0xE8431A)
    static let gradientEnd = Color(hex: 0xF59E0B)
    static let gradientDarkStart = Color(hex: 0x0F0F0F)
    static let gradientDarkEnd = Color(hex: 0x1A0A00)

    // ─── Overlays & chrome ────────────────────────────────────────
    static let cardOverlayDark = Color(hex: 0x000000, opacity: 0.8)
    static let cardOverlayLight = Color(hex: 0xFFFFFF, opacity: 0.1)
    static let bottomNavBackground = Color(light: 0xFFFFFF, dark: 0x141414)
    static let bottomNavBorder = Color(light: 0xE5E7EB, dark: 0x252525)
}
