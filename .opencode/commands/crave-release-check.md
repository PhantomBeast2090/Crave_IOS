---
description: Production and App Store readiness audit for Crave without modifying source.
---

Perform a production/App Store readiness audit of Crave. Do not modify source
code.

Load `crave-context`, `crave-release`, `crave-security`, and `crave-qa`.
Verify each item with evidence — never assume readiness.

Check: production vs staging configuration (Supabase URL/keys, endpoints) ·
secrets handling (source, logs, screenshots) · entitlements and permission
strings (camera for QR scan) · privacy manifests and required-API reasons ·
notification and payment production configuration · applied migrations/RLS ·
logging hygiene · accessibility and dark-mode state · crash risks
(force-unwraps, fatalError paths, unhandled states) · version/build, icon,
launch screen, metadata readiness · test suite and QA status.

Return: go/no-go verdict · P0 blockers with evidence and remediation · P1/P2
follow-ups · per-item verification status (verified / not verified / needs
device). End with the single most important next action before release.
