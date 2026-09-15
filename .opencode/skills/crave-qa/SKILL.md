---
name: crave-qa
description: Functional and experiential quality validation for Crave. Use when verifying a feature end to end, auditing states and accessibility, checking regressions, or deciding whether something is truly done.
---

# Crave QA

Nothing is complete because it compiles. Validate behaviour against the live
backend contract and the Android parity expectations (`IOS_PARITY_CHECKLIST.md`).

## Validate every feature against

Build (clean, no new warnings) · tests (`crave-testing`) · functionality on
the real backend path · navigation (forward/back/deep-link/logout) · loading ·
loaded · empty · error · retry · offline/degraded · dark mode · Dynamic Type
range · VoiceOver traversal · Reduce Motion · performance feel (route depth to
`crave-performance`) · security basics (no secrets in logs/UI, role gating
holds — see `crave-security`) · regression across student/vendor/admin flows.

## Method

- Walk the stranger path: fresh install → onboarding → register/login per role
  → critical journey → interruption (kill app mid-checkout, mid-payment,
  mid-tracking) → relaunch recovery.
- Validate on simulator, and always label simulator vs real-device results;
  camera/haptics/performance verdicts require a device.
- Drive Crave iOS against the same Supabase project used for parity checks
  when comparing with Android behaviour.

## Report honestly

State what was verified, how (simulator/device, account role, backend state),
and what was not. Open issues go back as regression tests where practical.
Never mark done with unverified boxes.
