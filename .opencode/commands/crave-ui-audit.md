---
description: Audit Crave UI/UX, SwiftUI architecture, accessibility, interaction, and visual consistency without modifying source.
---

Audit Crave's UI/UX read-only. Do not modify source code.

Load `crave-context`, `crave-ui`, `crave-motion`, and `crave-qa`. Walk the
student, vendor, and admin flows screen by screen.

Cover: SwiftUI architecture (view vs ViewModel separation, state handling) ·
visual consistency (DesignSystem token use, hardcoded colors, spacing/type) ·
loading/loaded/empty/error/retry/offline states per screen · dark mode ·
Dynamic Type · VoiceOver labels and traversal · contrast and touch targets ·
Reduce Motion · navigation transitions and micro-interactions · food/outlet
discovery, cart, checkout clarity, order tracking, notifications, vendor speed.

Return P0–P3 findings, each with: issue · evidence (file refs) · affected
screens · consequence · recommendation. End with what was inspected and what
needs on-device or simulator verification.
