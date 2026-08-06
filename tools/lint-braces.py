#!/usr/bin/env python3
"""
Checks every Swift file's braces balance.

Twice now a scripted edit has spliced a method into the middle of another one,
leaving a body unclosed. Both times the compiler caught it — after a ten-minute
macOS run at 10x billing, reporting something unhelpful like "attribute
'private' can only be used in a non-local scope", which points at the symptom
rather than the missing brace. This catches it in milliseconds.

Deliberately crude: it tracks strings and comments well enough not to produce
false alarms, and says nothing about whether the code is correct — only that
every block someone opened was closed.
"""
import pathlib
import sys

NORMAL, LINE_COMMENT, BLOCK_COMMENT, STRING, MULTILINE_STRING = range(5)


def imbalance(source: str):
    """Returns (depth, line_of_first_unmatched_close) — depth 0 means balanced."""
    state = NORMAL
    depth = 0
    block_depth = 0
    stray_close = None
    i, line = 0, 1
    n = len(source)

    while i < n:
        c = source[i]
        nxt = source[i + 1] if i + 1 < n else ""
        if c == "\n":
            line += 1
            if state == LINE_COMMENT:
                state = NORMAL
            i += 1
            continue

        if state == NORMAL:
            if c == "/" and nxt == "/":
                state = LINE_COMMENT; i += 2; continue
            if c == "/" and nxt == "*":
                state = BLOCK_COMMENT; block_depth = 1; i += 2; continue
            if source.startswith('"""', i):
                state = MULTILINE_STRING; i += 3; continue
            if c == '"':
                state = STRING; i += 1; continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth < 0 and stray_close is None:
                    stray_close = line
        elif state == LINE_COMMENT:
            pass
        elif state == BLOCK_COMMENT:
            if c == "/" and nxt == "*":
                block_depth += 1; i += 2; continue
            if c == "*" and nxt == "/":
                block_depth -= 1; i += 2
                if block_depth == 0:
                    state = NORMAL
                continue
        elif state == STRING:
            if c == "\\":
                i += 2; continue
            if c == '"':
                state = NORMAL
        elif state == MULTILINE_STRING:
            if c == "\\":
                i += 2; continue
            if source.startswith('"""', i):
                state = NORMAL; i += 3; continue
        i += 1

    return depth, stray_close


problems = []
checked = 0
for path in sorted(pathlib.Path(".").rglob("*.swift")):
    if any(part in {"build", ".build", "artifacts", "DerivedData"} for part in path.parts):
        continue
    checked += 1
    depth, stray = imbalance(path.read_text(encoding="utf-8"))
    if depth > 0:
        problems.append(f"  {path}: {depth} unclosed '{{' — a body was left open")
    elif depth < 0:
        problems.append(f"  {path}: {-depth} extra '}}' (first unmatched near line {stray})")

if problems:
    print("Swift files with unbalanced braces:")
    print("\n".join(problems))
    sys.exit(1)

print(f"braces OK — {checked} Swift files balanced")
