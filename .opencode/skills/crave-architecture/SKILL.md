---
name: crave-architecture
description: Protect and evolve Crave's MVVM + Clean SwiftUI architecture. Use when refactoring, adding features, changing navigation, DI, repositories, ViewModels, domain models, or app state, and when reviewing separation of concerns or testability.
---

# Crave Architecture

Crave is MVVM + Clean: SwiftUI Views → `@Observable`/`@MainActor` ViewModels →
repository protocols (`Core/App/`) → Supabase implementations → backend.
Domain models live in `Domain/Models/`. Preserve this layering.

## Enforce

- Separation of concerns: Views compose/present/interact; business logic lives
  in ViewModels and application services, never in Views.
- Repository abstraction: features depend on protocols (`OrderRepository`,
  `CartRepository`, `PaymentRepository`, `NotificationRepository`,
  `AdminRepository`, `AppRepository`); Supabase details stay in `Supabase*`
  implementations and DTOs/mappers.
- Manual DI via `AppState` composition root (`AppState+Repository.swift`,
  `CraveApp.swift`). No singletons for domain state except true infrastructure
  bridges (e.g. `RazorpayService.shared`, `SupabaseClientProvider.shared`).
- Explicit type-safe navigation per role (`RootView`, `StudentFlow`,
  `VendorFlow`, `AdminFlow`; see `NAVIGATION_MAP.md`). No hidden global routing.
- Single sources of truth; minimal global state. `AsyncStream` observers
  (`observeCart`, `observeOrders`, `observeOrderStatus`,
  `observeNotifications`, `observeOutlets`, `observeFavorites`) over duplicated
  cached copies.
- No payment verification logic in Views — the `CheckoutViewModel` flow plus
  server-authoritative verification owns it (see `crave-payments`).
- No security-sensitive backend logic in Views (see `crave-security`).
- No duplicated domain state: SwiftData entities are caches; backend is truth.

## Before any architectural refactor, document

Current architecture (files) · actual problem with evidence · proposed
architecture · affected files · migration strategy · risks · tests covering the
change · rollback considerations.

## Rules

- Never rewrite for stylistic preference. Smallest coherent incremental change.
- New feature? Follow the existing per-feature pattern: `View` +
  `ViewModel` (+ route entry in the role flow), repository protocol first if a
  new data need appears.
- Keep everything compiling at each step; run affected tests.
- Route payments to `crave-payments`, Supabase/realtime to `crave-supabase`,
  UI to `crave-ui`, testing to `crave-testing`.
