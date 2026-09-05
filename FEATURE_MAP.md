# FEATURE_MAP.md — Android feature inventory → iOS implementation

Maps every Android feature/screen to its iOS deliverable. Sourced from the Android `feature/` package.

Legend: ✅ implemented · 🔄 in progress · ⬜ pending · 🟡 parity-question (needs Category-C answer)

---

## Auth (`feature/auth/`)

| # | Android (Kotlin) | iOS (SwiftUI) | Status | Notes |
|---|---|---|---|---|
| A1 | Splash (restore session, decide start) | `SplashView` | ⬜ | GoTrue `restoreSession()`, then Onboarding→Login→role route |
| A2 | Onboarding | `OnboardingView` | ⬜ | mark onboarding-complete (AppStorage) |
| A3 | Login (`?role=`) | `LoginView` | ⬜ | creates `profiles` row on first verified login; role arg defaults student |
| A4 | Register (student) | `RegisterView` | ⬜ | profile self-INSERT allowed by RLS for role STUDENT |
| A5 | Logout | signOut() | ⬜ | clear Keychain, close realtime channels, pop to Login |

**ViewModels:** `LoginViewModel`, `RegisterViewModel`, `SplashViewModel` → `@Observable` iOS equivalents.

---

## Student (`feature/home|search|outlets|food|cart|checkout|orders|pickup|favorites|notifications|profile`)

### Home & Discovery
| # | Android | iOS | Status | Notes |
|---|---|---|---|---|
| S1 | Home feed (outlets, categories, promos, search entry) | `HomeView` | ⬜ | `HomeViewModel` |
| S2 | Search (live) + Results | `SearchView`, `SearchResultsView` | ⬜ | debounced `search_food` RPC |
| S3 | Outlet list | `OutletListView` | ⬜ | outlets with location/hours/queue |
| S4 | Outlet detail (catalogue) | `OutletDetailView` | ⬜ | `get_catalogue_for_outlet` |
| S5 | Food detail (variants, customizations) | `FoodDetailView` | ⬜ | nested `food_variants(food_variant_options)` |

### Cart & Checkout & Payments
| # | Android | iOS | Status | Notes |
|---|---|---|---|---|
| S6 | Cart (single-outlet, 5% tax, customizations) | `CartView` | ⬜ | cart server rows + local cart items |
| S7 | Checkout (pickup slots, instructions) | `CheckoutView` | ⬜ | slots AVAILABLE/LIMITED/FULL |
| S8 | `place_order` RPC | OrderService | ⬜ | server-authoritative pricing; cart cleared only on PAY_AT_COUNTER |
| S9 | Razorpay create-order + verify | `Razorpay` integration | ⬜ | edge fns `create-razorpay-order`, `verify-razorpay-payment` |
| S10 | Order confirmation | `OrderConfirmationView` | ⬜ | |

### Orders & Pickup
| # | Android | iOS | Status | Notes |
|---|---|---|---|---|
| S11 | Live order tracking (realtime) | `LiveOrderTrackingView` | ⬜ | realtime channel `public:orders`, status stepper |
| S12 | Order history | `OrderHistoryView` | ⬜ | list all orders w/ status colors |
| S13 | Order detail | `OrderDetailView` | ⬜ | items, customizations, payment, slot |
| S14 | Pickup QR code | `PickupQRCodeView` | ⬜ | render `pickup_tokens.token_value` as QR |

### Secondary
| # | Android | iOS | Status | Notes |
|---|---|---|---|---|
| S15 | Favorites | `FavoritesView` | ⬜ | `favorites` table toggle |
| S16 | Notifications | `NotificationsView` | ⬜ | realtime `public:notifications`; deep-link to order |
| S17 | Profile | `ProfileView` | ⬜ | user info, navigation hub, logout |
| S18 | Settings | `SettingsView` | ⬜ | theme, notifications prefs |
| S19 | Help & Support | `HelpView` | ⬜ | FAQ/contact |

---

## Vendor (`feature/vendor/`)

| # | Android | iOS | Status | Notes |
|---|---|---|---|---|
| V1 | Vendor Dashboard | `VendorDashboardView` | ⬜ | today's orders, stats, scan entry |
| V2 | Vendor Orders (list) | `VendorOrdersView` | ⬜ | realtime order feed for outlet |
| V3 | Vendor Order Detail | `VendorOrderDetailView` | ⬜ | accept/reject/preparing/ready RPCs |
| V4 | Vendor Menu (food mgmt) | `VendorMenuView` | ⬜ | availability, price, inventory |
| V5 | Food Edit | `VendorFoodEditView` | ⬜ | route exists; Android screen stub-level |
| V6 | Vendor Analytics | `VendorAnalyticsView` | ⬜ | |
| V7 | QR Scanner | `QRScannerView` | ⬜ | AVFoundation; `verify_pickup_token` READY→PICKED_UP |

---

## Admin (`feature/admin/`)

| # | Android | iOS | Status | Notes |
|---|---|---|---|---|
| D1 | Admin Dashboard | `AdminDashboardView` | ⬜ | `get_admin_stats` RPC — ⚠️ backend bug: uses `users` table (real: `profiles`) |
| D2 | Admin sub-screens (users/vendors/outlets/orders/analytics/settings) | route stubs | ⬜ | Android only routes them; minimal parity |

---

## Cross-cutting

| Concern | Android | iOS | Status |
|---|---|---|---|
| Design system | Compose theme | SwiftUI DesignSystem | ⬜ |
| Realtime | Supabase realtime (orders, notifications) | `Realtime` AsyncStream | ⬜ |
| Local cache | Room (cart/favs) + DataStore | light cache (favorites/cart persistence) | ⬜ |
| Payments | Razorpay Android SDK | Razorpay iOS SDK | 🟡 needs test keys |
| Push | Firebase (dormant — no FCM code) | none (realtime + in-app list) | 🟡 confirm |
| QR generation | ZXing/ML Kit | CoreImage `CIFilter` QR | ⬜ |
| QR scanning | CameraX/ML Kit | AVFoundation metadata output | ⬜ |
| Image loading | Coil | `AsyncImage` + disk cache | ⬜ |
