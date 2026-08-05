#!/usr/bin/env python3
"""
Builds the App Store screenshot rail from real simulator captures.

    python tools/make-store-screenshots.py

Reads captures from artifacts/ (whatever the Screens workflow last produced),
composes each into a drawn device frame on a 1284 x 2778 artboard — the only
size App Store Connect accepts for the 6.5" slot — and asserts the output
dimensions rather than trusting them.

Composed with Pillow rather than headless Chrome so the result is deterministic
and checkable in the same script that makes it. The real bundled fonts are used,
so the captions match the app.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

# The 6.5" slot. App Store Connect rejects anything else for this size class.
CANVAS = (1284, 2778)

FONTS = pathlib.Path("Exhale/Resources/Fonts")
DARK, CREAM = (0x0C, 0x22, 0x25), (0xF4, 0xEF, 0xE4)
SEA_GLASS, INK = (0xBD, 0xED, 0xE4), (0x1A, 0x17, 0x14)

# Captions do the selling — most people never read the description.
SHOTS = [
    ("today-day90",       "90 days becomes\nsomething you can see.", DARK,  SEA_GLASS),
    ("bill-cigarettes",   "Every cent it owed you,\nitemised.",       CREAM, INK),
    ("milestones-early",  "Your body heals on a schedule.\nWe'll tell you when.", DARK, SEA_GLASS),
    ("sos-breathe-in",    "A craving lasts 3 minutes.\nOutlast it.",  DARK,  SEA_GLASS),
    # The unselected picker shows a greyed-out Continue, which reads as broken
    # UI in a store listing. Use the state with a choice already made.
    ("onboard-product-selected", "Cigarettes, vape or pouches —\nbuilt for all three.", CREAM, INK),
]


def find_capture(name: str) -> pathlib.Path:
    hits = sorted(pathlib.Path("artifacts").rglob(f"{name}.png"))
    if not hits:
        sys.exit(f"missing capture: {name}.png — run the Screens workflow first")
    return hits[0]


def rounded_mask(size, radius):
    mask = Image.new("L", (size[0] * 4, size[1] * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size[0] * 4 - 1, size[1] * 4 - 1], radius=radius * 4, fill=255
    )
    return mask.resize(size, Image.LANCZOS)


def compose(name, caption, bg, fg):
    canvas = Image.new("RGB", CANVAS, bg)
    draw = ImageDraw.Draw(canvas)

    title = ImageFont.truetype(str(FONTS / "SpaceGrotesk-Bold.ttf"), 64)

    y = 132
    for line in caption.split("\n"):
        w = draw.textbbox((0, 0), line, font=title)[2]
        draw.text(((CANVAS[0] - w) / 2, y), line, font=title, fill=fg)
        y += 84

    # Device frame. The screen runs off the bottom edge, as in the design —
    # it reads as a phone in the hand rather than a boxed-in rectangle.
    shot = Image.open(find_capture(name)).convert("RGB")
    bezel = 12
    radius = 58
    frame_y = y + 96

    # Size the screen so its bottom lands exactly on the canvas edge. Chosen by
    # arithmetic rather than by eye: at a fixed width the screen stopped 208px
    # short, leaving a band of bezel colour that read as a bug.
    screen_h = CANVAS[1] - frame_y - bezel
    screen_w = round(shot.width * screen_h / shot.height)
    shot = shot.resize((screen_w, screen_h), Image.LANCZOS)
    frame_x = (CANVAS[0] - screen_w) // 2 - bezel

    draw.rounded_rectangle(
        [frame_x, frame_y, frame_x + screen_w + bezel * 2, CANVAS[1] + radius],
        radius=radius + bezel, fill=(0x05, 0x29, 0x2C),
    )
    canvas.paste(shot, (frame_x + bezel, frame_y + bezel),
                 rounded_mask((screen_w, screen_h), radius))
    return canvas


def main():
    out = pathlib.Path("artifacts/store")
    out.mkdir(parents=True, exist_ok=True)

    for index, (name, caption, bg, fg) in enumerate(SHOTS, start=1):
        image = compose(name, caption, bg, fg)
        path = out / f"{index}-{name}.png"
        image.save(path, "PNG")

        # Check, don't assume. App Store Connect silently refuses the wrong size.
        check = Image.open(path)
        assert check.size == CANVAS, f"{path} is {check.size}, must be {CANVAS}"
        assert check.mode == "RGB", f"{path} has an alpha channel"
        print(f"  {path}  {check.size[0]}x{check.size[1]}  "
              f"{path.stat().st_size // 1024} KB")

    print(f"\n{len(SHOTS)} screenshots, all {CANVAS[0]}x{CANVAS[1]}, no alpha")


if __name__ == "__main__":
    main()
