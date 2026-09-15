---
description: Threat-oriented security review of Crave without modifying source code.
---

Perform a threat-oriented security review of Crave. Do not modify source code.

Load `crave-context`, `crave-security`, `crave-supabase`, and
`crave-payments`. For each area use:
asset → attacker → trust boundary → attack → mitigation → verification.

Cover: auth/session storage and lifecycle · student/vendor/admin data exposure ·
payment identifiers and Razorpay handling (client vs server trust) · QR pickup
tokens · Supabase keys and secrets handling (source, logs, screenshots) ·
realtime channel authorization and cleanup · RLS and RPC enforcement
(`supabase/migrations/`) · privileged admin/vendor operations · error copy
leakage · sign-out cleanup.

Return P0–P3 findings, each with: issue · evidence (file refs) · consequence ·
recommendation · how to verify the fix. End with what was inspected and what
could not be verified (e.g. server-side behavior requiring backend access).
