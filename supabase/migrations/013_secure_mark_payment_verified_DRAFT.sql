-- 013_secure_mark_payment_verified.sql
--
-- STATUS: DRAFT — DO NOT APPLY YET.
--
-- Problem (P0, verified in repo files 010_payment_gateways.sql:44-66 and
-- 011_razorpay_fixes.sql:149-180):
--   mark_payment_verified() is SECURITY DEFINER with NO ownership check, NO
--   prior-status precondition, and NO REVOKE/GRANT section, so it remains
--   executable by PUBLIC. Any authenticated user can flip ANY order to PAID
--   with fabricated Razorpay ids, bypassing the Edge-Function HMAC boundary.
--   The vendor order gate (010) treats PAID as trusted, so a forged order
--   would be fulfilled.
--
-- Pre-apply verification REQUIRED (staging project, never prod):
--   1. Confirm Edge Function caller identity:
--        SELECT * FROM verify-razorpay-payment source — does it call this RPC
--        with the service_role key or the invoking user's JWT?
--        - If service_role  -> apply Parts A + B below as written.
--        - If user JWT      -> apply Part B ONLY, keep
--                             GRANT EXECUTE ... TO authenticated, and file a
--                             follow-up to move the Edge Function to
--                             service_role (user-JWT callers can still only
--                             touch their own PENDING orders after Part B,
--                             but self-forgery of own orders remains possible
--                             until Part A lands).
--   2. Forgery probe (staging, test student account, victim test order):
--        SET request.jwt.claims to a student JWT, then:
--        SELECT mark_payment_verified('<victim-order-uuid>', 'fake_pay', 'fake_sig', 'PAID');
--        Expect failure after this migration. Before it, expect success (hole).
--   3. Happy-path probe: full ONLINE checkout on staging must still reach PAID.
--
-- Part A: restrict execution to service_role (the Edge Functions).
--   (Skip Part A if step 1 shows the Edge Function uses the user JWT.)

REVOKE ALL ON FUNCTION mark_payment_verified(UUID, TEXT, TEXT, payment_status) FROM PUBLIC;
REVOKE ALL ON FUNCTION mark_payment_verified(UUID, TEXT, TEXT, payment_status) FROM authenticated;
REVOKE ALL ON FUNCTION mark_payment_verified(UUID, TEXT, TEXT, payment_status) FROM anon;
GRANT EXECUTE ON FUNCTION mark_payment_verified(UUID, TEXT, TEXT, payment_status) TO service_role;

-- Part B: defense-in-depth preconditions inside the function.
-- Applies regardless of Part A.
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
    -- Only terminal verification outcomes are accepted through this path.
    IF p_status NOT IN ('PAID', 'CAPTURED', 'FAILED') THEN
        RAISE EXCEPTION 'Invalid verification status.';
    END IF;

    SELECT user_id, payment_status INTO v_owner_id, v_current_status
    FROM orders WHERE id = p_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    -- Only a PENDING order can transition via verification (idempotent
    -- re-verify of an already-PAID order is a no-op success for callers
    -- that retry after a lost response).
    IF v_current_status IN ('PAID', 'CAPTURED') THEN
        RETURN;
    END IF;
    IF v_current_status <> 'PENDING' THEN
        RAISE EXCEPTION 'Order is not awaiting payment.';
    END IF;

    -- When invoked with a user JWT (Part A not yet applied), the caller must
    -- own the order. service_role callers bypass RLS/auth checks by design;
    -- auth.uid() is NULL for them, so skip the ownership check then.
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

-- NOTE: statements above use ';' terminators. Several earlier repo migration
-- files (003/005/008/010/011) contain '.'-terminated statements that cannot
-- have applied verbatim; the live project state must be diffed before ANY
-- migration in this chain is treated as applied truth.
