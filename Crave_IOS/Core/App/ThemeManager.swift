import Foundation
import Observation
import SwiftUI

/// App-wide appearance preference (mirrors Android ThemeMode SYSTEM/LIGHT/DARK).
nonisolated enum AppThemeMode: String, Sendable, CaseIterable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private static let storageKey = "crave.themeMode"

    var mode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        // QA/UI-test override: `-crave-appearance light|dark|system`.
        // Documented for screenshots and automated verification; the stored
        // preference wins when no launch argument is present.
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-crave-appearance"),
           args.indices.contains(index + 1),
           let forced = AppThemeMode(rawValue: args[index + 1].uppercased()) {
            self.mode = forced
            return
        }
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.mode = AppThemeMode(rawValue: raw) ?? .system
    }

    var colorScheme: ColorScheme? { mode.colorScheme }
}
