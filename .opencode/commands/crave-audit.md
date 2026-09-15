---
description: Audit the entire Crave project without modifying source code. Returns P0-P3 findings with evidence, affected files, consequences, and recommendations.
---

Audit the Crave iOS repository read-only. Do not modify source code.

Load `crave-context` first, then apply `crave-architecture`, `crave-ui`,
`crave-security`, `crave-supabase`, `crave-payments`, `crave-performance`,
and `crave-testing` lenses as relevant.

Inspect: project structure, architecture/layering, DI, navigation, Supabase
repositories/RPCs/realtime, auth/session, SwiftData caches, checkout and
payment state machine, cart flow, order lifecycle, QR pickup, notifications,
student/vendor/admin flows, DesignSystem usage, tests, secrets handling,
configuration, and `supabase/migrations`.

Return findings grouped as P0 critical · P1 high · P2 medium · P3 low.
For every finding include: issue · evidence (file paths and line refs) ·
affected files · consequence · recommendation.

End with: scope covered, what was actually inspected, and what could not be
verified.
