#!/usr/bin/env bash
#
# Boots simulators, launches Exhale once per seed, screenshots each one.
#
# The seed list is extracted from Shared/SeedNames.swift so there is exactly one
# source of truth — adding a seed in Swift adds it here automatically. (Which is
# why that file must contain no unrelated string literals.)
set -euo pipefail

BUNDLE_ID="com.matthias1412.exhale"
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

# macOS has no coreutils `timeout`, and simulator boot hangs indefinitely often
# enough to matter: one run sat in `bootstatus` for 23 minutes at 10x billing
# before being killed. Nothing here is allowed to block forever.
with_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$secs" ]; then
      echo "::warning::timed out after ${secs}s: $*"
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 2
    waited=$((waited + 2))
  done
  wait "$pid"
}

# Start from a known state — a leftover booted simulator is a common cause of
# the hang.
echo "Shutting down any already-booted simulators"
with_timeout 90 xcrun simctl shutdown all || true

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

  echo "Booting $DEVICE ($UDID)"
  if ! with_timeout 240 xcrun simctl boot "$UDID"; then
    echo "  boot returned non-zero or timed out; checking status anyway"
  fi
  if ! with_timeout 240 xcrun simctl bootstatus "$UDID" -b; then
    echo "::warning::$DEVICE did not report booted in time — retrying once"
    with_timeout 90 xcrun simctl shutdown "$UDID" || true
    with_timeout 240 xcrun simctl boot "$UDID" || true
    if ! with_timeout 240 xcrun simctl bootstatus "$UDID" -b; then
      echo "::error::$DEVICE would not boot; skipping it"
      echo "::endgroup::"
      continue
    fi
  fi
  echo "  booted"

  # Identical status bar every run, so captures are diffable and usable as
  # store assets.
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100

  with_timeout 180 xcrun simctl install "$UDID" "$APP_PATH" || {
    echo "::error::install failed on $DEVICE"; echo "::endgroup::"; continue
  }

  for SEED in "${SEEDS[@]}"; do
    with_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    if ! with_timeout 90 xcrun simctl launch "$UDID" "$BUNDLE_ID" -seed "$SEED" >/dev/null; then
      echo "::error::launch failed for seed '$SEED'"
      continue
    fi
    # Long enough for the spiral's 1.1s reveal to settle.
    sleep 3
    if with_timeout 60 xcrun simctl io "$UDID" screenshot --type=png "$OUT_DIR/$SEED.png" >/dev/null; then
      echo "  captured $SEED"
    else
      echo "::error::screenshot failed for seed '$SEED'"
    fi
  done

  with_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  with_timeout 90 xcrun simctl shutdown "$UDID" || true
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
