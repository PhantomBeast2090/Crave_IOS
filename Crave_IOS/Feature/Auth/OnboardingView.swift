import SwiftUI

/// Onboarding — three pages introducing the app, then "Get Started".
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "storefront",
            title: "Explore outlets",
            subtitle: "Discover canteens and outlets across campus with live menus, ratings and wait times."
        ),
        OnboardingPage(
            icon: "bag.fill",
            title: "Order ahead",
            subtitle: "Build your cart with customizations, pick a pickup slot, and pay securely online."
        ),
        OnboardingPage(
            icon: "qrcode.viewfinder",
            title: "Skip the queue",
            subtitle: "Show your QR at the outlet and grab your food the moment it's ready."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? GagColors.brandOrange : GagColors.outline)
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(duration: 0.25), value: currentPage)
                }
            }
            .padding(.bottom, GagShapes.spacingXL)

            GagButton(
                title: currentPage == pages.count - 1 ? "Get Started" : "Next",
                action: next
            )
            .padding(.horizontal, GagShapes.spacingXL)
            .padding(.bottom, GagShapes.spacingXXL)
        }
        .background(GagColors.background)
        .toolbar(.hidden)
    }

    private func next() {
        if currentPage == pages.count - 1 {
            appState.completeOnboarding()
        } else {
            withAnimation(.spring(duration: 0.3)) { currentPage += 1 }
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: GagShapes.spacingXL) {
            ZStack {
                Circle()
                    .fill(GagColors.brandOrange.opacity(0.12))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(GagColors.brandOrange.opacity(0.08))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(GagColors.brandOrange)
            }
            .padding(.top, 60)

            Text(page.title)
                .font(GagTypography.titleLarge)
                .foregroundStyle(GagColors.onBackground)

            Text(page.subtitle)
                .font(GagTypography.bodyLarge)
                .foregroundStyle(GagColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GagShapes.spacingXXL)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
