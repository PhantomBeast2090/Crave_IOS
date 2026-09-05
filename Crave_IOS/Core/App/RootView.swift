import SwiftUI

/// Root router — switches on `AppState.phase`.
/// Mirrors GagNavGraph's start-destination logic.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.phase {
        case .splash:
            SplashView()
        case .onboarding:
            OnboardingView()
        case .login(let role):
            LoginView(roleHint: role)
        case .main(let role):
            switch role {
            case .student: StudentFlow()
            case .vendor: VendorFlow()
            case .admin: AdminFlow()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
