import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            image: "fork.knife.circle.fill",
            title: "Discover Campus Food",
            description: "Browse menus from all your favorite campus outlets in one place."
        ),
        OnboardingPage(
            image: "clock.fill",
            title: "Order Ahead",
            description: "Place your order and pick it up when ready. Skip the queue entirely."
        ),
        OnboardingPage(
            image: "heart.fill",
            title: "Save Favorites",
            description: "Mark your go-to items for quick reordering next time."
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            GagButton(
                title: currentPage == pages.count - 1 ? "Get Started" : "Next",
                action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        appState.completeOnboarding()
                    }
                }
            )
            .padding(.horizontal, GagShapes.spacingXL)
            .padding(.bottom, GagShapes.spacingXXL)
        }
        .background(AppTheme.screenBackground)
    }
}

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: GagShapes.spacingXL) {
            Spacer()
            
            Image(systemName: page.image)
                .font(.system(size: 100))
                .foregroundStyle(GagColors.brandOrange)
            
            VStack(spacing: GagShapes.spacingM) {
                Text(page.title)
                    .font(GagTypography.displayMedium)
                    .foregroundStyle(GagColors.onBackground)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(GagTypography.bodyLarge)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GagShapes.spacingXL)
            }
            
            Spacer()
        }
        .padding()
    }
}
