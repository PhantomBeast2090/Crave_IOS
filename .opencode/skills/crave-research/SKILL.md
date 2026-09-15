---
name: crave-research
description: Technical and product research for Crave. Use when evaluating new dependencies, architectures, SDKs, or backend approaches, comparing alternatives, or answering whether Crave should adopt an external technology.
---

# Crave Research

No dependency, SDK, or rewrite merely because it is fashionable. The current
stack (SwiftUI, supabase-swift, Razorpay iOS SDK, SwiftData cache, AVFoundation
QR) is the default — displace it only with evidence.

## Before recommending anything external

1. State the actual problem with file-level evidence from the repo.
2. Inspect the current implementation that already covers (part of) it.
3. Compare alternatives (including "do nothing" / "build on existing")
   on: Apple platform fit · Supabase/backend compatibility · security
   (secrets, RLS, verification boundaries) · performance cost · maintenance
   burden · licence compatibility with the App Store and this repo.
4. Explain trade-offs and give a single recommendation with migration and
   rollback sketches.

## Rules

- Check `IOS_MIGRATION_PLAN.md` open items first — several "should we…"
  questions (Razorpay SDK vs web fallback, PAY_AT_COUNTER exposure, push vs
  realtime-only) are already framed there awaiting decisions, not new research.
- Never vendor third-party content into the repo without checking its licence.
- Academic or deep technical research uses structured planning with cited,
  verified evidence — no speculative claims.
- Route findings back into an implementation plan (`crave-muse-protocol`
  STEP 3) rather than jumping to code.
