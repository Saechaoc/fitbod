#!/usr/bin/env bash
#
# tour_run.sh - run the design-map screenshot tour on one simulator.
#
#   tools/tour_run.sh <17e|17promax> <default|ax3> <light|dark> <test> [trees]
#
#   <test>   a class or class/method in fitbodUITests, such as
#            DesignTourMainUITests or DesignTourStatesUITests/testW15Routines
#   trees    pass "trees" to attach accessibility trees (17e light default)
#
# The tour runs from a private worktree copy of the project, so nothing in
# the repository's targets changes. The script recreates the copy when it
# is missing, copies tools/DesignTourUITests.swift.txt into its
# fitbodUITests/ folder, rebuilds when that file changed, boots the
# simulator, sets its appearance and status bar, warms the app up, runs the
# tests and exports the screenshots with tour_export.py.
#
# Environment:
#   DESIGN_WORK  working folder for the copy, results and full-size images
#                (default: $TMPDIR/fitbod-design-work)
#   DESIGN_BASE  commit the copy is made from (default: 61353088)
#
# One simulator job runs at a time. Simulators whose names start with
# "sw6-" belong to other work and are never used.

set -euo pipefail

usage() { sed -n 3,12p "$0" >&2; exit 2; }
[[ $# -ge 4 ]] || usage

PHONE="$1" SIZE="$2" APPEARANCE="$3" TEST="$4" TREES="${5:-}"
case "$PHONE" in
  17e) SIM_NAME="design-iPhone 17e" ;;
  17promax) SIM_NAME="design-iPhone 17 Pro Max" ;;
  *) usage ;;
esac
[[ "$SIZE" == default || "$SIZE" == ax3 ]] || usage
[[ "$APPEARANCE" == light || "$APPEARANCE" == dark ]] || usage

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAP="$(dirname "$TOOLS")"
ROOT="$(cd "$MAP/../.." && pwd)"
WORK="${DESIGN_WORK:-${TMPDIR:-/tmp}/fitbod-design-work}"
BASE="${DESIGN_BASE:-61353088}"
COPY="$WORK/fitbod-design-tour"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/fitbod-design"
RESULTS="$WORK/results"
LOGS="$WORK/logs"
mkdir -p "$RESULTS" "$LOGS"

log() { printf '\n==> %s\n' "$*"; }

# Kills a command after $1 seconds (macOS ships no `timeout`).
with_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

# One run at a time: two runs would share the copy, DerivedData and the
# phones. A lock left by a killed run is taken over once its PID is gone.
LOCK="$WORK/run.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  holder="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
    echo "Tour run $holder is still active (lock $LOCK)" >&2
    exit 1
  fi
  echo "Taking over the lock left by run ${holder:-unknown}" >&2
fi
echo $$ > "$LOCK/pid"

UDID=""
# shellcheck disable=SC2329  # called by the EXIT trap below
cleanup() {
  if [[ -n "$UDID" ]]; then
    xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1 || true
    xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
  fi
  rm -rf "$LOCK"
}
trap cleanup EXIT

# 1. The private copy, which must be at the base commit.
BASE_SHA="$(git -C "$ROOT" rev-parse --verify "$BASE^{commit}")"
if [[ ! -d "$COPY/fitbod.xcodeproj" ]]; then
  log "Creating the private copy at $COPY from $BASE"
  git -C "$ROOT" worktree prune
  git -C "$ROOT" worktree add --detach "$COPY" "$BASE_SHA"
fi
copy_sha="$(git -C "$COPY" rev-parse HEAD)"
if [[ "$copy_sha" != "$BASE_SHA" ]]; then
  echo "The copy at $COPY is at $copy_sha, not $BASE ($BASE_SHA)." >&2
  echo "Remove it with: git -C \"$ROOT\" worktree remove --force \"$COPY\"" >&2
  exit 1
fi
TOUR_SRC="$TOOLS/DesignTourUITests.swift.txt"
TOUR_DST="$COPY/fitbodUITests/DesignTourUITests.swift"
STAMP="$WORK/tour.built.sha"
cp "$TOUR_SRC" "$TOUR_DST"

# 2. Build when the base or the tour changed since the last good build.
want="$BASE_SHA $(shasum "$TOUR_DST" | cut -d' ' -f1)"
have="$(cat "$STAMP" 2>/dev/null || true)"
if [[ "$want" != "$have" || ! -d "$DERIVED/Build/Products/Debug-iphonesimulator/fitbod.app" ]]; then
  log "build-for-testing"
  if ! xcodebuild build-for-testing \
      -project "$COPY/fitbod.xcodeproj" -scheme fitbod -configuration Debug \
      -derivedDataPath "$DERIVED" -destination "generic/platform=iOS Simulator" \
      ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
      > "$LOGS/build.log" 2>&1; then
    grep -E "error:" "$LOGS/build.log" | head -40 >&2 || true
    echo "Build failed; see $LOGS/build.log" >&2
    exit 1
  fi
  echo "$want" > "$STAMP"
fi

# 3. The simulator.
UDID="$(xcrun simctl list devices available -j | python3 -I -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == name:
            print(d["udid"]); raise SystemExit
' "$SIM_NAME")"
[[ -n "$UDID" ]] || { echo "No simulator named $SIM_NAME" >&2; exit 1; }

# Shut down the other design phone; never touch anyone else's simulators.
for other in "design-iPhone 17e" "design-iPhone 17 Pro Max"; do
  [[ "$other" == "$SIM_NAME" ]] || xcrun simctl shutdown "$other" >/dev/null 2>&1 || true
done

log "Booting $SIM_NAME ($UDID)"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
with_timeout 600 xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance "$APPEARANCE"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 --dataNetwork wifi

# 4. Warm-up: the first launch on a fresh simulator can outlast XCUITest's
# launch timeout, so launch the app once outside XCTest, as CI does.
APP="$DERIVED/Build/Products/Debug-iphonesimulator/fitbod.app"
xcrun simctl install "$UDID" "$APP"
with_timeout 300 xcrun simctl launch "$UDID" bodybuilding.fitbod >/dev/null || true
sleep 12
xcrun simctl terminate "$UDID" bodybuilding.fitbod >/dev/null 2>&1 || true

# 5. The tests.
LABEL="$(echo "$TEST" | tr '/' '_')"
BUNDLE="$RESULTS/$PHONE-$SIZE-$APPEARANCE-$LABEL-$(date +%Y%m%d-%H%M%S).xcresult"
log "test-without-building $TEST on $PHONE $SIZE $APPEARANCE"
set +e
TEST_RUNNER_DESIGN_TEXTSIZE="$SIZE" \
TEST_RUNNER_DESIGN_APPEARANCE="$APPEARANCE" \
TEST_RUNNER_DESIGN_TREES="$([[ "$TREES" == trees ]] && echo 1 || echo 0)" \
xcodebuild test-without-building \
  -project "$COPY/fitbod.xcodeproj" -scheme fitbod -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -resultBundlePath "$BUNDLE" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 600 \
  -only-testing:"fitbodUITests/$TEST" \
  CODE_SIGNING_ALLOWED=NO > "$LOGS/$PHONE-$SIZE-$APPEARANCE-$LABEL.log" 2>&1
STATUS=$?
set -e
grep -E "Test Case .*(passed|failed)|error: |\*\* TEST" "$LOGS/$PHONE-$SIZE-$APPEARANCE-$LABEL.log" | tail -40 || true

# 6. Export, even after failures: every shot taken before a failure counts.
log "Exporting screenshots from $BUNDLE"
python3 -I "$TOOLS/tour_export.py" --result "$BUNDLE" --img "$MAP/screens/img" \
  --tree "$MAP/screens/tree" --full "$WORK/full"
exit $STATUS
