#!/usr/bin/env bash
#
# Records the app's animations as video instead of stills.
#
# A pinned frame proves the drawing is right at that instant; it says nothing
# about whether the timing feels right, and a still of a frozen animation is
# indistinguishable from one that is working. The breathing orb sat motionless
# for an entire release and every screenshot of it looked correct.
#
# Seed names come from SeedNames.movies; the seconds each needs live here,
# because duration is a property of the recording, not of the app.
set -euo pipefail

BUNDLE_ID="com.matthias1412.exhale"
APP_PATH="$(find build/Build/Products -maxdepth 3 -name 'Exhale.app' | head -1)"
OUT_DIR="artifacts/movies"

if [[ -z "$APP_PATH" ]]; then
  echo "::error::Exhale.app not found under build/Build/Products"
  exit 1
fi

DEVICE="${SIM_ONE:?select-toolchain.sh did not run}"

# How long to hold the recorder open per seed. Anything not listed gets the
# default: long enough for the 1.1s reveal plus a beat of the settled state.
seconds_for() {
  case "$1" in
    sos-live)            echo 18 ;;   # a full 14s breath cycle, plus lead-in
    celebration-handoff) echo 10 ;;   # burst, self-dismiss at 3.2s, then reveal
    today-day1825)       echo 5  ;;
    *)                   echo 4  ;;
  esac
}

SEEDS=()
while IFS= read -r seed; do
  [ -n "$seed" ] && SEEDS+=("$seed")
done < <(
  sed -n '/static let movies:/,/^    \]/p' Shared/SeedNames.swift \
    | grep -oE '"[a-z0-9][a-z0-9-]*"' | tr -d '"'
)

if [[ ${#SEEDS[@]} -eq 0 ]]; then
  echo "::error::extracted no movie seeds from Shared/SeedNames.swift"
  exit 1
fi
echo "Recording ${#SEEDS[@]} seeds on $DEVICE"
mkdir -p "$OUT_DIR"

# Same watchdog as capture.sh — simulator boot hangs indefinitely often enough
# that one run sat in bootstatus for 23 minutes at 10x billing.
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

with_timeout 90 xcrun simctl shutdown all || true

UDID="$(xcrun simctl list devices available \
      | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)"
if [[ -z "$UDID" ]]; then
  echo "::error::$DEVICE not available on this runner image"
  exit 1
fi

echo "Booting $DEVICE ($UDID)"
with_timeout 240 xcrun simctl boot "$UDID" || true
if ! with_timeout 240 xcrun simctl bootstatus "$UDID" -b; then
  echo "::error::$DEVICE would not boot"
  exit 1
fi

xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100

with_timeout 180 xcrun simctl install "$UDID" "$APP_PATH"

for SEED in "${SEEDS[@]}"; do
  DURATION="$(seconds_for "$SEED")"
  OUT="$OUT_DIR/$SEED.mp4"
  echo "::group::$SEED (${DURATION}s)"

  with_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  # Recorder first, app second: the reveal starts on the first frame the app
  # draws, so starting the recorder afterwards would miss the thing being
  # recorded. h264 in an mp4 rather than the default HEVC .mov so it plays on
  # anything without a codec hunt.
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT" &
  REC_PID=$!
  sleep 2   # recorder needs a moment to attach before it captures anything

  if ! with_timeout 90 xcrun simctl launch "$UDID" "$BUNDLE_ID" -seed "$SEED" >/dev/null; then
    echo "::error::launch failed for seed '$SEED'"
    kill -INT "$REC_PID" 2>/dev/null || true
    wait "$REC_PID" 2>/dev/null || true
    echo "::endgroup::"
    continue
  fi

  sleep "$DURATION"

  # SIGINT, not SIGKILL — recordVideo writes the moov atom on interrupt, and a
  # killed recording is an unplayable file.
  kill -INT "$REC_PID" 2>/dev/null || true
  wait "$REC_PID" 2>/dev/null || true
  sleep 1

  if [[ -s "$OUT" ]]; then
    echo "  recorded $(basename "$OUT") ($(stat -f%z "$OUT") bytes)"
  else
    echo "::error::no video produced for '$SEED'"
  fi
  echo "::endgroup::"
done

with_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
with_timeout 90 xcrun simctl shutdown "$UDID" || true

echo "Verifying recordings"
FAILED=0
while IFS= read -r -d '' MOV; do
  BYTES="$(stat -f%z "$MOV")"
  echo "  $(basename "$MOV")  ${BYTES}B"
  # A recording of a crashed launch is a second of black and compresses to
  # almost nothing.
  if [[ "$BYTES" -lt 40000 ]]; then
    echo "::error::$MOV is only ${BYTES} bytes — likely a black or crashed screen"
    FAILED=1
  fi
done < <(find "$OUT_DIR" -name '*.mp4' -print0)

COUNT=$(find "$OUT_DIR" -name '*.mp4' | wc -l | tr -d ' ')
echo "Expected ${#SEEDS[@]} recordings, produced $COUNT"
[[ "$COUNT" -gt 0 ]] || { echo "::error::no recordings produced"; exit 1; }
exit "$FAILED"
