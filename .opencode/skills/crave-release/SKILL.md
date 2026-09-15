---
name: crave-release
description: Production and App Store readiness audits for Crave. Use when preparing TestFlight or App Store releases, checking production configuration, secrets, entitlements, privacy manifests, payments, notifications, or release regressions.
---

# Crave Release

Audit before every release. Never claim release readiness without evidence —
each check below needs a verified result, not an assumption.

## Audit checklist

- Production configuration: Supabase URL/anon key point at production;
  `Secrets.swift` present via secure provisioning, never committed;
  `AppConfig.isBackendConfigured` true; no staging/test endpoints.
- Secrets: no keys in source, logs, screenshots, or crash reports; Razorpay
  uses production key material server-side only.
- Entitlements/capabilities match usage (camera for vendor QR scan with
  `NSCameraUsageDescription` set and justified).
- Privacy: permission strings accurate; privacy manifests and required-API
  reasons current; notification usage matches what is configured.
- Payments: production Razorpay/Edge Function configuration verified with a
  real (reversible) transaction path; failure and refund paths reachable.
- Supabase: production RLS/migrations applied (001–012 verified, including the
  `012_` admin-stats fix); realtime and Edge Functions healthy.
- Quality gates: clean build, full test suite green (`crave-testing`), QA pass
  (`crave-qa`), security pass (`crave-security`), performance sanity
  (`crave-performance`).
- Crash risks: force-unwraps on network/decode paths, `fatalError` on
  `ModelContainer` creation (degraded-launch path?), unhandled End-of-flow states.
- App Store: version/build numbers, icons, launch screen, screenshots/metadata
  if requested; route review-policy depth to `app-store-review`.

## Rules

- Produce a go/no-go with P0 blockers listed first and evidence per item.
- Any release-blocker fix re-enters through `crave-muse-protocol`
  (implement → validate → audit), not as a hot tweak.
