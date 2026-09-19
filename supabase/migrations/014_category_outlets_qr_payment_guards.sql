-- 014_category_outlets_qr_payment_guards.sql
--
-- STATUS: AUTHORED — NOT APPLIED. Requires explicit approval before running
-- against any project (see rollback notes at the end of each section).
--
-- Three independent, additive, non-breaking sections:
--   A. mark_payment_verified preconditions (defense in depth; no grant changes)
--   B. pickup_tokens owner-scoped SELECT (fixes student QR screen RLS denial)
--   C. get_outlets_for_category RPC (category → outlet discovery reads)
--
-- Part A of the full payment lockdown (service_role-only EXECUTE) is
-- deliberately NOT included: the Edge Functions' caller identity
-- (service_role vs invoking-user JWT) is unverified, and revoking
-- `authenticated` before confirming would break legitimate verification.
-- See 013_secure_mark_payment_verified_DRAFT.sql for the full design.

-- =====================================================================
-- A. mark_payment_verified: ownership + state preconditions
-- RISK: LOW. Only ADDS failure modes (unauthorized/non-pending calls now
-- raise); legitimate Edge Function calls (own order, PENDING status,
-- PAID/CAPTURED/FAILED outcome) are unaffected.
-- ROLLBACK: restore 011 definition (CREATE OR REPLACE from 011_razorpay_fixes.sql).
-- =====================================================================
CREATE OR REPLACE FUNCTION mark_payment_verified(
    p_order_id UUID,
    p_razorpay_payment_id TEXT,
    p_razorpay_signature TEXT,
    p_status payment_status DEFAULT 'PAID'
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_user_id UUID;
    v_owner_id UUID;
    v_current_status payment_status;
BEGIN
    IF p_status NOT IN ('PAID', 'CAPTURED', 'FAILED') THEN
        RAISE EXCEPTION 'Invalid verification status.';
    END IF;

    SELECT user_id, payment_status INTO v_owner_id, v_current_status
    FROM orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    -- Idempotent re-verify: an already-PAID/CAPTURED order succeeds silently
    -- so lost-response retries are safe.
    IF v_current_status IN ('PAID', 'CAPTURED') THEN
        RETURN;
    END IF;
    IF v_current_status <> 'PENDING' THEN
        RAISE EXCEPTION 'Order is not awaiting payment.';
    END IF;

    -- service_role callers (Edge Functions) have NULL auth.uid() and bypass
    -- this check by design; user-JWT callers must own the order.
    IF auth.uid() IS NOT NULL AND auth.uid() <> v_owner_id THEN
        RAISE EXCEPTION 'Not authorized to verify this order.';
    END IF;

    UPDATE payments
    SET razorpay_payment_id = p_razorpay_payment_id,
        razorpay_signature = p_razorpay_signature,
        status = p_status,
        updated_at = NOW()
    WHERE order_id = p_order_id;

    UPDATE orders
    SET payment_status = p_status,
        updated_at = NOW()
    WHERE id = p_order_id
    RETURNING user_id INTO v_user_id;

    IF p_status IN ('PAID', 'CAPTURED') THEN
        DELETE FROM cart_items WHERE cart_id = (SELECT id FROM carts WHERE user_id = v_user_id LIMIT 1);
        UPDATE carts SET outlet_id=NULL, subtotal=0, tax=0, total=0, updated_at=NOW() WHERE user_id = v_user_id;
    END IF;
END;
$$;

-- =====================================================================
-- B. pickup_tokens: owner-scoped SELECT for students
-- RISK: LOW (purely additive policy). Without this, the student QR screen
-- is RLS-denied on every load: existing policies cover vendors (own outlet)
-- and admins only.
-- ROLLBACK: DROP POLICY pickup_tokens_owner_select ON pickup_tokens;
-- =====================================================================
DROP POLICY IF EXISTS pickup_tokens_owner_select ON pickup_tokens;
CREATE POLICY pickup_tokens_owner_select ON pickup_tokens
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = pickup_tokens.order_id
          AND orders.user_id = auth.uid()
    )
);

-- =====================================================================
-- C. get_outlets_for_category: exact-FK outlet discovery with dish counts
-- RISK: LOW. New read-only SECURITY DEFINER RPC + grants mirroring
-- search_food (authenticated, anon). No existing behavior changes.
-- Only outlets that are active AND currently offer available dishes in the
-- category are returned — an outlet with zero matching dishes never appears.
-- ROLLBACK: DROP FUNCTION get_outlets_for_category(UUID);
-- =====================================================================
CREATE OR REPLACE FUNCTION get_outlets_for_category(p_category_id UUID)
RETURNS TABLE (
    outlet_id UUID,
    outlet_name TEXT,
    location TEXT,
    is_open BOOLEAN,
    dish_count BIGINT
)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
    SELECT
        o.id,
        o.name,
        o.location_description,
        o.is_open,
        COUNT(fi.id)
    FROM outlets o
    JOIN food_items fi
      ON fi.outlet_id = o.id
     AND fi.category_id = p_category_id
     AND fi.is_available
     AND fi.deleted_at IS NULL
    WHERE o.is_active
      AND o.deleted_at IS NULL
    GROUP BY o.id, o.name, o.location_description, o.is_open
    ORDER BY COUNT(fi.id) DESC, o.name ASC;
$$;

REVOKE ALL ON FUNCTION get_outlets_for_category(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_outlets_for_category(UUID) TO authenticated, anon;
