# Decisions

Choices that aren't obvious from the code, and why they were made. Anything
here that contradicts the original handoff is a deliberate deviation with a
stated reason.

## Deviations from the handoff

### The spiral blooms over the first 90 days

**Handoff said:** place every dot with `r = holeR + span * √(i/(n-1))`.

**Problem:** that stretches the dots across the whole annulus regardless of how
many there are. Rendered, day 1 is a single dot stranded at the rim and days
7–30 are scattered confetti — no legible spiral until roughly day 60. The
signature visual doesn't exist during the stretch where someone quitting is
most fragile and most likely to open the app.

**Now:** the radius band opens outward over the first 90 days — inner edge
92 → 44pt, outer edge 92 → 145pt, centre veil scaling with it so early dots are
never swallowed by the numeral. **From day 90 the output is bit-identical to the
handoff**, so no later screen and no store asset is affected.

Verified by `SpiralGeometryTests.testBloomIsCompleteByDayNinety` and
`testEarlyDotsAreVisibleAndClearOfTheCentreLabel`. Rendered comparison of all
five candidate treatments is in `tools/preview/spiral-options.html`.

### No exchange rates anywhere

**Handoff had:** a table of multipliers against EUR (`USD: 1.1`, `JPY: 170`, …)
used for both the user's product price and the subscription price.

**Problem:** hardcoded currency conversion shows the wrong price to most of the
world, and it goes stale silently.

**Now:** subscription prices come from the store, already localised — nothing in
the app computes them. The user's own pack/pod/tin price is entered by the user;
all the app supplies is a per-currency *starting position* for the stepper
(typical retail prices, not conversions), which they adjust on the next tap.
Symbol and placement come from the system formatter, not a hand table.

### Calendar days, not rolling 24-hour periods

Day 2 begins at local midnight, so the streak reads the way people talk about
it and notifications land at sane hours. **Everything else** — the money
counter, units avoided, milestone timing — runs from the exact quit instant,
because money should tick smoothly and the body doesn't heal on calendar
boundaries. Both clocks are exercised in `EconomicsTests`.

### Quit moment offers three paths

The handoff's step 4 had two buttons that did the same thing and recorded no
date at all. Now: *just had it* (now), *earlier today* (time picker), and *pick
a date* for people who already quit days or weeks ago — so someone at day 40
isn't forced to restart at 1.

### RevenueCat, not StoreKit 2 directly

The Exhale brief specified StoreKit 2; Matthias already runs RevenueCat across
his other apps and that wins. Kept behind a `SubscriptionGate` protocol so it's
mockable and so screenshot seeds never touch the network.

**Consequence to watch:** the app otherwise collects nothing, and "privacy-first"
is a selling point. RevenueCat adds a third-party SDK and a data-collection
entry on the App Store privacy label. Worth wording the listing carefully.

## Still open

- **Colour ramp is relative, not absolute.** `t = i/(n-1)`, so every dot
  repaints as the streak grows — a given day has no fixed colour. Kept as
  specced because absolute-age colour renders the whole first year uniformly
  sea-glass and strips the ember out of the day-90 App Store hero shot. Row E in
  `tools/preview/spiral-options.html` shows the alternative.
- **Health-milestone copy makes medical claims** ("stroke risk has fallen back
  to that of a non-smoker", 11 minutes of life per cigarette). Descriptive and
  drawn from published cessation timelines, but unreviewed. Affects App Store
  review too.
- **Fonts aren't bundled yet.** `Font.spaceGrotesk` / `.archivo` /
  `.archivoBlack` resolve to the system face until the files land in
  `Exhale/Resources/Fonts` and `UIAppFonts` is added to `Info.plist`. All three
  are SIL Open Font License.
- **The 10-year cap.** The spiral stops adding dots at 3,650. Nothing after
  that ever changes.
