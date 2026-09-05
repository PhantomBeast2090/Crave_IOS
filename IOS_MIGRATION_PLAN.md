# IOS_MIGRATION_PLAN.md — Crave (GaG) Android → iOS

**Goal:** Reimplement the Android "Crave (GaG)" app as a native iOS/SwiftUI app that is a **real, functional product with full backend parity** — not a mockup or partial port.

**Source of truth:** the Android repo (Kotlin/Jetpack Compose, MVVM + Clean Architecture, Supabase). We translate *behavior and business rules*, writing idiomatic Swift/SwiftUI, not line-by-line Kotlin.

**Backend:** the existing Crave Supabase backend (schema `001`–`011`, Edge Functions, RLS, Realtime). We do **not** create a new Supabase project/schema or fake local data. If a backend change ever seems required, STOP and explain before touching it.

---

## 1. Architecture Target

```
┌──────────────────────────────────────────────────────────┐
│  SwiftUI App                                              │
│  @main CraveApp                                          │
│    ├── AppState (Observable) — auth session, user role    │
│    ├── RootView — switch on session/role → sub-graph      │
│    │    ├── AuthFlow (Onboarding, Login, Register)        │
│    │    ├── StudentFlow (TabView: Home/Search/Orders/…)   │
│    │    ├── VendorFlow (TabView: Dashboard/Orders/Menu)   │
│    │    └── AdminFlow (Dashboard)                         │
│    └── NavigationStack routing (mirrors Screen.kt routes) │
├──────────────────────────────────────────────────────────┤
│  Feature layer (per-feature: View + ViewModel @Observable)│
├──────────────────────────────────────────────────────────┤
│  Domain layer (models, repository protocols, use cases)   │
├──────────────────────────────────────────────────────────┤
│  Data layer (Supabase repo impls, mappers, local cache)   │
├──────────────────────────────────────────────────────────┤
│  Core (DesignSystem, Networking, Security/Keychain,       │
│         QR, Payments/Razorpay, Realtime)                  │
└──────────────────────────────────────────────────────────┘
```

**Stack choices**
| Concern | Android | iOS |
|---|---|---|
| UI | Jetpack Compose | SwiftUI |
| Architecture | MVVM + Clean | MVVM + Observable (`@Observable` / `@ObservableObject`) |
| Concurrency | Coroutines + Flow | Swift Concurrency (`async/await`, `AsyncStream`) |
| DI | Hilt | Manual DI (composition root / `Environment`) |
| Network | Supabase Kotlin SDK (Ktor) | Supabase Swift SDK (URLSession) |
| Local cache | Room + DataStore | SwiftData or lightweight cache in-memory/`@AppStorage` (only where Android had it) |
| Security | EncryptedSharedPreferences | Keychain (access/refresh tokens) |
| QR | ML Kit / CameraX / ZXing | AVFoundation `AVCaptureMetadataOutput` (QR) |
| Payments | Razorpay Android SDK | Razorpay iOS SDK (or Web-based checkout) |
| Push | Firebase (dormant) | none required initially (realtime + notifications table) |

---

## 2. Stages (incremental, compile constantly)

Each stage must leave the project **compiling** (`xcodebuild` or Xcode) before moving on.

### Stage 1 — Scaffolding & Config
- [x] Xcode project verified (`PBXFileSystemSynchronizedRootGroup`, files auto-join target)
- [ ] `Config` module: `AppConfig` with Supabase URL + anon key (via `.xcconfig`, **not committed**)
- [ ] Secret handling: add `Config.local.xcconfig` to `.gitignore`; commit a `Config.example.xcconfig` placeholder
- [ ] `Info.plist` keys: ATS exceptions (Supabase https fine), NSCameraUsageDescription (QR scan)
- [ ] Package dependency: `supabase-swift` (+ Auth/PostgREST/Realtime/Storage/Functions submodules)
- [ ] Session restore: GoTrue `restoreSession()` from Keychain on launch

### Stage 2 — Design System
- [ ] `DesignSystem/` — `AppTheme.swift`, `AppColors.swift`, `Typography.swift`, `Shapes.swift`
- [ ] Port the full color palette (GagOrange `0xFFE8431A`, dark surfaces `0xFF0F0F0F`/`0xFF1A1A1A`, status/slot/category colors)
- [ ] Shared components: `GagButton`, `GagTextField`, `GagTopBar`, `GagBottomNav`, `FoodItemCard`, `GagImage` (AsyncImage + caching), `GagStateViews` (Loading/Error/Empty)
- [ ] Dark + light mode (Android defines both palettes; respect system + manual toggle)

### Stage 3 — Core Infrastructure
- [ ] Networking: Supabase client singleton; typed error mapping (`SupabaseError`)
- [ ] `TokenManager`: persist GoTrue session in Keychain, expose refresh, handle expiry
- [ ] Auth repository protocol + Supabase implementation (login, register, signOut, session events)
- [ ] `SessionManager`/`AppState`: auth state stream → role resolution (`profiles.role`)
- [ ] Role-based routing skeleton (Splash → Onboarding → Login → Home / Vendor / Admin)
- [ ] Logger (non-secret) + common utilities (`formatPrice`, date formatting, haptics)

### Stage 4 — Domain Models + Repository Protocols
- [ ] `User`, `UserRole` (STUDENT/VENDOR/ADMIN)
- [ ] `Outlet` (+ location, hours, queue level), `FoodItem`, `FoodVariant`, `CustomizationOption`
- [ ] `Cart`, `CartItem`, `SelectedCustomization` (single-outlet cart, 5% tax)
- [ ] `Order`, `OrderItem`, `OrderStatus` (+ `isTerminal/isActive/displayName`), `PaymentStatus`, `PaymentMethod`
- [ ] `PickupSlot`, `SlotStatus`, `Review`, `Favorite`, `Notification`, `NotificationType`
- [ ] Repository protocols: Auth, Outlet, Food, Cart, Order, Payment, Notification, Admin, Profile

### Stage 5 — Data Layer
- [ ] DTOs + snake_case mapping (mirror `OrderDto.kt` / `FoodDto.kt` incl. nested `order_items`, `food_variants`)
- [ ] Mappers DTO ↔ domain
- [ ] Repository implementations backed by Supabase PostgREST queries + RPCs
- [ ] Local cache where Android had Room (favorites, cart persistence) — keep minimal, RLS still source of truth

### Stage 6 — Auth Flow
- [ ] Splash (restore session, decide start destination)
- [ ] Onboarding
- [ ] Login (`?role=`) — creates `profiles` row on first verified login (mirror `SupabaseAuthRepository`)
- [ ] Register (student; profile self-INSERT allowed by RLS)
- [ ] Logout → clear keychain + realtime channels

### Stage 7 — Student: Home, Search, Catalogue
- [ ] Home (feed: outlets, categories, promotions; search entry)
- [ ] Search + SearchResults (debounced `search_food` RPC)
- [ ] OutletList / OutletDetail (`get_catalogue_for_outlet`)
- [ ] FoodDetail (variants + customizations, add to cart)

### Stage 8 — Student: Cart, Checkout, Payments
- [ ] Cart (single-outlet, 5% tax, customizations)
- [ ] Checkout: pickup slots (AVAILABLE/LIMITED/FULL), special instructions
- [ ] `place_order` RPC (server-authoritative pricing; only clears cart for PAY_AT_COUNTER)
- [ ] Razorpay: `create-razorpay-order` edge fn → Razorpay iOS SDK → `verify-razorpay-payment` → `mark_payment_verified` (cart cleared server-side on PAID/CAPTURED)
- [ ] PAY_AT_COUNTER path (note: Android UI only exposes ONLINE; confirm with user)

### Stage 9 — Student: Orders & Real-time
- [ ] Order Confirmation → Order Detail
- [ ] Live Order Tracking (realtime channel `public:orders`, filter `id=eq.{orderId}`, status stepper)
- [ ] Order History (all statuses)
- [ ] Pickup QR code (renders `pickup_tokens.token_value`)

### Stage 10 — Student: Secondary Screens
- [ ] Favorites (toggle via `favorites` table)
- [ ] Notifications (realtime `public:notifications` + in-app list; deep-link to order)
- [ ] Profile, Settings, Help

### Stage 11 — Vendor Flow
- [ ] Vendor Dashboard (today's orders, stats, scan entry)
- [ ] Vendor Orders (list, realtime) + Vendor Order Detail (accept/reject/start-preparing/mark-ready RPCs)
- [ ] Vendor Menu (manage food items/inventory) + Food Edit
- [ ] QR Scanner (AVFoundation; `verify_pickup_token` → READY→PICKED_UP)
- [ ] Vendor Analytics

### Stage 12 — Admin Flow
- [ ] Admin Dashboard (`get_admin_stats` RPC — **note pre-existing backend bug:** references `users` table which doesn't exist; real table is `profiles`. Surface to user before relying on it)
- [ ] Admin sub-screens (users/vendors/outlets/orders/analytics/settings) as stubs where the Android app only routes them

### Stage 13 — Caching, Offline, Quality
- [ ] Cart + favorites persistence across launches
- [ ] Image caching
- [ ] Pull-to-refresh, empty/error/loading states everywhere
- [ ] Accessibility labels, dynamic type where reasonable

### Stage 14 — Parity Testing
- [ ] Drive both apps against the same backend; compare behavior per feature
- [ ] Auth flows, cart math (5% tax), order state machine transitions, RLS failures
- [ ] Realtime live-tracking parity, pickup QR flow, vendor RPCs, admin stats

### Stage 15 — Hardening & Polish
- [ ] Keychain token rotation, network retry/backoff, timeouts
- [ ] Error copy (never leak tokens/server internals)
- [ ] App icon, launch screen, onboarding polish
- [ ] Final audit against the security constraints (no service-role key, no secrets committed)

---

## 3. Security constraints (from the original spec — non-negotiable)
- Never request or embed a **Supabase service-role key** in the iOS client.
- Use only the client-safe **public anon key**.
- Never hardcode secrets, never commit credentials, never log auth tokens.
- Never bypass RLS; all server mutations via existing RPCs under RLS.
- Client-side authorization is UX only — server RLS is the security layer.

## 4. Open items (Category-C — to confirm with user before/at relevant stages)
1. Supabase **anon key** (needed Stage 1 to actually run).
2. **Bundle identifier** confirmation (`rakshan.Crave-IOS`), and final **app name** (Crave vs "Crave (GaG)" vs "GaG – SRM Food").
3. **Razorpay on iOS**: test mode keys + whether to use the native Razorpay iOS SDK or a web-based fallback.
4. **Payment methods** to expose: Android UI only shows ONLINE — confirm whether PAY_AT_COUNTER should appear.
5. Push notifications: Firebase is dormant on Android; confirm **realtime + in-app list only** is acceptable for v1.
6. `get_admin_stats()` RPC references a non-existent `users` table — confirm whether we should fix it (backend change → needs explicit approval) or leave admin stats read-only/degraded.
