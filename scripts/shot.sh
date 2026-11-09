#!/usr/bin/env bash
#
# shot.sh — capture one seeded app state on the 390pt phone, light and dark.
#
#   scripts/shot.sh <name> [launch args]
#   scripts/shot.sh today-first
#   scripts/shot.sh today-resume -fitbod-seed-demo-workout
#
# Builds the app, installs it on FITBOD_SHOT_DEVICE and, for each appearance,
# launches it on an empty store (-fitbod-reset-store) with the given launch
# arguments, then saves .ci/shots/<name>-light.png and <name>-dark.png.
# A state behind a tap (a sheet, a pushed screen) is captured by driving the
# simulator instead.
#
# Environment:
#   FITBOD_SHOT_DEVICE  simulator UDID (required): the dedicated 390pt phone,
#                       "fitbod-17e iPhone 17e". Its app data is reset.
#   FITBOD_SHOT_WAIT    seconds between launch and capture (default 6).
#   FITBOD_TEST_DD      DerivedData, the folder scripts/test.sh builds into,
#                       so a capture after a test run is an incremental build.
#                       Do not run this while tests run from the same folder.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="${1:?usage: $0 <name> [launch args]}"
shift
DEVICE="${FITBOD_SHOT_DEVICE:?set FITBOD_SHOT_DEVICE to the 390pt capture simulator UDID}"
WAIT="${FITBOD_SHOT_WAIT:-6}"
DD="${FITBOD_TEST_DD:-/tmp/fitbod-test-dd-$(printf %s "$ROOT" | shasum | cut -c1-8)}"
OUT="$ROOT/.ci/shots"
mkdir -p "$OUT"

xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl ui "$DEVICE" content_size large

xcodebuild -project "$ROOT/fitbod.xcodeproj" -scheme fitbod -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath "$DD" \
  build CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO > "$OUT/build.log" 2>&1 || {
    grep -E "\.swift:[0-9]+:[0-9]+: error:|^xcodebuild: error:" "$OUT/build.log" | head -20 >&2
    echo "build failed; see $OUT/build.log" >&2
    exit 1
  }
xcrun simctl install "$DEVICE" "$DD/Build/Products/Debug-iphonesimulator/fitbod.app"

for look in light dark; do
  xcrun simctl ui "$DEVICE" appearance "$look"
  xcrun simctl launch --terminate-running-process "$DEVICE" bodybuilding.fitbod \
    -fitbod-reset-store "$@" >/dev/null
  # shortcut: a fixed wait, not a readiness check. A reset store imports the
  # exercise library before Today draws; raise FITBOD_SHOT_WAIT if a capture
  # shows the preparation screen.
  sleep "$WAIT"
  xcrun simctl io "$DEVICE" screenshot "$OUT/$NAME-$look.png" >/dev/null 2>&1
  echo "$OUT/$NAME-$look.png"
done
xcrun simctl ui "$DEVICE" appearance light
