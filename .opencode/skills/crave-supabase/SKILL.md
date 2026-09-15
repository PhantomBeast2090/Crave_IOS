---
name: crave-supabase
description: Supabase backend, RLS, RPCs, Edge Functions, and Realtime expertise for Crave. Use when working with auth, repositories, PostgREST queries, RPCs, realtime subscriptions, caching, offline behavior, retries, or role/authorization boundaries.
---

# Crave Supabase

Preserve the existing backend contract (`BACKEND_MAP.md`,
`supabase/migrations/001–012`). No schema changes without explicit approval.
The anon key is client-safe but stays out of git (`Secrets.swift`).

## Know the contract

- Auth: GoTrue email/password; `SupabaseAuthService` (`Core/Networking/`);
  session restore on launch; `profiles` upsert on first login; student-only
  self-INSERT.
- Tables: `profiles`, `outlets`, `categories`, `food_items` (+
  `food_variants`/`food_variant_options`), `inventory`, `carts`/`cart_items`/
  `cart_item_customizations`, `pickup_slots`, `orders`/`order_items`/
  `order_item_customizations`, `payments`, `pickup_tokens`, `favorites`,
  `reviews`, `notifications`.
- RPCs: `place_order`, `verify_pickup_token`, `vendor_accept_order`,
  `vendor_reject_order`, `vendor_start_preparing`, `vendor_mark_ready`,
  `mark_payment_verified`, `search_food`, `get_catalogue_for_outlet`,
  `get_admin_stats` (migration `012_` fixed the `users`→`profiles` reference —
  verify runtime behavior rather than trusting older docs).
- Edge Functions (server-side, not vendored in this repo):
  `create-razorpay-order`, `verify-razorpay-payment`, `razorpay-webhook`.
- Realtime (`realtimeV2`): per-order channel for status
  (`SupabaseOrderRepository.observeOrderStatus`), per-user notifications
  channel (`SupabaseNotificationRepository`). All observers surface as
  `AsyncStream`.

## Realtime rules

Avoid duplicate channels (one per order/user scope) · cancel on view
disappear/sign-out (`removeAllChannels()` in `AppState.signOut`) · reconnect
safely via refetch-then-subscribe · debounce/coalesce before emitting to UI ·
never leak continuations (see `onTermination` cleanup in repository
`observe*` implementations).

## Data rules

- Server-authoritative pricing/tax/inventory/slots; client math is display only.
- SwiftData (`CachedOutlet`, `CachedFoodItem`, `CartItemEntity`,
  `OrderEntity`) is an offline cache with graceful fallback — RLS reads are truth.
- Map PostgREST/DTO errors to typed `AppError` (`Core/Common/AppError.swift`);
  retry with backoff, distinguish offline from server errors, never surface
  internals.
- Role/authorization boundaries mirror RLS helpers (`get_user_role`,
  `is_admin`, `is_vendor`); vendors see online orders only when paid.
- Route payments verification to `crave-payments`, secret handling to
  `crave-security`, networking depth to `ios-networking`.
