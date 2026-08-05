#!/usr/bin/env python3
"""
Checks Shared/SeedNames.swift parses as a Swift array.

Merging three arrays into one dropped two separators, and each cost a full CI
round trip to find because Swift reads `"a"\n"b"` as one concatenated string
rather than an error at the obvious place. This catches it locally in
milliseconds.
"""
import pathlib, re, sys

path = pathlib.Path("Shared/SeedNames.swift")
lines = path.read_text(encoding="utf-8").splitlines()

problems = []
for i, line in enumerate(lines):
    if not re.search(r'"[a-z0-9][a-z0-9-]*"', line):
        continue
    code = line.split("//")[0].rstrip()
    following = next((l for l in lines[i + 1:] if l.strip()), "")
    if not code.endswith(",") and not following.strip().startswith("]"):
        problems.append(f"  line {i + 1}: missing ',' after {line.strip()}")

names = re.findall(r'"([a-z0-9][a-z0-9-]*)"', path.read_text(encoding="utf-8"))
dupes = {n for n in names if names.count(n) > 1 and names.count(n) != 2}

if problems:
    print("SeedNames.swift has separator problems:")
    print("\n".join(problems))
    sys.exit(1)

print(f"SeedNames.swift OK — {len(set(names))} unique seeds")
