import SwiftUI

struct SplashView: View {
    @Environment(AppState.self) private var appState
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            AppTheme.screenBackground
            
            VStack(spacing: GagShapes.spacingXL) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(GagColors.brandOrange)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text(AppConfig.appDisplayName)
                    .font(GagTypography.displayLarge)
                    .foregroundStyle(GagColors.onBackground)
                    .opacity(logoOpacity)
                
                Text(AppConfig.appTagline)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .opacity(logoOpacity)
            }
            
            VStack {
                Spacer()
                if !appState.isBackendConfigured {
                    GagNotConfiguredBanner()
                        .padding(.horizontal, GagShapes.spacingL)
                        .padding(.bottom, GagShapes.spacingXL)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}
