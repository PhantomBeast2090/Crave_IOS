---
name: crave-ui
description: Crave's playful food-centric SwiftUI design system and screen UX. Use when building or auditing any Crave screen, component, theme token, loading/empty/error state, dark mode, Dynamic Type, or VoiceOver support.
---

# Crave UI

Design language: playful, energetic, food-centric, youthful, premium,
campus-native, distinctly iOS, visually memorable. Food discovery, outlet
discovery, cart, checkout clarity, order tracking, notifications, and vendor
operational speed come first.

## Use the existing DesignSystem — never bypass it

- Tokens: `GagColors` (`Core/DesignSystem/AppColors.swift`) — brand orange
  `0xE8431A`, amber, adaptive background/surface/text, semantic
  success/error/warning/info, order-status colors, slot
  available/limited/full, category colors, veg/non-veg.
- `AppTheme.brandGradient` / `heroGradient`, `gagCard()` surface,
  `GagShapes` radii/spacing, `Typography`.
- Components: `GagButton`, `GagTextField`, `GagTopBar`, `GagBottomNav`,
  `FoodItemCard`, `QuantitySelector`, `OrderStatusBadge`, `OrderTimelineView`,
  `QRCodeView`, `GagToast`, `GagStateViews` (Loading/Error/Empty).
- Target direction is warm and appetising (orange/amber/violet/mint on cream);
  if adapting tokens, extend `GagColors`/semantic tokens — never hardcode
  feature-level colors in screens.

## Avoid

Generic SaaS layouts, AI-generated-looking UI, excessive glassmorphism, random
gradients, rainbow interfaces, visual noise, hardcoded colors in features.

## Every major screen must consider

Loading · loaded · empty · error · retry · offline/degraded where applicable ·
dark mode (adaptive tokens + `ThemeManager`) · Dynamic Type · VoiceOver labels
and traits · contrast · 44pt touch targets · Reduce Motion.

## Rules

- Views present; state and logic live in the ViewModel (`crave-architecture`).
- Status/slot colors must use the semantic tokens so order states read
  consistently across student, vendor, and admin flows.
- Gestures complement, never replace, essential actions.
- Motion and haptics belong to `crave-motion`; accessibility specifics route to
  `ios-accessibility` when deeper expertise is needed.
