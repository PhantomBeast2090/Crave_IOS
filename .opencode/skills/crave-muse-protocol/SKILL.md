---
name: crave-muse-protocol
description: Mandatory orchestration workflow for substantial Crave work. Use for any non-trivial Crave task — feature, fix, refactor, audit, or release — to enforce understand, select expertise, plan, implement, validate, audit, and report.
---

# Crave Muse Protocol

For any substantial Crave task, follow all seven steps in order. Never jump
from request to code.

## STEP 1 — UNDERSTAND

Inspect before coding: relevant source files, architecture, existing
components, backend contracts (`BACKEND_MAP.md`, migrations), tests, and the
applicable skill files in `.opencode/skills/`. Ground yourself in
`crave-context` first. Do not code yet.

## STEP 2 — SELECT EXPERTISE

Load every skill the task touches. Examples:

- UI task: `crave-context` + `crave-ui` + `crave-motion`, plus `swiftui-expert-skill`;
  add `ios-accessibility` when interaction or readability changes.
- Payment task: `crave-context` + `crave-payments` + `crave-security` +
  `crave-supabase` + `crave-testing`.
- Supabase/realtime task: `crave-context` + `crave-supabase` +
  `ios-networking` + `authentication` where identity is involved.
- Performance task: `crave-context` + `crave-performance` +
  `swiftui-performance-audit` + `debugging-instruments`.
- Release task: `crave-context` + `crave-release` + `crave-security` +
  `crave-qa` + `app-store-review`.
- Live order tracking: `crave-supabase` + `crave-ui` + `crave-motion`, plus
  `activitykit` / `push-notifications` if those surfaces are in scope.

## STEP 3 — PLAN

Before substantial implementation, produce internally: objective · current
implementation (files) · proposed change · affected files · dependencies ·
backend impact · security implications · performance implications ·
accessibility implications · tests · validation strategy. Surface the plan for
approval when the change is architectural, security-sensitive, or backend-touching.

## STEP 4 — IMPLEMENT

Smallest coherent increment. Reuse existing components and the DesignSystem.
Follow `crave-architecture` layering. Do not rewrite unrelated systems. Keep
compiling at each step.

## STEP 5 — VALIDATE

Run what fits: build · affected + adjacent tests · static checks · simulator
validation · UI/state checks · profiling for perf touches · security review
for sensitive touches. Label simulator vs device results.

## STEP 6 — AUDIT

Review the change for functionality · architecture · UI · accessibility ·
security · performance · regression risk across student/vendor/admin flows.

## STEP 7 — REPORT

State: what changed · files changed · tests run (with results) · build result ·
validation performed · known risks · remaining work. Never say it works unless
it was verified. File-level citations for key claims.
