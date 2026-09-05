# NAVIGATION_MAP.md — Android routes → iOS NavigationStack

Mirrors `Screen.kt` (routes) + `NavGraph.kt` (composition + start-destination logic). iOS uses SwiftUI `NavigationStack` + type-safe route enums per role; the root switches on session/role.

**Start-destination logic (from `SplashViewModel`):**
```
splash not ready        → Loading
onboarding incomplete   → Onboarding
not logged in           → Login?role=student
logged in + VENDOR      → Vendor Dashboard
logged in + ADMIN       → Admin Dashboard
else (STUDENT)          → Home
```

---

## Route table

| Android route | Param | iOS destination | Role |
|---|---|---|---|
| `splash` | — | `SplashView` (then routes) | all |
| `onboarding` | — | `OnboardingView` | all |
| `login?role={role}` | role (default `student`) | `LoginView(role:)` | all |
| `register` | — | `RegisterView` | student |
| `home` | — | `HomeView` (tab root) | student |
| `search?query={query}` | query | `SearchView` | student |
| `search_results?query={query}` | query | `SearchResultsView(query:)` | student |
| `outlets` | — | `OutletListView` | student |
| `outlet/{outletId}` | outletId | `OutletDetailView(outletId:)` | student |
| `food/{foodId}` | foodId | `FoodDetailView(foodId:)` | student |
| `cart` | — | `CartView` | student |
| `checkout` | — | `CheckoutView` | student |
| `order_confirmation/{orderId}` | orderId | `OrderConfirmationView(orderId:)` → `OrderDetailView` | student |
| `track_order/{orderId}` | orderId | `LiveOrderTrackingView(orderId:)` | student |
| `pickup_qr/{orderId}` | orderId | `PickupQRCodeView(orderId:)` | student |
| `orders` | — | `OrderHistoryView` | student |
| `order/{orderId}` | orderId | `OrderDetailView(orderId:)` | student |
| `favourites` | — | `FavoritesView` | student |
| `notifications` | — | `NotificationsView` | student |
| `profile` | — | `ProfileView` | student |
| `settings` | — | `SettingsView` | student |
| `help` | — | `HelpView` | student |
| `vendor/dashboard` | — | `VendorDashboardView` (tab root) | vendor |
| `vendor/orders` | — | `VendorOrdersView` | vendor |
| `vendor/order/{orderId}` | orderId | `VendorOrderDetailView(orderId:)` | vendor |
| `vendor/menu` | — | `VendorMenuView` | vendor |
| `vendor/food/{foodId}` | foodId | `VendorFoodEditView(foodId:)` | vendor |
| `vendor/analytics` | — | `VendorAnalyticsView` | vendor |
| `vendor/profile` | — | `VendorProfileView` | vendor |
| `vendor/qr_scanner` | — | `QRScannerView` | vendor |
| `admin/dashboard` | — | `AdminDashboardView` (tab root) | admin |
| `admin/users` · `admin/vendors` · `admin/outlets` · `admin/orders` · `admin/analytics` · `admin/settings` | — | Admin sub-views | admin |

---

## Bottom navigation (Android `GagBottomNav`)

- **Student tabs:** Home · Search · Orders · Notifications · Profile (top-level screens: Home, Search, OrderHistory, Notifications, Profile — `onNavigateBottom` keeps single-top + saves/restores state).
- **Vendor tabs:** Dashboard · Orders · Menu · (Profile).
- **Admin:** Dashboard + sub-route nav.

## iOS structure sketch

```swift
enum StudentRoute: Hashable { case search(query: String), outlets, outlet(String), food(String), cart, checkout, orderConfirmation(String), trackOrder(String), pickupQR(String), orderDetail(String), favourites, notifications, settings, help }

struct RootView: View {
    @Environment(AppState.self) var app
    var body: some View {
        switch app.route {
        case .onboarding: OnboardingView()
        case .login: LoginView(role: app.pendingRole)
        case .student: StudentTabView()          // TabView + NavigationStack
        case .vendor: VendorTabView()
        case .admin: AdminTabView()
        }
    }
}
```

Transitions mirror Android slide/fade (`transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), ...))`).

## Navigation actions (from NavGraph.kt)

- Checkout success → `order_confirmation/{orderId}` popping up to Home.
- Order Confirmation/Detail ↔ Live Tracking ↔ Pickup QR (bidirectional).
- Login success → role destination, `popUpTo(login, inclusive)`.
- Logout → `popUpTo(0, inclusive)` then Login.
- Profile → Settings / Help / Orders / Favourites.
- Notifications → deep-link to `order/{orderId}`.
