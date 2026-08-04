# CI costs

macOS runners bill at **10× the normal rate**. The previous project burned ~2,900
of 3,000 monthly minutes and 71% of that was the screenshot job, because it ran
on every push alongside the build.

## Rules

1. **Nothing runs on push.** Both workflows are `workflow_dispatch` only.
2. **Screens defaults to one device and the smoke seed set.** All three devices
   only when we're specifically checking layout.
3. **Estimate before anything unusual**, and flag it when the spend climbs.

## Rough cost per run

Billed minutes = wall-clock × 10.

| Run | Wall clock | Billed | % of 3,000 |
|---|---|---|---|
| Build, no tests | ~5–7 min | 50–70 | ~2% |
| Build + tests | ~6–8 min | 60–80 | ~2.5% |
| Screens, one device, smoke (7 seeds) | ~7–9 min | 70–90 | ~3% |
| Screens, one device, all (~26 seeds) | ~10–13 min | 100–130 | ~4% |
| Screens, three devices, all | ~17–23 min | 170–230 | ~6–8% |

Roughly a third of every run is fixed overhead — image boot, `brew install
xcodegen`, SPM resolution, the first compile. Adding seeds is cheap (about 3
seconds each); adding *devices* is expensive, because each one re-boots a
simulator and re-installs.

## Devices

Three shapes that genuinely differ:

- **iPhone 17 Pro Max** — largest.
- **iPhone 16e** — smallest current.
- **iPhone 17** — the plain flagship: Dynamic Island *and* a short screen. This
  is where overlays collide, so it's the single device used when `devices: one`.
