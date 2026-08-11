#!/usr/bin/env python3
"""Turn a downloaded screens artifact into one reviewable page.

The CI job produces artifacts/screens/<device>/<seed>.png at full simulator
resolution, which is a zip nobody opens. This flattens it into a single
self-contained HTML file grouped the way the app is actually experienced, so a
review is scrolling one page rather than clicking fifty files.

Images are downscaled and inlined as data URIs because the published page
cannot fetch anything external. That is also the size ceiling: full-resolution
PNGs base64 out to roughly 27 MB, and the limit is 16 MB.

    python tools/build-contact-sheet.py <dir-of-pngs> [out.html]
"""
import base64
import io
import pathlib
import sys
from PIL import Image

WIDTH = 620          # enough to read body copy; 52 of these stay under the cap
QUALITY = 82

# Order and grouping are editorial: this is the order a person meets the app,
# not alphabetical. Seeds not named here land in "Everything else" rather than
# being dropped, so a new seed can never go missing from a review.
GROUPS = [
    ("Onboarding", "All ten steps, in the order you meet them.", [
        "onboard-intro",
        "onboard-product", "onboard-product-selected",
        "onboard-amount-cigarettes", "onboard-amount-vape", "onboard-amount-pouches",
        "onboard-price-empty", "onboard-price-cigarettes", "onboard-price-vape",
        "onboard-price-yearly",
        "onboard-reason", "onboard-reason-chosen",
        "onboard-cravings",
        "onboard-slips",
        "onboard-quit-moment", "onboard-quit-time", "onboard-quit-date",
        "onboard-reminders",
        "onboard-ready", "onboard-ready-scheduled", "onboard-ready-backdated",
    ]),
    ("Paywall", "Including the states that are easy to forget.", [
        "paywall", "paywall-loading", "paywall-foreign-currency",
    ]),
    ("Starting states", "The three ways a run can begin, plus the one that waits.", [
        "pre-quit-countdown", "awaiting-start", "today-day1", "slip-backdated",
    ]),
    ("Today", "The spiral at every density it has to survive.", [
        "today-day14", "today-day90", "today-day365", "today-day1825",
        "today-day8", "today-vape", "today-imminent-milestone",
        "today-after-relapse",
    ]),
    ("Milestones", "The burst, mid-flight, and the list behind it.", [
        "milestone-celebration", "milestone-celebration-f20",
        "milestone-celebration-f45", "milestone-celebration-f70",
        "banner-milestone", "milestones-early", "milestones-late",
        "milestones-notifications-denied",
    ]),
    ("Craving", "The breath, through a full cycle.", [
        "sos-breathe-in", "sos-hold", "sos-let-go", "sos-with-reason",
    ]),
    ("The bill", "Money, at the sizes that break layouts.", [
        "bill-cigarettes", "bill-vape", "bill-tally-x10", "bill-long-money",
    ]),
    ("Slips and settings", "", ["slip-sheet", "settings"]),
    ("Debug", "Comes out before TestFlight.", ["debug-menu"]),
]


def encode(path):
    im = Image.open(path).convert("RGB")
    im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=QUALITY, optimize=True, progressive=True)
    return base64.b64encode(buf.getvalue()).decode(), im.height


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "artifacts/screens")
    out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "tools/preview/screens.html")

    shots = {}
    for png in sorted(root.rglob("*.png")):
        shots.setdefault(png.stem, png)
    if not shots:
        sys.exit(f"no PNGs under {root}")

    placed = {s for _, _, seeds in GROUPS for s in seeds}
    leftovers = sorted(set(shots) - placed)
    groups = list(GROUPS)
    if leftovers:
        groups.append(("Everything else", "Not yet grouped.", leftovers))

    cards, shown, total_bytes = [], 0, 0
    for title, blurb, seeds in groups:
        present = [s for s in seeds if s in shots]
        if not present:
            continue
        tiles = []
        for seed in present:
            b64, h = encode(shots[seed])
            total_bytes += len(b64)
            shown += 1
            tiles.append(
                f'<figure class="shot"><img loading="lazy" alt="{seed}" '
                f'src="data:image/jpeg;base64,{b64}">'
                f'<figcaption>{seed}</figcaption></figure>'
            )
        cards.append(
            f'<section><header><h2>{title}</h2>'
            f'<p>{blurb}</p><span class="count">{len(present)}</span></header>'
            f'<div class="grid">{"".join(tiles)}</div></section>'
        )

    missing = sorted(placed - set(shots))
    note = (f'<p class="missing"><b>Not captured:</b> {", ".join(missing)}</p>'
            if missing else "")

    html = TEMPLATE.replace("{{CARDS}}", "\n".join(cards)) \
                   .replace("{{NOTE}}", note) \
                   .replace("{{COUNT}}", str(shown))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"wrote {out}  {out.stat().st_size // 1024} KB  {shown} screens")
    if out.stat().st_size > 15_500_000:
        print("::warning::approaching the 16 MB artifact ceiling")


TEMPLATE = """<title>Exhale, every screen</title>
<style>
  :root{
    --bg:#F4F6F6; --panel:#FFFFFF; --ink:#0B1A1D; --muted:#5A6B6E;
    --hair:rgba(11,26,29,.10); --accent:#127C6B; --shot:#0A1012;
  }
  @media (prefers-color-scheme: dark){
    :root{ --bg:#080F11; --panel:#0E1719; --ink:#E9F5F3; --muted:#8FA5A6;
           --hair:rgba(233,245,243,.12); --accent:#7FD8CB; }
  }
  :root[data-theme="dark"]{
    --bg:#080F11; --panel:#0E1719; --ink:#E9F5F3; --muted:#8FA5A6;
    --hair:rgba(233,245,243,.12); --accent:#7FD8CB;
  }
  :root[data-theme="light"]{
    --bg:#F4F6F6; --panel:#FFFFFF; --ink:#0B1A1D; --muted:#5A6B6E;
    --hair:rgba(11,26,29,.10); --accent:#127C6B;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);
    font:15px/1.55 ui-sans-serif,-apple-system,"Segoe UI",system-ui,sans-serif;
    -webkit-font-smoothing:antialiased}
  .wrap{max-width:1400px;margin:0 auto;padding:40px 26px 90px}
  h1{font-size:28px;letter-spacing:-.5px;margin:0 0 6px;text-wrap:balance}
  .lede{color:var(--muted);margin:0 0 34px;max-width:62ch}
  .missing{color:var(--muted);font-size:13px;border-left:3px solid var(--accent);
    padding:8px 0 8px 12px;margin:0 0 30px}
  section{background:var(--panel);border:1px solid var(--hair);border-radius:16px;
    padding:22px;margin-bottom:22px}
  header{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap;
    padding-bottom:16px;margin-bottom:18px;border-bottom:1px solid var(--hair)}
  h2{font-size:17px;margin:0;letter-spacing:-.2px}
  header p{margin:0;color:var(--muted);font-size:13.5px;flex:1}
  .count{font-variant-numeric:tabular-nums;font-size:12px;color:var(--muted);
    border:1px solid var(--hair);border-radius:99px;padding:2px 9px}
  .grid{display:grid;gap:20px;
    grid-template-columns:repeat(auto-fill,minmax(180px,1fr))}
  figure{margin:0}
  .shot img{width:100%;display:block;border-radius:11px;background:var(--shot);
    border:1px solid var(--hair);cursor:zoom-in}
  figcaption{font:11.5px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;
    color:var(--muted);margin-top:7px;word-break:break-all}
  dialog{border:0;background:transparent;padding:0;max-width:100vw;max-height:100vh}
  dialog::backdrop{background:rgba(4,10,11,.86)}
  dialog img{max-height:92vh;border-radius:14px;display:block}
</style>
<div class="wrap">
  <h1>Exhale, every screen</h1>
  <p class="lede">{{COUNT}} states captured on one device, straight from the
  simulator. Click any screen to enlarge.</p>
  {{NOTE}}
  {{CARDS}}
</div>
<dialog id="zoom"><img id="zoomImg" alt=""></dialog>
<script>
  const dlg = document.getElementById('zoom'), big = document.getElementById('zoomImg');
  document.addEventListener('click', e => {
    if (e.target.matches('.shot img')) { big.src = e.target.src; dlg.showModal(); }
    else if (e.target === dlg || e.target === big) dlg.close();
  });
</script>
"""

if __name__ == "__main__":
    main()
