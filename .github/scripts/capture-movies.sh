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

# Stills are pulled *during* the recording as well, at these intervals. The
# video is for a person to watch; the filmstrip is so the animation can be
# checked without one — a claim that something moves should be backed by two
# frames that differ, not by a file that exists.
#
# gap × count also sets how long the recorder stays open.
# A screenshot round-trip costs the best part of a second, so a filmstrip can
# only resolve animations slower than that. The 1.1s reveal is not one of them
# — that is what the pinned-frame seed set is for — so the strip is taken only
# where it can actually say something.
frame_gap() {
  case "$1" in
    sos-live)            echo 2 ;;   # 8 gaps spans a full 14s breath cycle
    celebration-handoff) echo 1 ;;   # burst, self-dismiss at 3.2s, then reveal
    *)                   echo 0 ;;
  esac
}
frame_count() {
  case "$1" in
    sos-live|celebration-handoff) echo 9 ;;
    *)                            echo 0 ;;
  esac
}
# Recorder time for the seeds with no filmstrip.
plain_seconds() {
  case "$1" in
    today-day1825) echo 5 ;;
    *)             echo 4 ;;
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
  GAP="$(frame_gap "$SEED")"
  COUNT="$(frame_count "$SEED")"
  OUT="$OUT_DIR/$SEED.mp4"
  STRIP="$OUT_DIR/frames/$SEED"
  if [ "$COUNT" -gt 0 ]; then
    mkdir -p "$STRIP"
    echo "::group::$SEED (video + $COUNT frames every ${GAP}s)"
  else
    echo "::group::$SEED (video, $(plain_seconds "$SEED")s)"
  fi

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

  if [ "$COUNT" -gt 0 ]; then
    # Frame grabs run while the recorder is still open, so the video and the
    # filmstrip are of the same take rather than two separate launches.
    N=1
    while [ "$N" -le "$COUNT" ]; do
      with_timeout 30 xcrun simctl io "$UDID" screenshot --type=png \
        "$STRIP/$(printf '%02d' "$N").png" >/dev/null 2>&1 || true
      sleep "$GAP"
      N=$((N + 1))
    done
  else
    sleep "$(plain_seconds "$SEED")"
  fi

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

MOVIE_COUNT=$(find "$OUT_DIR" -name '*.mp4' | wc -l | tr -d ' ')
FRAME_COUNT=$(find "$OUT_DIR/frames" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
echo "Expected ${#SEEDS[@]} recordings, produced $MOVIE_COUNT (+ $FRAME_COUNT filmstrip frames)"
[[ "$MOVIE_COUNT" -gt 0 ]] || { echo "::error::no recordings produced"; exit 1; }
exit "$FAILED"
