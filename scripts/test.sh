#!/usr/bin/env bash
#
# test.sh — the two local test tiers.
#
#   scripts/test.sh fast [xcodebuild test args]   # developer feedback, ~30 s
#   scripts/test.sh full                          # full verification, ~60 min
#
# fast: an incremental build-for-testing, then every unit test (fitbodTests)
#       in one serial process. Extra args replace the selection, for example
#       `scripts/test.sh fast -only-testing:fitbodUITests/SkipWarmupsUITests`
#       to run one UI class while you work on it.
# full: the same build, every unit test serially, then every UI test class
#       sharded over FITBOD_TEST_WORKERS simulators at once, then the widget
#       build. Each shard is one serial xcodebuild run on its own simulator;
#       tests in a class stay together and in order. It fails unless the
#       merged result ran exactly the tests the build enumerates, so sharding
#       cannot drop a test silently.
#
# Environment:
#   FITBOD_TEST_DEVICE   simulator UDID (required): a dedicated test phone,
#                        never a personal-data simulator. Shards 2..N are
#                        siblings the script creates once, "<name> shard K",
#                        of the same model and runtime.
#   FITBOD_TEST_WORKERS  UI shards for `full` (default 2; 1 = serial). Four
#                        shards on the 12-core M4 failed 1-2 typing and
#                        sheet tests per run that pass serially; two did not.
#   FITBOD_TEST_DD       DerivedData (default /tmp/fitbod-test-dd-<hash of
#                        this worktree>, so two worktrees never share one).
#   FITBOD_TEST_OUT      result bundles and logs (default /tmp/fitbod-test-out).
#
# Why not `-parallel-testing-enabled YES`: xcodebuild reuses cached clones
# whose text size can differ from the device's, and a trial run hung. Unit
# tests never run in parallel processes: SwiftData suites crashed on clones
# ("refRemapping clone-crash cascade"), and some share UserDefaults.
# Shards are balanced by scripts/ui-test-timings.json; refresh it after a
# full run with `python3 scripts/test_results.py timings <bundle>`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIER="${1:-}"
[[ "$TIER" == fast || "$TIER" == full ]] || { echo "usage: $0 fast|full [xcodebuild test args]" >&2; exit 2; }
shift

DEVICE="${FITBOD_TEST_DEVICE:?set FITBOD_TEST_DEVICE to a dedicated simulator UDID}"
WORKERS="${FITBOD_TEST_WORKERS:-2}"
DD="${FITBOD_TEST_DD:-/tmp/fitbod-test-dd-$(printf %s "$ROOT" | shasum | cut -c1-8)}"
OUT="${FITBOD_TEST_OUT:-/tmp/fitbod-test-out}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN="$OUT/$TIER-$STAMP"
mkdir -p "$RUN"

flags=(
  -project "$ROOT/fitbod.xcodeproj"
  -scheme fitbod
  -destination "platform=iOS Simulator,id=$DEVICE"
  -derivedDataPath "$DD"
  CODE_SIGNING_ALLOWED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)
# Without this, a run with any failure waits minutes in `simctl diagnose`.
test_flags=(-collect-test-diagnostics never)

T0=$(date +%s)
elapsed() { echo $(( $(date +%s) - T0 )); }
step() { printf '==> %s (t=%ss)\n' "$*" "$(elapsed)"; }

# Runs xcodebuild into a log and prints only the result lines.
xb() {
  local log="$1"; shift
  local status=0
  xcodebuild "$@" > "$log" 2>&1 || status=$?
  grep -E "^\*\* .* (SUCCEEDED|FAILED) \*\*|^xcodebuild: error:|\.swift:[0-9]+:[0-9]+: error:" "$log" | tail -20 || true
  return "$status"
}

summary() { python3 "$ROOT/scripts/test_results.py" summary "$1"; }

APP_ID=bodybuilding.fitbod

# Boots a phone, pins default text and light mode, and checks that both took.
prepare() {
  local udid="$1"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" content_size large
  xcrun simctl ui "$udid" appearance light
  local size look
  size="$(xcrun simctl ui "$udid" content_size)"
  look="$(xcrun simctl ui "$udid" appearance)"
  [[ "$size" == large && "$look" == light ]] || { echo "$udid is $size/$look, not large/light" >&2; return 1; }
}

# Runs one serial test-without-building on phone $1, logging to $2 and
# writing bundle $3. A run in which no test started (the runner hung or never
# bootstrapped) is retried once on the rebooted phone, as scripts/ci/ios-ci.sh
# does. A run in which any test started is never retried, so a failing or
# flaky test stays failed.
xctest() {
  local udid="$1" log="$2" bundle="$3"; shift 3
  local attempt code started
  for attempt in 1 2; do
    rm -rf "$bundle"
    code=0
    xb "$log" test-without-building -destination "platform=iOS Simulator,id=$udid" \
      "${test_flags[@]}" -parallel-testing-enabled NO -resultBundlePath "$bundle" "$@" || code=$?
    [[ $code -ne 0 ]] || return 0
    # A bad argument fails before testing starts; a reboot would not help it.
    if grep -q "^xcodebuild: error:" "$log" && ! grep -q "^Testing started" "$log"; then return "$code"; fi
    started="$(python3 "$ROOT/scripts/test_results.py" started "$bundle" 2>/dev/null || echo 0)"
    [[ $attempt -eq 1 && "$started" -eq 0 ]] || return "$code"
    echo "   no test started on $udid; rebooting it and retrying once" >&2
    mv "$log" "$log.attempt1"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    if [[ "$TIER" == full ]]; then
      prepare "$udid" || return 1
    else
      xcrun simctl boot "$udid" >/dev/null 2>&1 || true
      xcrun simctl bootstatus "$udid" -b >/dev/null
    fi
  done
}

xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

[[ "$TIER" == fast || $# -eq 0 ]] || { echo "full takes no test args; it runs everything" >&2; exit 2; }

step "build-for-testing"
xb "$RUN/build.log" "${flags[@]}" build-for-testing
xctestrun="$(ls -t "$DD"/Build/Products/*.xctestrun | head -1)"

status=0
if [[ "$TIER" == fast ]]; then
  selection=("$@")
  [[ ${#selection[@]} -gt 0 ]] || selection=(-only-testing:fitbodTests)
  step "tests (serial)"
  # The unit tests' host app opens its store at launch; start it empty, so no
  # store left by an earlier UI run decides whether the host even starts.
  xcrun simctl uninstall "$DEVICE" "$APP_ID" >/dev/null 2>&1 || true
  xctest "$DEVICE" "$RUN/test.log" "$RUN/fast.xcresult" -xctestrun "$xctestrun" "${selection[@]}" || status=$?
  summary "$RUN/fast.xcresult"
  step "done: exit $status, bundle $RUN/fast.xcresult"
  exit "$status"
fi

# The UDID of shard $1, created from the main device's model and runtime.
shard_device() {
  local index="$1"
  [[ "$index" -eq 1 ]] && { echo "$DEVICE"; return; }
  xcrun simctl list devices -j | python3 -c '
import json, subprocess, sys
device, index = sys.argv[1], sys.argv[2]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["udid"] == device:
            name = d["name"] + " shard " + index
            for other in devices:
                if other["name"] == name and other.get("isAvailable", True):
                    print(other["udid"]); sys.exit()
            print(subprocess.check_output(["xcrun", "simctl", "create", name,
                d["deviceTypeIdentifier"], runtime], text=True).strip()); sys.exit()
sys.exit(f"device {device} not found")' "$DEVICE" "$index"
}

step "enumerate tests"
# Listing tests launches the test runner, which can hang before it connects.
# A retry here cannot hide a test result: no test has run yet.
for attempt in 1 2 3; do
  rm -f "$RUN/enumerated.json"
  xcodebuild "${flags[@]}" test-without-building -enumerate-tests -test-enumeration-format json \
    -test-enumeration-output-path "$RUN/enumerated.json" > "$RUN/enumerate.log" 2>&1 || true
  python3 -c 'import json, sys; sys.exit(1 if json.load(open(sys.argv[1])).get("errors") else 0)' \
    "$RUN/enumerated.json" 2>/dev/null && break
  [[ $attempt -lt 3 ]] || { echo "test enumeration failed 3 times; see $RUN/enumerate.log" >&2; exit 1; }
  echo "   enumeration attempt $attempt failed; retrying"
done
python3 "$ROOT/scripts/test_results.py" shard "$RUN/enumerated.json" \
  "$ROOT/scripts/ui-test-timings.json" "$WORKERS" > "$RUN/shards.txt"
WORKERS="$(wc -l < "$RUN/shards.txt" | tr -d ' ')"

shards=()
for ((i = 1; i <= WORKERS; i++)); do shards+=("$(shard_device "$i")"); done
step "prepare ${#shards[@]} phones"
for udid in "${shards[@]}"; do prepare "$udid" & done
for job in $(jobs -p); do wait "$job" || { echo "a phone could not be prepared" >&2; exit 1; }; done

step "unit tests (serial)"
xcrun simctl uninstall "$DEVICE" "$APP_ID" >/dev/null 2>&1 || true
xctest "$DEVICE" "$RUN/unit.log" "$RUN/unit.xcresult" -xctestrun "$xctestrun" \
  -only-testing:fitbodTests || status=$?
summary "$RUN/unit.xcresult"

# Every shard starts from an uninstalled app, so no store survives from an
# earlier run or the unit tests' host app, whatever class runs first.
for udid in "${shards[@]}"; do xcrun simctl uninstall "$udid" "$APP_ID" >/dev/null 2>&1 || true; done

step "UI tests (${#shards[@]} shards)"
i=0
while read -r classes; do
  udid="${shards[$i]}"; i=$((i + 1))
  selection=()
  for class in $classes; do selection+=("-only-testing:fitbodUITests/$class"); done
  (
    S0=$(date +%s)
    code=0
    xctest "$udid" "$RUN/ui-$i.log" "$RUN/ui-$i.xcresult" -xctestrun "$xctestrun" \
      "${selection[@]}" > /dev/null || code=$?
    # XCUITest waits 60 s for each of these; they show where a slow shard went.
    stalls="$(grep -c "App animations complete notification not received" "$RUN/ui-$i.log" || true)"
    echo "   shard $i on $udid: exit $code in $(( $(date +%s) - S0 ))s, $stalls idle-wait stalls"
    exit "$code"
  ) &
done < "$RUN/shards.txt"
for job in $(jobs -p); do wait "$job" || status=1; done

step "widget build"
xb "$RUN/widget.log" -project "$ROOT/fitbod.xcodeproj" -scheme FitbodWidgetsExtension \
  -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath "$DD" \
  build CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO || status=$?

step "merge and coverage check"
bundles=("$RUN/unit.xcresult")
for ((k = 1; k <= i; k++)); do bundles+=("$RUN/ui-$k.xcresult"); done
xcrun xcresulttool merge "${bundles[@]}" --output-path "$RUN/full.xcresult" >/dev/null
summary "$RUN/full.xcresult"
xcrun xcresulttool get test-results tests --path "$RUN/full.xcresult" > "$RUN/ran.json"
python3 "$ROOT/scripts/test_results.py" coverage "$RUN/enumerated.json" "$RUN/ran.json" || status=1

step "done: exit $status, bundle $RUN/full.xcresult"
exit "$status"
