---
name: crave-performance
description: SwiftUI rendering, memory, networking, and realtime performance for Crave. Use when profiling slow screens, fixing jank, reducing network or realtime churn, cutting memory retention, or validating responsiveness before release.
---

# Crave Performance

Optimise in order: correctness → perceived responsiveness → rendering →
memory → networking → battery. Never optimise on intuition when profiling
evidence is obtainable.

## Investigate first

- Unnecessary SwiftUI invalidation: oversized `@Observable` observation,
  expensive `body` computation, unstable `ForEach` IDs in outlet/food/order lists.
- Eager rendering: catalogue images without caching/lazy loading
  (`AsyncImage` + disk cache), full order-history renders, unthrottled search
  (debounced `search_food` is the pattern).
- Realtime churn: duplicate channels, per-event full-list refetch or UI
  rebuilds on every status tick (`observeOrderStatus`/`observeOrders` paths).
- Network: missing cancellation on disappearing views, unguarded background
  refreshes, repeated identical PostgREST reads that a cache already serves.
- Memory: leaked `AsyncStream` continuations/channel handles, retained
  ViewModels or services beyond their flow, unbounded image caches.
- Animation cost: heavy transitions replayed by realtime updates.

## Method

Baseline → change → build → profile → compare → document. Use Instruments
(Time Profiler, Allocations, Leaks, Network) for non-trivial claims; simulator
for iteration, real device for verdicts. Route deep tooling to
`debugging-instruments` and view-layer specifics to `swiftui-performance-audit`.

## Rules

- Keep skeletons/loading states instant even if data is slow — perceived
  responsiveness is a feature (coordinate with `crave-ui`).
- Cancellation on disappear and channel cleanup on sign-out are correctness
  issues, not optional polish.
- Report measured before/after numbers, device, and what was profiled;
  never claim "faster" without evidence.
