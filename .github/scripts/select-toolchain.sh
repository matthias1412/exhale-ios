#!/usr/bin/env bash
#
# Runner images change device names and Xcode versions without warning, and
# guessing them from a Windows machine burns a 10x-billed run per guess. So:
# discover what's actually installed, print it, and export the choices.
#
# Exports to $GITHUB_ENV:
#   SIM_ONE   — best single iPhone for cheap runs (plain flagship if present)
#   SIM_ALL   — newline-separated: largest Pro Max, smallest, plain flagship
set -euo pipefail

echo "::group::Available Xcode versions"
ls -d /Applications/Xcode*.app 2>/dev/null || echo "none found"
echo "::endgroup::"

# Newest Xcode by version sort, not by a hardcoded name.
XCODE="$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -1)"
if [[ -z "$XCODE" ]]; then
  echo "::error::no Xcode found on this runner"
  exit 1
fi
echo "Selecting $XCODE"
sudo xcode-select -s "$XCODE"
xcodebuild -version

echo "::group::Installed simulator runtimes"
xcrun simctl list runtimes
echo "::endgroup::"

echo "::group::Available iPhone simulators"
xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' || true
echo "::endgroup::"

# All available iPhone device names, deduped, newest model numbers last.
# NOTE: macOS ships bash 3.2 as /bin/bash — no `mapfile`, no negative array
# indices. Everything here must stay 3.2-compatible.
IPHONES=()
while IFS= read -r name; do
  [ -n "$name" ] && IPHONES+=("$name")
done < <(
  xcrun simctl list devices available \
    | grep -oE '^[[:space:]]+iPhone [^(]+' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | sort -u -V
)

if [[ ${#IPHONES[@]} -eq 0 ]]; then
  echo "::error::no iPhone simulators available"
  exit 1
fi

pick_matching() {
  # First arg is a regex; echoes the newest match, or nothing.
  local pattern="$1" match=""
  for name in "${IPHONES[@]}"; do
    if [[ "$name" =~ $pattern ]]; then match="$name"; fi
  done
  echo "$match"
}

PRO_MAX="$(pick_matching 'Pro Max')"
# The plain flagship: "iPhone <n>" with no Pro/Plus/mini/e suffix. Short screen
# *and* a Dynamic Island, which is where overlays collide.
FLAGSHIP="$(pick_matching '^iPhone [0-9]+$')"
# Smallest current: an "e" model, else a mini, else the plain flagship.
SMALLEST="$(pick_matching '^iPhone [0-9]+e$')"
[[ -n "$SMALLEST" ]] || SMALLEST="$(pick_matching 'mini')"

# Fall back to the newest available iPhone for anything we couldn't identify.
NEWEST="${IPHONES[${#IPHONES[@]}-1]}"
[[ -n "$FLAGSHIP" ]] || FLAGSHIP="$NEWEST"
[[ -n "$PRO_MAX" ]]  || PRO_MAX="$NEWEST"
[[ -n "$SMALLEST" ]] || SMALLEST="$NEWEST"

echo "Chosen — flagship: $FLAGSHIP | pro max: $PRO_MAX | smallest: $SMALLEST"

{
  echo "SIM_ONE=$FLAGSHIP"
  echo "SIM_ALL<<__EOF__"
  printf '%s\n' "$PRO_MAX" "$SMALLEST" "$FLAGSHIP" | awk '!seen[$0]++'
  echo "__EOF__"
} >> "${GITHUB_ENV:-/dev/stdout}"
