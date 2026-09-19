# Crave 2.0 Product Transformation — Implementation Record

## Status: Wave 1 + core client architecture implemented, backend migrations authored-but-unapplied

## 1. Category flow (done, tested)
- Chips navigate to dedicated `CategoryResultsView` (never Search).
- `FoodRepository.getOutletsForCategory` groups `search_food` dishes by outlet;
  prefers exact-ID ordering from new `get_outlets_for_category` RPC when live.
- Veg/Non-Veg + Under-₹100 filters on real data. Loading/empty/error/retry states.

## 2. Dietary correctness (data fix authored, UI verified)
- Live finding: `food_items.is_veg` NULL on all 1397 rows; client `?? true`
  rendered everything (incl. Chicken 65) as vegetarian.
- `015_diet_backfill.sql`: all 1397 IDs classified (527 non-veg / 870 veg,
  zero ambiguous) via audited keyword engine + ~25 hand-resolved names;
  explicit ID lists (no prod pattern matching); guard aborts on leftovers;
  then `SET NOT NULL`. Egg/dairy sweets → non-veg per FSSAI.
- Vendor menu gains a diet toggle (`updateFoodDiet`, RLS-covered) for corrections.
- UI already correct (circle vs triangle + labels); mapping tests added.

## 3. Multi-outlet cart (client done, backend gated)
- Domain: `Cart.sections`, `OutletCartSection`, per-item `slotId`; entity
  `slotId` (SwiftData lightweight migration).
- Single-outlet conflict flow deleted (11 files); dedup is per-outlet.
- Sync/push operate per outlet section; `resolveSync` policy unchanged.
- Blocked until migration 016 applied: legacy `UNIQUE(user_id)` + trigger
  reject second-outlet pushes (errors surface, local intact — no fake success).

## 4. Slots (stepped: per-outlet-section now, per-item model ready)
- `CartViewModel` loads today's slots per outlet; section pickers + per-item
  picker sheet persist `slotId` lines.
- `SlotMatcher` (pure, tested): exact-window intersection, gap-safe ids.
- Cart match mode: select → MATCH SLOT → common windows → apply.

## 5. Checkout (sequential per-section, honest without batch payment)
- Sections each place + pay + verify; verified sections kept; placement
  failures compensate (cancel unpaid this-run orders); payment failures never
  cancel; per-section cart clearing; main button re-verifies.
- Combined single-payment needs Edge Function changes (separate owner) +
  `mark_group_*`; spec drafted in migration comments.

## 6. Backend (authored, DRY-RUN VALIDATED, unapplied)
- `014`: `mark_payment_verified` preconditions (live forgery hole confirmed:
  PUBLIC/anon/authenticated EXECUTE), `pickup_tokens` owner SELECT (student
  QR was RLS-denied live), `get_outlets_for_category` RPC.
- `015`: diet backfill (above).
- `016`: `UNIQUE(user_id,outlet_id)`, `checkout_groups`, group columns,
  atomic idempotent `place_orders_batch` mirroring `place_order` checks.
- All three migrate cleanly inside rolled-back transactions against live
  schema (validated 2026-09-19, zero rows changed).

## 7. Design system + motion
- Crave tokens (`craveBackground/Ink/Primary/...`, contrast-checked roles;
  accent graphics-only documented). Orbit Regular bundled (OFL-1.1, `OFL.txt`
  shipped, Settings → Legal viewer). `CraveFonts` runtime registration.
- `CategoryArtwork`: 9 hand-built vector motifs (backend emojis are empty).
- Haptics: add-to-cart, favorite, quantity, checkout success. Reduce Motion
  gates: splash, FAQ, onboarding, toast transitions. Numeric badge/quantity
  transitions. VegIndicator a11y label verified in place.

## 8. Tests (59 green)
- New: category grouping/filters, dietary mapping, grouped sections, slot
  matching, multi-outlet sequential checkout, sync decisions.
- UI tests compile; live runs need credentials (deferred by user).

## 9. Known limitations / needs credentials
- Multi-section placement + batch payment need 014/016 applied + functions.
- Authed simulator walkthrough (cart→checkout→tracking→vendor QR) unverified.
- Order-ready celebration + Live Activity scoping deferred with push infra.
