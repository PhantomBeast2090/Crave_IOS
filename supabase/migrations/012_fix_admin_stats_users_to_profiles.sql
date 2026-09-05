-- =============================================================================
-- Migration 012: Fix get_admin_stats to reference the real users table.
--
-- Background: migration 009 created get_admin_stats() reading from a "users"
-- table. That table does not exist -- 001_initial_schema.sql defines the user
-- table as "profiles". The RPC therefore errored at runtime, breaking the
-- Admin dashboard.
--
-- This migration rewrites the function to query profiles.
--
-- HOW TO APPLY: open the Supabase dashboard -> SQL editor -> paste this file ->
-- Run. (Supabase project: btdmhveaqssuuhyoyanz)
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION get_admin_stats() RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_result JSONB;
BEGIN
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required.'; END IF;

    -- Verify admin role (was: FROM users)
    SELECT role INTO v_role FROM profiles WHERE id = v_user_id;
    IF v_role != 'ADMIN' THEN RAISE EXCEPTION 'Unauthorized: Requires ADMIN role.'; END IF;

    -- Compute stats (was: FROM users)
    SELECT jsonb_build_object(
        'totalUsers', (SELECT count(*) FROM profiles WHERE role = 'STUDENT'),
        'totalVendors', (SELECT count(*) FROM profiles WHERE role = 'VENDOR'),
        'totalOutlets', (SELECT count(*) FROM outlets),
        'totalOrders', (SELECT count(*) FROM orders),
        'activeOrders', (SELECT count(*) FROM orders WHERE status IN ('PLACED', 'ACCEPTED', 'PREPARING', 'READY')),
        'completedOrders', (SELECT count(*) FROM orders WHERE status = 'PICKED_UP'),
        'revenue', COALESCE((SELECT sum(total) FROM orders WHERE status = 'PICKED_UP'), 0),
        'ordersToday', (SELECT count(*) FROM orders WHERE DATE(placed_at) = CURRENT_DATE),
        'revenueToday', COALESCE((SELECT sum(total) FROM orders WHERE status = 'PICKED_UP' AND DATE(placed_at) = CURRENT_DATE), 0)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- Re-grant defensively (should already be granted by migration 009)
REVOKE ALL ON FUNCTION get_admin_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_admin_stats() TO authenticated;

COMMIT;
