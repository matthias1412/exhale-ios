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
]

for what, swift_pattern, python_pattern in checks:
    a = find(swift, swift_pattern, what, "SpiralGeometry.swift")
    b = find(python, python_pattern, what, "make-app-icon.py")
    if a is None or b is None:
        continue
    if float(a) != float(b):
        problems.append(f"  {what}: Swift says {a}, the icon script says {b}")

# The dot diameter ramp has to match too, since it sets the weight of the mark.
swift_dia = re.search(r"diameter: \(([\d.]+) \+ ramp \* ([\d.]+)\) \* scale", swift)
python_dia = re.search(r"diameter = \(([\d.]+) \+ t \* ([\d.]+)\) \* scale", python)
if swift_dia and python_dia:
    if swift_dia.groups() != python_dia.groups():
        problems.append(
            f"  dot diameter ramp: Swift says {swift_dia.groups()}, "
            f"the icon script says {python_dia.groups()}"
        )
else:
    problems.append("  could not compare the dot diameter ramp")

if problems:
    print("The app icon and the in-app mark have drifted apart:")
    print("\n".join(problems))
    print("\nThey must be the same logo. Fix whichever is wrong, then re-run")
    print("  python tools/make-app-icon.py")
    sys.exit(1)

print("logo OK — icon and in-app mark share dot count, angle, radii and ramp")
