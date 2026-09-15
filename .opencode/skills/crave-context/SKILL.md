---
name: crave-context
description: Source-of-truth orientation for the Crave iOS campus food-ordering app. Use when starting any Crave task, before modifying architecture, backend contracts, auth, Supabase, realtime, SwiftData, Razorpay, cart, checkout, orders, QR pickup, notifications, or vendor/admin flows.
---

# Crave Context

Crave is an existing, production-oriented native iOS campus food-ordering app
(SwiftUI, Swift 5.0, iOS 26.5, `rakshan.Crave-IOS`). Do not rebuild it. The
repository is the source of truth — not prior descriptions of it.

## Source-of-truth hierarchy

1. Actual repository implementation (`Crave_IOS/`)
2. Repository protocols and domain models (`Core/App/*Repository*.swift`, `Domain/Models/`)
3. Backend implementation and configuration (`supabase/migrations/`, `BACKEND_MAP.md`)
4. Tests (`Crave_IOSTests/`, `Crave_IOUITests/`)
5. `FEATURE_MAP.md`, `NAVIGATION_MAP.md`, `IOS_MIGRATION_PLAN.md`, `IOS_PARITY_CHECKLIST.md`
6. Apple documentation, then external technical references

## Verified repository facts

- Layout: `Crave_IOS/Core/{App,DesignSystem,Networking,Config,Common,Payment}/`,
  `Crave_IOS/Domain/Models/`, `Crave_IOS/Feature/{Auth,Student,Vendor,Admin}/`.
- Architecture: MVVM + Clean. `@Observable`/`@MainActor` ViewModels per feature,
  repository protocols in `Core/App/`, Supabase implementations
  (`Supabase*Repository`), domain models in `Domain/Models/`.
- DI: manual. `AppState` (`Core/App/AppState.swift`) is the composition root,
  injected via `.environment(appState)` in `CraveApp.swift`; repositories via
  `setRepository(_:)` (`DefaultAppRepository.makeWithSwiftData` in production,
  `makeInMemory` fallback/tests).
- DesignSystem: `GagColors` (brand orange `0xE8431A`, adaptive surfaces,
  order-status/slot/category tokens), `AppTheme.brandGradient`,
  `gagCard()` modifier, `GagButton`, `GagTextField`, `GagTopBar`,
  `GagBottomNav`, `FoodItemCard`, `OrderStatusBadge`, `OrderTimelineView`,
  `QRCodeView`, `GagToast`, `GagStateViews`, `Typography`, `AppShapes`.
- Backend: Supabase project `btdmhveaqssuuhyoyanz`; migrations
  `supabase/migrations/001–012`. Key RPCs: `place_order`,
  `verify_pickup_token`, `vendor_accept_order` / `vendor_reject_order` /
  `vendor_start_preparing` / `vendor_mark_ready`, `mark_payment_verified`,
  `search_food`, `get_catalogue_for_outlet`, `get_admin_stats`.
  5% tax is server-authoritative (`place_order` computes it).
- Checkout state machine: `Feature/Student/Home/CheckoutViewModel.swift`
  (`idle → placing → awaitingPayment → verifying → success`, plus
  `paymentCancelled` / `error`); stale-order cancellation on retry.
- Payments: `Core/Payment/RazorpayService.swift` (native sheet bridge) +
  `SupabasePaymentRepository` (Edge Functions `create-razorpay-order`,
  `verify-razorpay-payment`). Secrets live in gitignored
  `Core/Config/Secrets.swift` (see `Secrets.example.swift`) — never in source.
- Realtime: `realtimeV2` per-order (`order-<id>`) and per-user notification
  channels, exposed as `AsyncStream` observers; `removeAllChannels()` on sign-out.
- Local cache: SwiftData entities (`CachedOutlet`, `CachedFoodItem`,
  `CartItemEntity`, `OrderEntity`, `OrderItemEntity`) are offline caches only;
  backend/RLS is authoritative.
- Tests: `Crave_IOSTests` (`CartMathTests`, `DecodingTests`),
  `Crave_IOUITests` (`AcceptanceTests`).

## Rules

- Inspect relevant files before modifying anything. Preserve working
  architecture, backend contracts, repository abstractions, auth, Supabase,
  realtime, SwiftData caching, Razorpay integration, and vendor/admin flows.
- Reuse the DesignSystem; adapt it rather than bypassing it. Note the actual
  brand orange is `0xE8431A`, not any value from a brief — follow the repo.
- Preserve role-based flows (student / vendor / admin) and role routing in
  `AppState`/`RootView`/flow files.
- Distinguish verified facts (cited to files) from assumptions in every report.
  Never claim verification that did not happen. If a doc (e.g. `BACKEND_MAP.md`
  on `get_admin_stats`) disagrees with a migration (e.g. `012_`), trust the
  migration and flag the discrepancy.
- For substantial work, hand off to `crave-muse-protocol` for orchestration
  and route to specialist skills: `crave-architecture`, `crave-ui`,
  `crave-motion`, `crave-security`, `crave-supabase`, `crave-payments`,
  `crave-performance`, `crave-testing`, `crave-qa`, `crave-research`,
  `crave-release`.
