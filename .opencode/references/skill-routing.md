# Skill Routing — Crave iOS

Start every substantial task with `crave-context`, then orchestrate via
`crave-muse-protocol`. Add specialist skills per area below. `crave-*` skills
are project-local (`.opencode/skills/`); all other names below are installed
upstream skills (global, `~/.config/opencode/skills/_upstream/` — see registry).

- GENERAL → `crave-context` → `crave-muse-protocol`
- ARCHITECTURE / REFACTOR → `crave-architecture` → `swift-architecture-skill`
- SWIFTUI / SCREENS / COMPONENTS → `crave-ui` → `swiftui-expert-skill` → `swiftui-animation` → `ios-accessibility` where relevant
- UI DESIGN / REDESIGN / BRAND → `swiftui-design-skill` → `swiftui-design-tokens` → `crave-ui`
- DESIGN TOKENS (colors, spacing, type, motion) → `swiftui-design-tokens` → `crave-ui`
- MOTION / HAPTICS → `crave-motion` → `swiftui-animation`
- GESTURES → `swiftui-gestures`
- CONCURRENCY (`async/await`, `AsyncStream`, tasks) → `swift-concurrency`
- SECURITY / AUTH DATA / SECRETS / RLS REVIEW → `crave-security` → `swift-security`
- AUTH (Sign in with Apple, passkeys, OAuth, biometrics) → `authentication` → `swift-security`
- SUPABASE / RPC / REALTIME / OFFLINE / REPOSITORIES → `crave-supabase` → `ios-networking` → `authentication`
- PAYMENTS / CHECKOUT / RAZORPAY → `crave-payments` → `swift-security` → `ios-networking` → `swift-concurrency` → `swift-testing-pro`
- PERFORMANCE / JANK / MEMORY / NETWORK CHURN → `crave-performance` → `swiftui-performance-audit` → `debugging-instruments` when runtime evidence is needed
- TESTING (unit/domain/UI) → `crave-testing` → `swift-testing-pro` → `ios-simulator` for simulator execution
- LOCAL CACHE (SwiftData entities as offline cache) → `crave-supabase` → `swiftdata` → `swift-concurrency` when isolation is involved
- QR SCAN / CAMERA → `crave-supabase` (verify_pickup_token) + `crave-qa` (device check)
- NOTIFICATIONS → `push-notifications`
- LIVE ORDER TRACKING → `activitykit` → `push-notifications` → `swift-concurrency` → `crave-ui` → `crave-motion`
- LINT / STATIC CHECKS → `swiftlint`
- SIMULATOR VALIDATION → `ios-simulator` → `crave-qa`
- RELEASE / TESTFLIGHT / APP STORE → `crave-release` → `app-store-review` → `swift-security` → `ios-accessibility` → `ios-simulator` → `debugging-instruments` where appropriate
- RESEARCH (academic only: lit review, novelty, experiments) → `research-agent`
- PERSISTENCE → `swiftdata` → `swift-concurrency` when isolation/concurrency is involved

## Installed upstream skill registry

Installed globally (not vendored into this repo) so complete SKILL.md files,
references, examples, scripts, and future `git pull` updates stay intact.
Verified via `opencode debug skill` on 2026-09-15.

| Skill | Source repo @ commit | Licence | Global location |
|---|---|---|---|
| `swiftui-expert-skill` | `AvdLee/SwiftUI-Agent-Skill` @ `00a94e1` | MIT | `skills/_upstream/swiftui-agent-skill/skills/swiftui-expert-skill/` |
| `swift-concurrency` | `AvdLee/Swift-Concurrency-Agent-Skill` @ `d577081` | MIT | `skills/_upstream/swift-concurrency-agent-skill/skills/swift-concurrency/` |
| `swiftui-design-skill` | `Wholiver/swiftui-design-skill` @ `2c82638` | MIT | `skills/_upstream/swiftui-design-skill/` |
| `swiftui-design-tokens` | `eworthing/agent-skills` @ `090e206` (sparse: `swiftui-design-tokens/`) | MIT | `skills/_upstream/eworthing-agent-skills/swiftui-design-tokens/` |
| `swift-architecture-skill` | `efremidze/swift-architecture-skill` @ `d80c4ee` (sparse: `swift-architecture-skill/`) | MIT | `skills/_upstream/swift-architecture-skill/swift-architecture-skill/` |
| `swift-testing-pro` | `twostraws/Swift-Testing-Agent-Skill` @ `2d6bba1` (OpenCode variant; Claude `skills/` subdir excluded) | MIT | `skills/_upstream/swift-testing-agent-skill/swift-testing-pro/` |
| `app-store-review` | `safaiyeh/app-store-review-skill` @ `d7650c3` | MIT | `skills/_upstream/app-store-review-skill/` |
| `research-agent` | `ngtiendong/Academic-Research-Agent-Skill` @ `41c611c` (sparse: `SKILL.md`, `references/`, `scripts/`, `examples/`; website `docs/` excluded) | MIT | `skills/_upstream/academic-research-agent-skill/` |
| `swiftui-performance-audit` | `steipete/agent-scripts` @ `2784a38` (sparse: `skills/swiftui-performance-audit/`) | MIT | `skills/_upstream/steipete-agent-scripts/skills/swiftui-performance-audit/` |
| `swift-security` | `dpearson2699/swift-ios-skills` @ `8d90fd1` (sparse: 12 skills, see below) | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/swift-security/` |
| `authentication` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/authentication/` |
| `ios-networking` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/ios-networking/` |
| `ios-accessibility` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/ios-accessibility/` |
| `push-notifications` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/push-notifications/` |
| `activitykit` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/activitykit/` |
| `swiftdata` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/swiftdata/` |
| `swiftui-animation` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/swiftui-animation/` |
| `swiftui-gestures` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/swiftui-gestures/` |
| `ios-simulator` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/ios-simulator/` |
| `debugging-instruments` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/debugging-instruments/` |
| `swiftlint` | `dpearson2699/swift-ios-skills` @ `8d90fd1` | PolyForm Perimeter 1.0.0 | `skills/_upstream/dpearson-swift-ios-skills/skills/swiftlint/` |

Base path for global locations: `~/.config/opencode/`.

## Licence notes

- MIT skills: free to use, update via `git pull` in their directories.
- `dpearson2699/swift-ios-skills` is **PolyForm Perimeter 1.0.0**
  (source-available, not OSI-open; includes a noncompete clause and a required
  copyright notice). Installed globally for local agent use only — **never
  copy these files into this repository** (that would be redistribution).
- `openai/plugins` (`plugins/build-ios-apps/skills/swiftui-performance-audit`)
  was **not installed**: the repo carries no licence grant. The MIT-licensed
  steipete copy above covers the same need; per policy, use the narrowest
  applicable skill and do not invoke both.
