# BACKEND_MAP.md — Supabase backend contract used by the iOS app

The iOS app talks to the **existing** Crave Supabase backend. This doc is the contract: tables, enums, RLS posture, RPCs, Edge Functions, Realtime. **No schema changes are planned.** If one is ever needed, it must be approved explicitly (see Open Items).

- Supabase project ref: `btdmhveaqssuuhyoyanz` — URL `https://btdmhveaqssuuhyoyanz.supabase.co`
- Auth: GoTrue (email/password). Sessions restored from Keychain.
- Anon key: kept out of git; provided via uncommitted `.xcconfig` (see IOS_MIGRATION_PLAN §Stage 1).

---

## 1. Tables (from `001_initial_schema.sql`)

| Table | Purpose | iOS role access (RLS) |
|---|---|---|
| `profiles` | users: id, name, email, phone, role, registration_number, is_active | self read/write; role-driven |
| `outlets` | vendor outlets: name, description, location, hours, is_open, is_active, queue level | public read; vendor/ADMIN write |
| `categories` | food categories: name, emoji, sort_order | public read |
| `food_items` | menu items: outlet_id, name, desc, price, image_url, is_veg, is_available, prep_time_minutes | public read; vendor/ADMIN write |
| `food_variants` | option groups (Size, Add-ons…) | read w/ food |
| `food_variant_options` | selectable options with `extra_price` | read w/ food |
| `inventory` | per-food quantity_available | read; decremented by RPCs |
| `carts` / `cart_items` / `cart_item_customizations` | user's cart (single-outlet) | owner-only |
| `pickup_slots` | per-outlet slots: slot_date, start/end, capacity, booked_count, status | public read; mutated by RPCs |
| `orders` | order header: status, payment, totals, slot | owner / vendor / ADMIN |
| `order_items` / `order_item_customizations` | line items + snapshot customizations | via order |
| `payments` | payment record per order | via order |
| `pickup_tokens` | 64-hex token + expiry (2h) | via order; verified by RPC |
| `favorites` | user↔food | owner |
| `reviews` | outlet/food reviews | owner write, public read |
| `notifications` | in-app notifications | owner |
| `coupons` | discount codes (unused by Android core flow) | — |
| `audit_logs` | server audit trail | server-side |

## 2. Enums

- `user_role` — `STUDENT`, `VENDOR`, `ADMIN`
- `order_status` — `CREATED, PLACED, ACCEPTED, PREPARING, READY, PICKED_UP, REJECTED, CANCELLED, EXPIRED, REFUNDED`
- `payment_status` — `PENDING, PAID, FAILED, REFUNDED, CREATED, AUTHORIZED, CAPTURED`
- `payment_method` — `PAY_AT_COUNTER`, `ONLINE`
- `pickup_slot_status` — `AVAILABLE, LIMITED, FULL`
- `notification_type` — (per schema)

## 3. RLS posture

- `get_user_role()` / `is_admin()` / `is_vendor()` / `is_student()` helper functions gate policies.
- Profile self-INSERT: `auth.uid() = id AND role = 'STUDENT'` (register is student-only).
- Vendors see their outlet's orders **only** when `payment_method = 'PAY_AT_COUNTER'` OR `payment_status IN ('PAID','REFUNDED')` OR status in REJECTED/CANCELLED (migration 010 hardens this for online payments).
- All server mutations go through SECURITY DEFINER RPCs — the client never bypasses RLS.

## 4. RPCs the iOS app will call

| RPC | Signature | Used by |
|---|---|---|
| `place_order` | `(p_cart_id uuid, p_pickup_slot_id uuid, p_payment_method text default 'PAY_AT_COUNTER') → uuid` | Student checkout. Atomic: validates outlet/slot/inventory, computes subtotal + 5% tax, inserts order + items + customizations (prices from DB), decrements inventory, increments slot booked_count, creates pickup_token (gen_random_bytes(32) hex, 2h expiry), updates/creates payment row, clears cart **only** on PAY_AT_COUNTER, audit log. |
| `verify_pickup_token` | `(p_token text) → void` | Vendor QR scan. READY → PICKED_UP. |
| `vendor_accept_order` / `vendor_reject_order` / `vendor_start_preparing` / `vendor_mark_ready` | `(p_order_id uuid) → void` | Vendor order state machine. Trigger enforces legal transitions + role. |
| `mark_payment_verified` | `(p_order_id, p_razorpay_payment_id, p_razorpay_signature, p_status default 'PAID') → void` | Post-Razorpay. Clears cart when PAID/CAPTURED (migration 011). |
| `search_food` | `(p_query text, p_limit int, p_offset int)` | Search. Returns food w/ flat `outlet_name`, `category_name`. |
| `get_catalogue_for_outlet` | `(p_outlet_id uuid)` | Outlet detail. |
| `get_admin_stats` | `() → jsonb` | Admin dashboard. ⚠️ **Backend bug:** references non-existent `users` table (real: `profiles`) → RPC errors at runtime. |

**Trigger/state machine:** `orders` transitions enforced server-side (PLACED→ACCEPTED→PREPARING→READY→PICKED_UP; →REJECTED/CANCELLED; restore inventory + slot on CANCEL/REJECT).

## 5. Edge Functions (Deno/TypeScript)

| Function | Purpose | Env vars |
|---|---|---|
| `create-razorpay-order` | creates Razorpay order for a `place_order`'d order | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` |
| `verify-razorpay-payment` | HMAC-SHA256 signature verification; calls `mark_payment_verified` | `RAZORPAY_KEY_SECRET` |
| `razorpay-webhook` | server-side webhook handler | `RAZORPAY_WEBHOOK_SECRET` |

## 6. Realtime

- Channel `postgres_changes` on `public:orders` → live order status (LiveOrderTracking, VendorOrders/Dashboard).
- Channel on `public:notifications` → in-app notification feed + badge.

## 7. iOS repository → backend mapping

| iOS repo | Backend |
|---|---|
| `SupabaseAuthRepository` | GoTrue signUp/signIn/restoreSession; `profiles` upsert on first login |
| `SupabaseOutletRepository` | `outlets` SELECT (+ location/hours) |
| `SupabaseFoodRepository` | `food_items` + nested variants/options; `search_food`; `get_catalogue_for_outlet` |
| `SupabaseCartRepository` | `carts`/`cart_items`/`cart_item_customizations` CRUD |
| `SupabaseOrderRepository` | `orders`(+items/customizations/slot); `place_order`; vendor RPCs; realtime observer |
| `SupabasePaymentRepository` | `functions.invoke(create-razorpay-order/verify-razorpay-payment)`; `mark_payment_verified` |
| `SupabaseNotificationRepository` | `notifications` + realtime |
| `AdminRepositoryImpl` | `get_admin_stats`, `admin_toggle_outlet_status` |

## 8. Open backend items (need user decision)

- **B1 — `get_admin_stats` bug:** RPC references `users` (doesn't exist); real table is `profiles`. Fixing = backend change → requires approval. Options: (a) approve a minimal migration, (b) keep admin stats degraded and document, (c) compute admin stats client-side from permitted reads.
- **B2 — Razorpay env keys:** iOS needs test `RAZORPAY_KEY_ID` (public) for the SDK. Keys live server-side; client only ever uses the public key id + order id.
