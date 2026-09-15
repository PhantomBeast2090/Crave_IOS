---
name: crave-testing
description: Testing strategy for Crave's critical journeys. Use when writing unit, domain, integration, or UI tests for auth, cart, checkout, payments, orders, QR pickup, vendor flows, realtime recovery, roles, or navigation.
---

# Crave Testing

Test behaviour, not implementation details. Existing suites:
`Crave_IOSTests` (`CartMathTests`, `DecodingTests`) and `Crave_IOUITests`
(`AcceptanceTests`). Use modern Swift Testing for unit/domain tests and
XCTest/XCUITest for UI automation.

## Prioritise

Auth (login/register/restore/logout, role routing) · cart math (single-outlet
rule, customizations, 5% tax vs server) · checkout state machine
(`CheckoutViewModel.FlowState` transitions, gating, retry-from-terminal-only)
· payment verification paths (success/cancel/fail/timeout, cart preserved
until verified) · order lifecycle transitions · QR pickup
(token render + `verify_pickup_token` READY→PICKED_UP + expiry) · vendor order
management RPCs · realtime recovery (disconnect/reconnect, channel cleanup) ·
role-based access (student/vendor/admin boundaries) · critical navigation
(checkout → confirmation → tracking → QR; notification deep-links).

## Critical journey (happy + failure paths)

Student login → browse → food detail → add to cart → checkout → payment →
order tracking → pickup. Every step needs its failure twin: offline, empty,
error, retry, expired session, cancelled payment, failed verification.

## Rules

- New production bug → new regression test when practical.
- Test through repository protocols with in-memory fakes
  (`DefaultAppRepository.makeInMemory` pattern); never hit the live backend
  from unit tests.
- Keep DTO/decoding tests current with the real schema (`OrderDto` nesting,
  `search_food` flat names) so backend drift fails fast.
- Report exactly what ran (suite, count, result); never claim coverage that
  was not executed.
- Route Swift Testing API depth to `swift-testing-pro` and simulator execution
  to `ios-simulator`.
