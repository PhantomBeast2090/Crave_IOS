# IOS_PARITY_CHECKLIST.md — Android ⇄ iOS parity verification

Dual-column checklist to verify the iOS app matches the Android app **against the same live backend**. Each row = a testable behavior. Checkmarks are updated as implementation + verification progress.

Legend: ⬜ not started · 🔄 in progress · ✅ verified on iOS · ⚠️ parity gap / needs decision

---

## A. Auth & Session

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| A1 | Splash restores session from secure storage | ✅ | ⬜ | ⬜ |
| A2 | First-login creates `profiles` row | ✅ | ⬜ | ⬜ |
| A3 | Login `?role=` routes by role | ✅ | ⬜ | ⬜ |
| A4 | Register (student only) | ✅ | ⬜ | ⬜ |
| A5 | Logout clears session + realtime channels | ✅ | ⬜ | ⬜ |
| A6 | Session expiry → refresh token flow | ✅ | ⬜ | ⬜ |
| A7 | Onboarding gate | ✅ | ⬜ | ⬜ |

## B. Catalogue & Discovery

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| B1 | Home feed (outlets + categories) | ✅ | ⬜ | ⬜ |
| B2 | Debounced search via `search_food` | ✅ | ⬜ | ⬜ |
| B3 | Search shows flat outlet/category names | ✅ | ⬜ | ⬜ |
| B4 | Outlet detail catalogue `get_catalogue_for_outlet` | ✅ | ⬜ | ⬜ |
| B5 | Food detail variants + options w/ `extra_price` | ✅ | ⬜ | ⬜ |
| B6 | Availability + prep time surfaced | ✅ | ⬜ | ⬜ |

## C. Cart & Checkout

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| C1 | Single-outlet cart (adding from another outlet resets) | ✅ | ⬜ | ⬜ |
| C2 | Customizations attached per cart item | ✅ | ⬜ | ⬜ |
| C3 | Subtotal + 5% tax math matches server `place_order` | ✅ | ⬜ | ⬜ |
| C4 | Slot availability AVAILABLE/LIMITED/FULL shown | ✅ | ⬜ | ⬜ |
| C5 | `place_order` creates order + pickup token | ✅ | ⬜ | ⬜ |
| C6 | ONLINE payment only (Android UI) | ✅ | ⬜ | 🟡 confirm PAY_AT_COUNTER exposure |
| C7 | PAY_AT_COUNTER clears cart immediately | ✅ | ⬜ | ⬜ |
| C8 | ONLINE: cart survives until payment verified | ✅ | ⬜ | ⬜ |
| C9 | Cart cleared on PAID/CAPTURED via `mark_payment_verified` | ✅ | ⬜ | ⬜ |

## D. Order State Machine

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| D1 | PLACED → ACCEPTED → PREPARING → READY → PICKED_UP | ✅ | ⬜ | ⬜ |
| D2 | REJECTED / CANCELLED restore inventory + slot | ✅ | ⬜ | ⬜ |
| D3 | Illegal transitions rejected server-side | ✅ | ⬜ | ⬜ |
| D4 | Vendor can only act on PAID/CAPTURED online orders | ✅ | ⬜ | ⬜ |
| D5 | Realtime live tracking updates status in-place | ✅ | ⬜ | ⬜ |
| D6 | Status colors per state | ✅ | ⬜ | ⬜ |

## E. Pickup & QR

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| E1 | QR renders `pickup_tokens.token_value` | ✅ | ⬜ | ⬜ |
| E2 | Vendor scan verifies token (`verify_pickup_token`) | ✅ | ⬜ | ⬜ |
| E3 | READY → PICKED_UP on successful scan | ✅ | ⬜ | ⬜ |
| E4 | Token expiry (2h) handled | ✅ | ⬜ | ⬜ |

## F. Payments (Razorpay)

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| F1 | `create-razorpay-order` invoked with order id | ✅ | ⬜ | 🟡 needs iOS test keys |
| F2 | Razorpay sheet opens w/ correct amount + theme | ✅ | ⬜ | 🟡 |
| F3 | Success → `verify-razorpay-payment` (HMAC) | ✅ | ⬜ | 🟡 |
| F4 | Failure/cancel → order remains, cart intact | ✅ | ⬜ | ⬜ |
| F5 | No service-role/secret keys in client | ✅ | ⬜ | ✅ by design |

## G. Vendor

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| G1 | Dashboard shows today's/active orders + stats | ✅ | ⬜ | ⬜ |
| G2 | Accept / reject / start-preparing / mark-ready RPCs | ✅ | ⬜ | ⬜ |
| G3 | Menu management (availability, price, inventory) | ✅ | ⬜ | ⬜ |
| G4 | Analytics | ✅ | ⬜ | ⬜ |
| G5 | Realtime order feed | ✅ | ⬜ | ⬜ |

## H. Admin

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| H1 | Dashboard stats via `get_admin_stats` | ✅ | ⬜ | ⚠️ backend bug (`users` → `profiles`) |
| H2 | Toggle outlet open/closed `admin_toggle_outlet_status` | ✅ | ⬜ | ⬜ |
| H3 | Sub-screens routing parity | ✅ | ⬜ | ⬜ |

## I. Secondary

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| I1 | Favorites add/remove + persisted | ✅ | ⬜ | ⬜ |
| I2 | Notifications feed + realtime + deep-link to order | ✅ | ⬜ | ⬜ |
| I3 | Profile shows user info + nav hub | ✅ | ⬜ | ⬜ |
| I4 | Settings (theme/appearance) | ✅ | ⬜ | ⬜ |
| I5 | Help/Support | ✅ | ⬜ | ⬜ |

## J. Quality & Security

| # | Behavior | Android | iOS | Verified |
|---|---|---|---|---|
| J1 | Loading / empty / error states on every screen | ✅ | ⬜ | ⬜ |
| J2 | Image loading + caching | ✅ | ⬜ | ⬜ |
| J3 | No secrets committed / logged | ✅ | ✅ by design | ⬜ |
| J4 | RLS never bypassed client-side | ✅ | ⬜ | ⬜ |
| J5 | Refresh/retry + offline cache for cart & favorites | ✅ | ⬜ | ⬜ |
| J6 | Pull-to-refresh | ✅ | ⬜ | ⬜ |

---

## How to run parity verification
1. Run Android emulator and iOS simulator against the **same Supabase project**.
2. Use a fresh test student/vendor/admin account on each.
3. Step each feature on Android, record the observable, repeat on iOS, compare.
4. Mark the `Verified` column only when the iOS observable matches Android's.
