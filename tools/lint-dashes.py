#!/usr/bin/env python3
"""
No em dashes in anything the user reads.

They are a house-style decision, and they are also the single most reliable
tell that a sentence was not written by a person. Doc comments and code
comments are exempt: they are notes to whoever maintains this, not product
voice, and several of them quote retired copy as a counterexample.

Checks Swift string literals and the copy in the preview builders. A hyphen
substituted for an em dash usually reads worse than either, so this only
reports; the fix is a sentence decision every time.
"""
import pathlib
import re
import sys

DASH = "\u2014"
problems = []

for path in sorted(pathlib.Path("Exhale").rglob("*.swift")):
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("//"):
            continue
        for literal in re.findall(r'"([^"\n]*)"', line):
            if DASH in literal:
                problems.append(f"  {path}:{number}  {literal.strip()[:80]}")

for path in sorted(pathlib.Path("tools").glob("build-*-preview.py")):
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        if DASH in line:
            problems.append(f"  {path}:{number}  {line.strip()[:80]}")

if problems:
    print("Em dashes in user-facing copy:")
    print("\n".join(problems))
    print("\nRewrite the sentence rather than swapping the character.")
    sys.exit(1)

print("dashes OK — no em dashes in user-facing copy")
