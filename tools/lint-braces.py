#!/usr/bin/env python3
"""
Structural checks on Swift sources that the compiler only reports after a
ten-minute macOS run at 10x billing.

Two failures, both caused by scripted edits, both of which shipped a red build:

  * a method spliced in ahead of a body's closing brace, so `body` never
    closed. The compiler said "attribute 'private' can only be used in a
    non-local scope", which points three lines away from the real problem.
  * a helper inserted twice, giving "invalid redeclaration".

Neither needs a compiler to find. Both are caught here in milliseconds.

Deliberately crude: it tracks strings and comments well enough not to cry
wolf, and says nothing about whether the code is correct — only that every
block someone opened was closed, and that nothing was declared twice inside
the same type.
"""
import pathlib
import re
import sys

NORMAL, LINE_COMMENT, BLOCK_COMMENT, STRING, MULTILINE_STRING = range(5)

TYPE_RE = re.compile(
    r"\b(?:struct|class|enum|actor|protocol|extension)\s+([A-Za-z_]\w*)"
)
FUNC_RE = re.compile(r"\bfunc\s+([A-Za-z_]\w*)\s*\(([^)]*)\)")


def imbalance(source: str):
    """Returns (depth, line_of_first_unmatched_close). Depth 0 means balanced."""
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


def duplicate_declarations(source: str):
    """Function signatures declared twice inside the same type.

    Scoped by enclosing type, because the same signature legitimately appears
    in a protocol and again in every type conforming to it, and a test helper
    of the same name may live in several test classes. An unscoped version of
    this check reported six such false alarms on the first run.

    Signature means name plus argument labels, which is what Swift overloads
    on, so genuine overloads are not flagged.
    """
    seen, dupes = {}, []
    scope = []            # (type name, brace depth it opened at)
    depth = 0

    for number, raw in enumerate(source.splitlines(), 1):
        code = raw.split("//")[0]

        func_match = FUNC_RE.search(code)
        type_match = TYPE_RE.search(code)

        if func_match:
            labels = ":".join(
                part.strip().split(":")[0].split()[0]
                for part in func_match.group(2).split(",")
                if part.strip()
            )
            path = ".".join(name for name, _ in scope)
            key = f"{path}|{func_match.group(1)}({labels})"
            if key in seen:
                dupes.append((key.split("|", 1)[1], seen[key], number))
            else:
                seen[key] = number
        elif type_match:
            scope.append((type_match.group(1), depth))

        depth += code.count("{") - code.count("}")
        while scope and depth <= scope[-1][1]:
            scope.pop()

    return dupes


problems = []
checked = 0
for path in sorted(pathlib.Path(".").rglob("*.swift")):
    if any(part in {"build", ".build", "artifacts", "DerivedData"} for part in path.parts):
        continue
    checked += 1
    source = path.read_text(encoding="utf-8")

    for signature, first, again in duplicate_declarations(source):
        problems.append(
            f"  {path}: {signature} declared at line {first} and again at {again}"
        )

    depth, stray = imbalance(source)
    if depth > 0:
        problems.append(f"  {path}: {depth} unclosed '{{' — a body was left open")
    elif depth < 0:
        problems.append(f"  {path}: {-depth} extra '}}' (first unmatched near line {stray})")

if problems:
    print("Swift files with structural problems:")
    print("\n".join(problems))
    sys.exit(1)

print(f"structure OK — {checked} Swift files balanced, no duplicate declarations")
