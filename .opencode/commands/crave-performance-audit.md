---
description: Audit Crave rendering, networking, memory, realtime, and responsiveness without modifying source.
---

Audit Crave's performance read-only. Do not modify source code.

Load `crave-context`, `crave-performance`, and `crave-supabase`. Trace hot
paths: home/catalogue rendering and images, search debouncing, cart/checkout,
order tracking realtime updates, notification feed, vendor order feed.

Cover: SwiftUI invalidation and body cost · list IDs and lazy loading · image
loading/caching · realtime subscriptions (duplication, churn per event,
cleanup) · network calls (redundancy, cancellation, retry behavior) · SwiftData
cache efficiency · memory retention (continuations, channels, ViewModels) ·
animation cost · launch and navigation responsiveness.

Return P0–P3 findings, each with: issue · evidence (file refs) · consequence ·
recommendation · how to measure (Instruments instrument, metric, device class).
Do not claim improvements — propose the baseline → change → profile → compare
plan for each P0/P1. End with what was inspected statically vs profiled.
