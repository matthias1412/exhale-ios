#!/usr/bin/env python3
"""
Checks the notification preview still says what the app says.

tools/build-notifications-preview.py mirrors NotificationCopy.swift by hand so
the whole first month can be read on one page. A mirror that drifts is worse
than no mirror: it invites a copy decision made against wording the user will
never receive. Every sentence in the Swift must appear verbatim in the builder.
"""
import pathlib
import re
import sys

swift = pathlib.Path("Exhale/Domain/NotificationCopy.swift").read_text(encoding="utf-8")
builder = pathlib.Path("tools/build-notifications-preview.py").read_text(encoding="utf-8")

# Strip doc comments — they discuss old wording on purpose, and quoting a
# retired line as an example must not require it to exist in the preview.
code = "\n".join(
    line for line in swift.splitlines()
    if not line.lstrip().startswith("///")
)

# Sentences the user actually sees: long string literals, minus interpolations.
sentences = set()
for raw in re.findall(r'"([^"\n]{16,})"', code):
    if "\\(" in raw:
        # keep only the fixed fragments around the interpolation
        for part in re.split(r"\\\([^)]*\)", raw):
            part = part.strip()
            if len(part) >= 16:
                sentences.add(part)
    else:
        sentences.add(raw.strip())

missing = sorted(s for s in sentences if s not in builder)

if missing:
    print("The notification preview has drifted from the app:")
    for m in missing:
        print(f"  not in the preview: {m}")
    print("\nUpdate tools/build-notifications-preview.py, then re-run it.")
    sys.exit(1)

print(f"notifications OK — {len(sentences)} lines mirrored in the preview")
