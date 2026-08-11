#!/usr/bin/env python3
"""Approved onboarding copy must exist in the app, not only in the preview.

Twice now, wording that was reviewed and signed off changed in the HTML
preview and never reached the Swift. The app kept saying "Why now?" and "we'll
hand the first one back to you when it's hard" for days after both were
replaced, and nothing anywhere failed, because a preview and an app have no
reason to agree unless something makes them.

This makes them. Every line in tools/onboarding-copy.json must appear verbatim
in the Swift view that owns it *and* in the generated preview. Drift in either
direction is an error, so the two cannot separate again without the build
saying so.

The same trick as lint-notifications.py, applied to the flow the user actually
spent the most time reviewing.
"""
import html as htmllib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "tools" / "onboarding-copy.json"
PREVIEW = ROOT / "tools" / "preview" / "onboarding-v2.html"


def normalise(text, strip_tags=False):
    """Collapse whitespace and unify apostrophes.

    The preview wraps prose across source lines for readability and the Swift
    holds it on one; both are the same sentence to a reader, so neither should
    count as drift.

    Preview markup is stripped rather than matched around, because an emphasis
    tag lands in the middle of a sentence ("is <b>behind you</b>") and would
    otherwise read as drift when nothing has drifted.
    """
    if strip_tags:
        # A space, not nothing: "one<br>is" must not become "oneis".
        text = re.sub(r"<[^>]+>", " ", text)
        text = htmllib.unescape(text)
        # The preview stores each variant inside a JavaScript string for its
        # switcher, so line breaks reach the file as a literal backslash-n
        # rather than a newline and survive a plain whitespace collapse.
        text = text.replace(r"\n", " ").replace(r"\"", '"').replace(r"\'", "'")
    text = text.replace("’", "'").replace("“", '"').replace("”", '"')
    return re.sub(r"\s+", " ", text).strip()


def main():
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    preview = (normalise(PREVIEW.read_text(encoding="utf-8"), strip_tags=True)
               if PREVIEW.exists() else "")
    if not preview:
        sys.exit(f"{PREVIEW} missing — run tools/build-onboarding-preview.py first")

    cache, problems, checked = {}, [], 0
    for screen in spec["screens"]:
        path = ROOT / screen["swift"]
        if path not in cache:
            if not path.exists():
                problems.append(f"{screen['step']}: {screen['swift']} does not exist")
                cache[path] = ""
            else:
                cache[path] = normalise(path.read_text(encoding="utf-8"))
        swift = cache[path]

        for line in screen["lines"]:
            checked += 1
            want = normalise(line)
            if want not in swift:
                problems.append(
                    f"{screen['step']}: not in {screen['swift']}\n      {line}")
            if want not in preview:
                problems.append(
                    f"{screen['step']}: approved but not in the preview\n      {line}")

    if problems:
        print("Onboarding copy has drifted from what was approved:")
        for p in problems:
            print(f"  - {p}")
        print("\nFix the source, or update tools/onboarding-copy.json if the")
        print("wording genuinely changed — but change all three together.")
        sys.exit(1)

    print(f"onboarding copy OK - {checked} approved lines in both the app and the preview")


if __name__ == "__main__":
    main()
