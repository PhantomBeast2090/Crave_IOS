# AGENTS.md — Crave iOS

Crave is an existing, production-oriented native iOS campus food-ordering app
(SwiftUI + Supabase + Razorpay). Do not rebuild it from scratch.

- Inspect the repository before implementing; the repo is the source of truth
  (see `.opencode/skills/crave-context/SKILL.md`).
- Preserve the MVVM + Clean layering, repository protocols, manual DI via
  `AppState`, backend contracts/RPCs, auth, realtime, SwiftData caches, and
  vendor/admin flows.
- Reuse the DesignSystem (`GagColors`, `AppTheme`, `gagCard()`, shared
  components). Never hardcode feature-level colors or bypass tokens.
- Payment verification is server-authoritative. Never clear the cart before
  verified payment; never trust the client callback.
- No secrets in source, logs, or screenshots (`Secrets.swift` is gitignored).
  Respect Supabase RLS; privileged logic stays server-side.
- Accessibility is required (VoiceOver, Dynamic Type, contrast, 44pt targets);
  dark mode is required; Reduce Motion must be respected.
- Performance matters: profile with Instruments before claiming improvements.
- Tests matter: cover critical journeys and failure paths; new bugs get
  regression tests when practical.
- For any substantial change, follow `.opencode/skills/crave-muse-protocol/`:
  UNDERSTAND → SELECT SKILLS → PLAN → IMPLEMENT → VALIDATE → AUDIT → REPORT.
- Verify rather than assume. Report what was actually checked; label
  simulator vs real-device validation. Never say it works without evidence.
