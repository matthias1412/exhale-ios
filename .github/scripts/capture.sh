#!/usr/bin/env bash
#
# Boots simulators, launches Exhale once per seed, screenshots each one.
#
# The seed list is extracted from Shared/SeedNames.swift so there is exactly one
# source of truth — adding a seed in Swift adds it here automatically. (Which is
# why that file must contain no unrelated string literals.)
set -euo pipefail

BUNDLE_ID="com.matthias.exhale"
APP_PATH="$(find build/Build/Products -maxdepth 3 -name 'Exhale.app' | head -1)"
OUT_ROOT="artifacts/screens"

if [[ -z "$APP_PATH" ]]; then
  echo "::error::Exhale.app not found under build/Build/Products"
  exit 1
fi
echo "Using app at $APP_PATH"

# --- devices ---------------------------------------------------------------
# Names come from select-toolchain.sh, which reads them off the runner rather
# than trusting a hardcoded list. Three shapes that actually differ: the largest
# Pro Max, the smallest current phone, and the plain flagship — short screen
# *and* a Dynamic Island, which is where overlays collide.
DEVICES=()
if [[ "${DEVICE_SET:-one}" == "all" ]]; then
  while IFS= read -r name; do
    [ -n "${name// /}" ] && DEVICES+=("$name")
  done <<< "${SIM_ALL:?select-toolchain.sh did not run}"
else
  DEVICES=("${SIM_ONE:?select-toolchain.sh did not run}")
fi

# --- seeds -----------------------------------------------------------------
extract_seeds() {
  grep -oE '"[a-z0-9][a-z0-9-]*"' Shared/SeedNames.swift | tr -d '"' | sort -u
}
SEEDS=()
if [[ "${SEED_SET:-smoke}" == "all" ]]; then
  while IFS= read -r seed; do
    [ -n "$seed" ] && SEEDS+=("$seed")
  done < <(extract_seeds)
else
  while IFS= read -r seed; do
    [ -n "$seed" ] && SEEDS+=("$seed")
  done < <(
    sed -n '/static let smoke/,/\]/p' Shared/SeedNames.swift \
      | grep -oE '"[a-z0-9][a-z0-9-]*"' | tr -d '"'
  )
fi

if [[ ${#SEEDS[@]} -eq 0 ]]; then
  echo "::error::extracted no seed names from Shared/SeedNames.swift"
  exit 1
fi
echo "Capturing ${#SEEDS[@]} seeds on ${#DEVICES[@]} device(s)"

mkdir -p "$OUT_ROOT"

for DEVICE in "${DEVICES[@]}"; do
  echo "::group::$DEVICE"
  SAFE_NAME="${DEVICE// /-}"
  OUT_DIR="$OUT_ROOT/$SAFE_NAME"
  mkdir -p "$OUT_DIR"

  UDID="$(xcrun simctl list devices available \
        | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
  if [[ -z "$UDID" ]]; then
    echo "::warning::$DEVICE not available on this runner image, skipping"
    echo "::endgroup::"
    continue
  fi

  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b

  # Identical status bar every run, so captures are diffable and usable as
  # store assets.
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100

  xcrun simctl install "$UDID" "$APP_PATH"

  for SEED in "${SEEDS[@]}"; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -seed "$SEED" >/dev/null
    # Long enough for the spiral's 1.1s reveal to settle.
    sleep 3
    xcrun simctl io "$UDID" screenshot --type=png "$OUT_DIR/$SEED.png" >/dev/null
    echo "  captured $SEED"
  done

  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl shutdown "$UDID" || true
  echo "::endgroup::"
done

# --- verify programmatically, not by eye -----------------------------------
echo "Verifying captures"
FAILED=0
while IFS= read -r -d '' PNG; do
  DIMS="$(sips -g pixelWidth -g pixelHeight "$PNG" | grep -oE '[0-9]+$' | paste -sd'x' -)"
  BYTES="$(stat -f%z "$PNG")"
  echo "  $(basename "$(dirname "$PNG")")/$(basename "$PNG")  $DIMS  ${BYTES}B"
  # A screenshot of a crashed or blank app compresses to almost nothing.
  if [[ "$BYTES" -lt 20000 ]]; then
    echo "::error::$PNG is only ${BYTES} bytes — likely a blank or crashed screen"
    FAILED=1
  fi
done < <(find "$OUT_ROOT" -name '*.png' -print0)

EXPECTED=$(( ${#SEEDS[@]} * ${#DEVICES[@]} ))
ACTUAL=$(find "$OUT_ROOT" -name '*.png' | wc -l | tr -d ' ')
echo "Expected up to $EXPECTED captures, produced $ACTUAL"
[[ "$ACTUAL" -gt 0 ]] || { echo "::error::no captures produced"; exit 1; }
exit "$FAILED"
