---
name: crave-security
description: Threat-oriented security review for Crave. Use when touching auth, sessions, student/vendor/admin data, payments, Razorpay, QR pickup tokens, Supabase keys, RLS, realtime authorization, Edge Functions, admin operations, or before any release.
---

# Crave Security

Crave handles sessions, PII, payment identifiers, and pickup credentials.
Server-side enforcement (RLS + `SECURITY DEFINER` RPCs) is the security layer;
client-side role checks are UX only.

## Security-sensitive assets

Auth/session data · student/vendor/admin PII · payment identifiers and
Razorpay payloads · QR pickup tokens (`pickup_tokens.token_value`, 64-hex,
2h expiry) · Supabase anon key handling · realtime channel authorization ·
Edge Function trust boundaries · privileged admin operations
(`AdminRepository`, `admin_toggle_outlet_status`).

## Never

- Hardcode or commit secrets. Secrets live only in gitignored
  `Crave_IOS/Core/Config/Secrets.swift` (template: `Secrets.example.swift`);
  the public Razorpay `key_id` is returned per-order by the backend, never
  stored in the app.
- Log tokens, payment secrets/signatures, or QR token values
  (`print` of secrets is a finding, even in debug paths).
- Store secrets or tokens in `UserDefaults` (onboarding flags and theme prefs
  are fine; credentials are not).
- Trust the client payment callback — verification is server-authoritative
  (see `crave-payments`).
- Bypass RLS or move privileged logic client-side for convenience; all server
  mutations go through existing RPCs.
- Expose admin/vendor actions through client-side checks alone.
- Accept QR pickup as valid because the client says so — only
  `verify_pickup_token` (READY → PICKED_UP) authorises it.

## Review method

For each change: asset → attacker → trust boundary → attack → mitigation →
verification. Check `supabase/migrations/002_rls_policies.sql`,
`003_harden_backend`, `007_`, `008_`, `010_` for the enforced posture, and
confirm vendor visibility rules for online (PAID-gated) orders still hold.

## Rules

- Error copy must never leak tokens or server internals to the user or logs.
- Sign-out must clear sessions and realtime channels (`AppState.signOut`
  pattern: `removeAllChannels()` before sign-out completes).
- Route deeper iOS platform security (Keychain design, ATS, privacy manifests)
  to `swift-security`; payments specifics to `crave-payments`.
