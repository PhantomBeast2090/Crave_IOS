-- 016_multi_outlet_checkout.sql
--
-- STATUS: AUTHORED — NOT APPLIED. Requires explicit approval + staging
-- verification before running against any project.
--
-- GOAL: multi-outlet carts with per-outlet-section slots and atomic batch
-- placement. Stepped scope (per user decision): ONE slot per outlet section
-- in v1; per-item slot columns are intentionally NOT added (client persists
-- line slotIds locally; placement consumes the section slot).
--
-- WHAT CHANGES:
--   1. carts: UNIQUE(user_id) -> UNIQUE(user_id, outlet_id) (one row per
--      outlet per user). Existing rows already satisfy this (at most one row
--      per user), so the swap is non-destructive.
--   2. checkout_groups: new table binding one checkout's orders for group
--      display, combined payment (future), and idempotent replay.
--   3. orders.checkout_group_id + payments.checkout_group_id (nullable,
--      additive; existing rows untouched).
--   4. place_orders_batch RPC: atomic multi-order placement with per-row
--      validation mirrored from place_order + idempotency via client key.
--
-- WHAT DOES NOT CHANGE:
--   - enforce_cart_single_outlet trigger: still correct (each cart row stays
--     single-outlet). Kept as-is.
--   - place_order, mark_payment_verified, vendor RPCs, RLS policies: untouched.
--   - Slot capacity counting (booked_count +1 per order): unchanged.
--   - Combined single Razorpay payment: NOT here — needs Edge Function
--     changes (separate owner) + mark_group_payment_verified. Until then the
--     client pays per outlet order sequentially (verified, retryable).
--
-- ROLLBACK: drop function + columns + table + restore UNIQUE(user_id):
--   DROP FUNCTION place_orders_batch(...); ALTER TABLE orders DROP COLUMN
--   checkout_group_id; ALTER TABLE payments DROP COLUMN checkout_group_id;
--   DROP TABLE checkout_groups; ALTER TABLE carts DROP CONSTRAINT
--   carts_user_outlet_key; ALTER TABLE carts ADD CONSTRAINT
--   carts_user_id_key UNIQUE (user_id);
-- BACKUP the database before applying.

-- ---------------------------------------------------------------------
-- 1. Multi-cart rows
-- ---------------------------------------------------------------------
ALTER TABLE carts DROP CONSTRAINT IF EXISTS carts_user_id_key;
ALTER TABLE carts ADD CONSTRAINT carts_user_outlet_key UNIQUE (user_id, outlet_id);

-- ---------------------------------------------------------------------
-- 2. Checkout groups
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checkout_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    client_session_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PLACED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, client_session_id)
);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS checkout_group_id UUID NULL REFERENCES checkout_groups(id) ON DELETE SET NULL;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS checkout_group_id UUID NULL REFERENCES checkout_groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_orders_checkout_group ON orders(checkout_group_id);
CREATE INDEX IF NOT EXISTS idx_payments_checkout_group ON payments(checkout_group_id);

ALTER TABLE checkout_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS checkout_groups_owner_select ON checkout_groups;
CREATE POLICY checkout_groups_owner_select ON checkout_groups
FOR SELECT USING (auth.uid() = user_id);
-- Groups are created server-side by place_orders_batch only (no direct
-- INSERT/UPDATE/DELETE policies for clients).

-- ---------------------------------------------------------------------
-- 3. Atomic batch placement
--
-- p_items: JSONB array of {"cart_id": uuid, "pickup_slot_id": uuid}.
-- Returns one row per created order (order_id, outlet_id).
-- Idempotent: repeating a call with the same p_client_session_id returns
-- the previously created orders without touching inventory/slots.
-- Validation mirrors place_order per row: cart ownership + non-empty,
-- single-outlet integrity, availability, inventory FOR UPDATE, slot
-- ownership/capacity/past FOR UPDATE. Any row failing aborts the whole
-- batch (single transaction) — no partial orders, no orphan holds.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION place_orders_batch(
    p_items JSONB,
    p_payment_method TEXT DEFAULT 'ONLINE',
    p_client_session_id TEXT DEFAULT NULL
) RETURNS TABLE (order_id UUID, outlet_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_group_id UUID;
    v_entry JSONB;
    v_cart_id UUID;
    v_slot_id UUID;
    v_cart RECORD;
    v_outlet RECORD;
    v_slot RECORD;
    v_line RECORD;
    v_customization RECORD;
    v_subtotal NUMERIC;
    v_tax NUMERIC;
    v_total NUMERIC;
    v_prep INTEGER;
    v_item_subtotal NUMERIC;
    v_order_id UUID;
    v_order_item_id UUID;
    v_inv_qty INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;
    IF p_payment_method NOT IN ('ONLINE', 'PAY_AT_COUNTER') THEN
        RAISE EXCEPTION 'Invalid payment method.';
    END IF;
    IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Empty checkout.';
    END IF;

    -- Idempotent replay: same session key returns existing orders.
    IF p_client_session_id IS NOT NULL THEN
        SELECT id INTO v_group_id FROM checkout_groups
        WHERE user_id = v_user_id AND client_session_id = p_client_session_id;
        IF FOUND THEN
            RETURN QUERY SELECT o.id, o.outlet_id FROM orders o
            WHERE o.checkout_group_id = v_group_id ORDER BY o.created_at;
            RETURN;
        END IF;
    END IF;

    INSERT INTO checkout_groups (user_id, client_session_id, status)
    VALUES (v_user_id, COALESCE(p_client_session_id, 'single-' || gen_random_uuid()::text), 'PLACED')
    RETURNING id INTO v_group_id;

    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_cart_id := (v_entry ->> 'cart_id')::uuid;
        v_slot_id := (v_entry ->> 'pickup_slot_id')::uuid;

        -- Cart ownership (locked for the transaction).
        SELECT * INTO v_cart FROM carts
        WHERE id = v_cart_id AND user_id = v_user_id
        FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cart not found or not owned by user.';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM cart_items WHERE cart_id = v_cart_id) THEN
            RAISE EXCEPTION 'Cart is empty.';
        END IF;

        SELECT * INTO v_outlet FROM outlets WHERE id = v_cart.outlet_id;
        IF NOT FOUND OR NOT v_outlet.is_active THEN
            RAISE EXCEPTION 'Outlet is not active.';
        END IF;

        -- Slot belongs to the cart's outlet, is future, and has capacity.
        SELECT * INTO v_slot FROM pickup_slots
        WHERE id = v_slot_id AND outlet_id = v_cart.outlet_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Pickup slot not found for this outlet.';
        END IF;
        IF v_slot.slot_date < CURRENT_DATE THEN
            RAISE EXCEPTION 'Pickup slot is in the past.';
        END IF;
        IF v_slot.booked_count >= v_slot.capacity THEN
            RAISE EXCEPTION 'Pickup slot is full.';
        END IF;

        -- Create order first (mirrors place_order columns + group link).
        INSERT INTO orders (
            order_number, user_id, vendor_id, outlet_id, pickup_slot_id,
            checkout_group_id, subtotal, tax, total, status, payment_status,
            payment_method, estimated_prep_minutes, placed_at
        ) VALUES (
            'GAG-' || TO_CHAR(NOW(),'YYYYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::text,1,6)),
            v_user_id, v_outlet.vendor_id, v_outlet.id, v_slot_id,
            v_group_id, 0, 0, 0, 'PLACED', 'PENDING', p_payment_method::payment_method,
            0, NOW()
        ) RETURNING id INTO v_order_id;

        v_subtotal := 0;
        v_prep := 0;

        -- Per-line integrity, availability, inventory, customization folding
        -- (mirrors place_order exactly).
        FOR v_line IN
            SELECT ci.id AS cart_item_id, ci.food_item_id, ci.quantity,
                   fi.name AS food_name, fi.image_url, fi.price AS base_price,
                   fi.is_veg, fi.is_available, fi.prep_time_minutes, fi.outlet_id AS item_outlet
            FROM cart_items ci JOIN food_items fi ON ci.food_item_id = fi.id
            WHERE ci.cart_id = v_cart_id
        LOOP
            IF v_line.item_outlet != v_cart.outlet_id THEN RAISE EXCEPTION 'Cart integrity error.'; END IF;
            IF NOT v_line.is_available THEN RAISE EXCEPTION 'Item "%" is unavailable.', v_line.food_name; END IF;
            IF v_line.quantity <= 0 THEN RAISE EXCEPTION 'Invalid quantity for "%".', v_line.food_name; END IF;

            SELECT quantity_available INTO v_inv_qty FROM inventory
            WHERE food_item_id = v_line.food_item_id FOR UPDATE;
            IF NOT FOUND THEN RAISE EXCEPTION 'No inventory for "%".', v_line.food_name; END IF;
            IF v_inv_qty < v_line.quantity THEN
                RAISE EXCEPTION 'Insufficient stock for "%". Have %, need %.', v_line.food_name, v_inv_qty, v_line.quantity;
            END IF;
            UPDATE inventory SET quantity_available = quantity_available - v_line.quantity,
                updated_at = NOW()
            WHERE food_item_id = v_line.food_item_id;

            v_item_subtotal := v_line.base_price;

            INSERT INTO order_items (order_id, food_item_id, food_name, food_image_url, quantity, unit_price, total_price, is_veg)
            VALUES (v_order_id, v_line.food_item_id, v_line.food_name, v_line.image_url, v_line.quantity, v_line.base_price, v_line.base_price * v_line.quantity, v_line.is_veg)
            RETURNING id INTO v_order_item_id;

            FOR v_customization IN
                SELECT fv.name AS variant_name, fvo.name AS option_name, fvo.extra_price AS db_extra_price
                FROM cart_item_customizations cic
                JOIN food_variants fv ON fv.id = cic.variant_id
                JOIN food_variant_options fvo ON fvo.id = cic.option_id
                WHERE cic.cart_item_id = v_line.cart_item_id
                  AND fv.food_item_id = v_line.food_item_id
                  AND fvo.variant_id = fv.id
            LOOP
                v_item_subtotal := v_item_subtotal + v_customization.db_extra_price;

                INSERT INTO order_item_customizations (order_item_id, variant_name, option_name, extra_price)
                VALUES (v_order_item_id, v_customization.variant_name, v_customization.option_name, v_customization.db_extra_price);
            END LOOP;

            UPDATE order_items
            SET unit_price = v_item_subtotal, total_price = v_item_subtotal * v_line.quantity
            WHERE id = v_order_item_id;

            v_subtotal := v_subtotal + (v_item_subtotal * v_line.quantity);
            v_prep := GREATEST(v_prep, v_line.prep_time_minutes);
        END LOOP;

        -- Server-authoritative totals (5% GST like place_order).
        v_tax := ROUND(v_subtotal * 0.05, 2);
        v_total := v_subtotal + v_tax;
        UPDATE orders
        SET subtotal = v_subtotal, tax = v_tax, total = v_total, estimated_prep_minutes = v_prep
        WHERE id = v_order_id;

        UPDATE pickup_slots SET booked_count = booked_count + 1,
            status = CASE
                WHEN booked_count + 1 >= capacity THEN 'FULL'::pickup_slot_status
                WHEN booked_count + 1 >= capacity * 0.8 THEN 'LIMITED'::pickup_slot_status
                ELSE 'AVAILABLE'::pickup_slot_status
            END
        WHERE id = v_slot_id;

        INSERT INTO pickup_tokens (order_id, token_value, expires_at)
        VALUES (v_order_id, encode(gen_random_bytes(32), 'hex'), NOW() + INTERVAL '2 hours');

        INSERT INTO payments (order_id, checkout_group_id, amount, currency, status)
        VALUES (v_order_id, v_group_id, v_total, 'INR', 'PENDING');

        -- PAY_AT_COUNTER clears only this outlet's cart row.
        IF p_payment_method = 'PAY_AT_COUNTER' THEN
            DELETE FROM cart_items WHERE cart_id = v_cart_id;
            DELETE FROM carts WHERE id = v_cart_id;
        END IF;

        INSERT INTO audit_logs (user_id, action, table_name, record_id,
            new_data)
        VALUES (v_user_id, 'ORDER_PLACED', 'orders', v_order_id,
            jsonb_build_object('outlet_id', v_cart.outlet_id, 'total', v_total,
                               'checkout_group_id', v_group_id));
    END LOOP;

    RETURN QUERY SELECT o.id, o.outlet_id FROM orders o
    WHERE o.checkout_group_id = v_group_id ORDER BY o.created_at;
END;
$$;

REVOKE ALL ON FUNCTION place_orders_batch(JSONB, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION place_orders_batch(JSONB, TEXT, TEXT) TO authenticated;
