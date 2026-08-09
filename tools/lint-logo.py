#!/usr/bin/env python3
"""
Checks the app icon is generated from the same numbers as the in-app mark.

These drifted apart once: LogoGeometry was changed to thin the mark out at
small sizes, make-app-icon.py was not, and the icon on the home screen became
visibly a different logo from the one in the header. Nothing failed — both
halves were individually correct — so it survived until someone looked at the
two side by side.
"""
import pathlib, re, sys

swift = pathlib.Path("Exhale/Design/SpiralGeometry.swift").read_text(encoding="utf-8")
python = pathlib.Path("tools/make-app-icon.py").read_text(encoding="utf-8")

problems = []


def find(source, pattern, what, where):
    match = re.search(pattern, source, re.M)
    if not match:
        problems.append(f"  could not find {what} in {where}")
        return None
    return match.group(1)


# The mark is defined by four numbers plus the golden angle. If any pair
# disagrees, the two renderings are different marks.
checks = [
    ("dot count", r"static let dotCount\s*=\s*(\d+)", r"^DOTS\s*=\s*(\d+)"),
    ("golden angle", r"goldenAngle\s*(?:=|:\s*Double\s*=)\s*([\d.]+)", r"^GOLDEN\s*=\s*([\d.]+)"),
    ("hole radius", r"let hole = ([\d.]+) \* scale", r"hole = ([\d.]+) \* scale"),
    ("max radius", r"let maxR = ([\d.]+) \* scale", r"max_r = ([\d.]+) \* scale"),
    ("dot diameter",
     r"static let dotDiameter: Double = ([\d.]+)",
     r"^DOT_DIAMETER\s*=\s*([\d.]+)"),
]

for what, swift_pattern, python_pattern in checks:
    a = find(swift, swift_pattern, what, "SpiralGeometry.swift")
    b = find(python, python_pattern, what, "make-app-icon.py")
    if a is None or b is None:
        continue
    if float(a) != float(b):
        problems.append(f"  {what}: Swift says {a}, the icon script says {b}")

# The icon must not scale dots on top of the shared diameter. This is the line
# that actually broke the mark: DOT_SCALE sat at 1.35 to keep the icon weighty
# when downsampled, and combined with dots that grew outward it pushed 26 of
# them into genuine overlap on the home screen. The rim fused into a solid ring
# and the spiral arms — the only thing that makes it read as a bloom — vanished.
scale_match = re.search(r"^DOT_SCALE\s*=\s*([\d.]+)", python, re.M)
if scale_match is None:
    problems.append("  could not find DOT_SCALE in make-app-icon.py")
elif float(scale_match.group(1)) != 1.0:
    problems.append(
        f"  DOT_SCALE is {scale_match.group(1)}, not 1.0 — the icon would fatten every "
        f"dot and the rim would overlap again"
    )

# Nothing may reintroduce a diameter that varies with radius, for the same
# reason: spacing is even, so a growing dot is a shrinking gap.
if re.search(r"diameter:.*ramp\s*\*", swift):
    problems.append("  SpiralGeometry's dot diameter varies with radius again")
if re.search(r"diameter\s*=.*\bt\s*\*", python):
    problems.append("  the icon script's dot diameter varies with radius again")

if problems:
    print("The app icon and the in-app mark have drifted apart:")
    print("\n".join(problems))
    print("\nThey must be the same logo. Fix whichever is wrong, then re-run")
    print("  python tools/make-app-icon.py")
    sys.exit(1)

print("logo OK — icon and in-app mark share count, angle, radii and an even dot")
