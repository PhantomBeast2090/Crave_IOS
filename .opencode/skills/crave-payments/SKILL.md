---
name: crave-payments
description: Razorpay payment state machine and verification for Crave. Use when working on checkout, place_order, Razorpay sheet, payment verification, cart clearing, payment failure/cancel/retry, duplicate submissions, or any payment audit.
---

# Crave Payments

Payment is a critical state machine, implemented in
`Feature/Student/Home/CheckoutViewModel.swift` with `RazorpayService`
(`Core/Payment/`) and `SupabasePaymentRepository` (`Core/App/`). Audit the
actual implementation — never assume it follows this model.

## Expected flow

`place_order` → `create-razorpay-order` (Edge Function returns public `key_id`
+ `razorpay_order_id`) → present sheet (`RazorpayService.pay`) → sheet result
→ `verify-razorpay-payment` (HMAC, server-side) → confirmed order → clear cart.

PAY_AT_COUNTER clears the cart immediately on placement; ONLINE keeps the cart
until verification succeeds. `AppConfig.taxRate` (5%) mirrors the server —
the server computes the authoritative total.

## Never

- Treat the client sheet callback as authoritative success.
- Clear the cart before verified payment (ONLINE path).
- Store or expose Razorpay secrets in the app; only the per-order public
  `key_id` from the backend is used.
- Fabricate payment credentials or mark payment success locally.
- Allow double-tap/duplicate submissions — gate placement on `FlowState`
  (`canPlaceOrder` pattern: block while `placing`/`awaitingPayment`/`verifying`).
- Turn failure into success: cancellation, failure, timeout, network loss,
  verification failure, and backend timeout all keep the order intact with the
  cart preserved for retry.

## Handle explicitly

Cancellation (order remains, retryable) · failure · timeout/network loss ·
verification failure ("money is safe" copy + support path with order ID) ·
stale state (cancel superseded pending order before retry) · duplicate
submission · interrupted payment (relaunch recovery via order history) · retry
from terminal states only (`idle`/`error`/`paymentCancelled`).

## Rules

- Verification stays server-authoritative via Edge Function +
  `mark_payment_verified`; the sheet result only advances the local flow.
- Single sheet at a time; drop stale continuations rather than leaking them.
- Every payment change needs failure-path tests (see `crave-testing`) and a
  security pass (see `crave-security`).
