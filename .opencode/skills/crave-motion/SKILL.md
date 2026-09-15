---
name: crave-motion
description: Native SwiftUI motion and haptic feedback for Crave. Use when adding or auditing animations for add-to-cart, cart badge, favorites, quantity changes, navigation transitions, order placement, status changes, order-ready celebration, or QR/pickup feedback.
---

# Crave Motion

Motion communicates state change and confirms feedback. It is never decoration.

## Prioritise

Add-to-cart feedback · cart badge animation · favorite toggle · quantity
changes · navigation transitions · order placement success · order status
transitions · order-ready celebration · QR/pickup scan feedback · subtle
haptics for success/failure/selection.

## Prefer native SwiftUI APIs

`animation` · `transition` · `contentTransition` (e.g. numeric cart counts) ·
`symbolEffect` · `matchedGeometryEffect` (e.g. food image → detail) ·
`PhaseAnimator` / `KeyframeAnimator` (order-ready celebration) ·
`sensoryFeedback` for haptics.

## Rules

- One purposeful animation per state change. Do not animate everything.
- Respect Reduce Motion: gate celebratory/large motion behind
  `AccessibilityReduceMotion`, keeping state changes instant and legible.
- Keep animations cancellable and cheap; status-driven realtime updates (see
  `crave-supabase`) must not retrigger heavy transitions per event.
- Gestures must never be the only path to essential actions.
- Coordinate with `crave-ui` (visual states) and `crave-performance` if an
  animation drops frames — profile with Instruments, don't guess.
