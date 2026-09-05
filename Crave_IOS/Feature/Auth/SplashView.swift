import SwiftUI

/// Launch splash — restores the session and routes on completion.
struct SplashView: View {
    @Environment(AppState.self) private var appState
    @State private var didLaunch = false

    var body: some View {
        ZStack {
            GagColors.background.ignoresSafeArea()
            VStack(spacing: GagShapes.spacingM) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(GagColors.brandOrange)
                Text(AppConfig.appDisplayName)
                    .font(GagTypography.displayMedium)
                    .foregroundStyle(GagColors.onBackground)
                Text(AppConfig.appTagline)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
            }
        }
        .task {
            guard !didLaunch else { return }
            didLaunch = true
            await appState.launch()
        }
    }
}

#Preview {
    SplashView()
        .environment(AppState())
}
