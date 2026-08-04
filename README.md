# Exhale — quit nicotine

A native SwiftUI iPhone app for quitting cigarettes, vaping or nicotine pouches.
One dot per smoke-free day, arranged as a phyllotaxis spiral; a running receipt
for the money nicotine owed you.

Local-only: no backend, no accounts, no analytics.

## Working without a Mac

The `.xcodeproj` is **generated, never committed** — XcodeGen builds it from
[`project.yml`](project.yml) in CI. That's what makes Mac-less development work.
Everything ships through GitHub Actions.

Both workflows are **`workflow_dispatch` only**. Nothing runs on push, because
macOS runners bill at 10×. See [docs/ci-costs.md](docs/ci-costs.md).

| Workflow | What it does |
|---|---|
| **Build** | XcodeGen → build for simulator → unit tests. Optionally signs and ships to TestFlight. |
| **Screens** | Boots simulators, launches the app once per seed, screenshots each state, uploads them as an artifact. |

## The screenshot harness

The rule: **never claim a screen works until you've looked at a picture of it.**

Every screen *and state* is reachable directly via a launch argument, so nothing
has to be tapped through:

```bash
xcrun simctl launch booted com.matthias.exhale -seed today-day90
```

Seeds live in [`Shared/SeedNames.swift`](Shared/SeedNames.swift) — a single
source of truth that both the app and `capture.sh` read. Multi-step overlays get
one seed per step: `sos-breathe-in`, `sos-hold`, `sos-let-go` are three separate
captures, because a bug once hid in step 2 of a three-step flow that only ever
had step 1 photographed.

Seeded runs freeze the clock at 15 June 2026, 09:41, and the workflow pins the
status bar with `simctl status_bar override`, so captures are identical run to
run and usable as store assets.

## Layout

```
Exhale/
  App/        entry point, model, persistence, seeds
  Domain/     product config, quit plan, progress, milestones, currency
  Design/     spiral maths, palette, typography
  Views/      screens
Shared/       seed names — compiled into the app, read by CI
ExhaleTests/  economics and geometry
tools/preview/ HTML reference renders of the spiral maths
docs/         decisions, CI costs
```

## State

Four stored facts — product, amount, unit price, quit date. Everything else is
derived on the fly. Elapsed time always comes from the stored `Date`, never from
accumulated timers, so timezone changes and DST can't corrupt a streak.

Persisted as one `Codable` blob in Application Support.

## Status

Scaffold and harness first, features after — verification exists before there's
anything to verify.

- [x] Project, CI, screenshot harness
- [x] Spiral geometry + logo mark, unit-tested
- [x] Domain model + economics, unit-tested
- [x] Fonts bundled and verified — a wrong name now fails the build
- [x] Today
- [x] The Bill
- [x] Milestones
- [x] Settings
- [x] Local notification scheduling
- [x] Craving SOS
- [x] Onboarding step 1 (product picker)
- [x] Onboarding steps 2–4 (amount, price, quit moment with backdating)
- [x] Paywall behind `SubscriptionGate`
- [x] Debug menu (time-travel presets)
- [x] App icon
- [ ] RevenueCat products — needs the dashboard set up, see
      [docs/testflight-setup.md](docs/testflight-setup.md)
- [ ] TestFlight — needs your Apple Developer account, same doc
- [ ] Marketing screenshots at 1284 × 2778
- [ ] App Store listing

34 unit tests green. All 32 states captured on three iPhones — largest Pro Max,
smallest current, and the plain flagship — and reviewed.

Deliberate deviations from the design handoff, with reasons, are in
[docs/decisions.md](docs/decisions.md).
