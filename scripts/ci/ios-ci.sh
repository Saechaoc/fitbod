#!/usr/bin/env bash
#
# ios-ci.sh — build, test, and collect verification evidence for the fitbod
# iOS app. Used by .github/workflows/ios.yml and runnable locally on any Mac
# with Xcode 26.4+ installed:
#
#   scripts/ci/ios-ci.sh select-xcode      # CI only: pick newest Xcode 26.x
#   scripts/ci/ios-ci.sh simulators        # create/boot "Fitbod Small/Large"
#   scripts/ci/ios-ci.sh build             # build-for-testing (one build)
#   scripts/ci/ios-ci.sh unit              # Swift Testing unit suites
#   scripts/ci/ios-ci.sh ui small|large    # XCUITest journey + layout audit
#   scripts/ci/ios-ci.sh evidence          # export screenshots + summary
#
# Everything lands in ./.ci (DerivedData, .xcresult bundles, logs, evidence).
# The script never touches signing: simulator builds run with
# CODE_SIGNING_ALLOWED=NO, so no Apple developer team is needed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CI_DIR="$ROOT/.ci"
DERIVED="$CI_DIR/DerivedData"
RESULTS="$CI_DIR/results"
LOGS="$CI_DIR/logs"
SIMS_ENV="$CI_DIR/simulators.env"
mkdir -p "$CI_DIR" "$RESULTS" "$LOGS"

PROJECT="$ROOT/fitbod.xcodeproj"
SCHEME="fitbod"

common_flags=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration Debug
  -derivedDataPath "$DERIVED"
  CODE_SIGNING_ALLOWED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Pretty-print xcodebuild output when xcbeautify is available, but always keep
# the raw log on disk for post-mortem greps.
pretty() {
  local logfile="$1"
  if command -v xcbeautify >/dev/null 2>&1; then
    tee "$logfile" | xcbeautify -q || true
  else
    tee "$logfile" | grep -E "error:|warning: .*fitbod|\*\* (BUILD|TEST)|Test (Case|Suite).*(passed|failed)|✘|✔|Executed" || true
  fi
}

load_sims() {
  if [[ -f "$SIMS_ENV" ]]; then
    # shellcheck disable=SC1090
    source "$SIMS_ENV"
  else
    echo "No $SIMS_ENV — run '$0 simulators' first" >&2
    exit 1
  fi
}

cmd_select_xcode() {
  # The project targets iOS 26.4 (created with Xcode 26.4.1), so prefer the
  # newest installed Xcode 26.x that is >= 26.4; otherwise fall back to the
  # newest Xcode overall.
  local choice
  choice="$(python3 - <<'PY'
import glob, plistlib, re
cands = []
for app in glob.glob("/Applications/Xcode*.app"):
    try:
        with open(f"{app}/Contents/Info.plist", "rb") as f:
            v = plistlib.load(f).get("CFBundleShortVersionString", "0")
    except Exception:
        continue
    parts = [int(x) for x in re.findall(r"\d+", v)][:3]
    while len(parts) < 3:
        parts.append(0)
    beta = "beta" in app.lower() or "_b" in app.lower()
    cands.append((tuple(parts), not beta, app))
pref = [c for c in cands if c[0][0] == 26 and c[0] >= (26, 4, 0)]
pool = pref or cands
pool.sort(key=lambda c: (c[1], c[0]))
print(pool[-1][2] if pool else "")
PY
)"
  if [[ -z "$choice" ]]; then
    echo "No Xcode installation found" >&2
    exit 1
  fi
  log "Selecting $choice"
  sudo xcode-select -s "$choice/Contents/Developer"
  xcodebuild -version
}

cmd_inventory() {
  log "Toolchain inventory"
  sw_vers || true
  xcodebuild -version
  ls -d /Applications/Xcode*.app 2>/dev/null || true
  xcrun simctl list runtimes
  xcrun simctl list devicetypes | grep -i iphone || true
}

cmd_simulators() {
  log "Creating simulators"
  python3 - "$SIMS_ENV" <<'PY'
import json, subprocess, sys

def sh(*args):
    return subprocess.check_output(args, text=True)

out_path = sys.argv[1]
runtimes = json.loads(sh("xcrun", "simctl", "list", "runtimes", "-j"))["runtimes"]
ios = [r for r in runtimes if r.get("platform") == "iOS" and r.get("isAvailable")]
if not ios:
    sys.exit("No available iOS simulator runtime")
ios.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
runtime = ios[-1]
supported = {d["name"]: d["identifier"] for d in runtime.get("supportedDeviceTypes", [])}
if not supported:
    dts = json.loads(sh("xcrun", "simctl", "list", "devicetypes", "-j"))["devicetypes"]
    supported = {d["name"]: d["identifier"] for d in dts}

# Smallest point size first, then the largest Pro Max available.
small_prefs = ["iPhone SE (3rd generation)", "iPhone 13 mini", "iPhone 12 mini",
               "iPhone 16e", "iPhone 17e", "iPhone 17", "iPhone 16"]
large_prefs = ["iPhone 17 Pro Max", "iPhone 16 Pro Max", "iPhone 16 Plus",
               "iPhone 15 Pro Max", "iPhone Air", "iPhone 17 Pro", "iPhone 16 Pro"]

def pick(prefs):
    for name in prefs:
        if name in supported:
            return name, supported[name]
    iphones = sorted(n for n in supported if n.startswith("iPhone"))
    return iphones[-1], supported[iphones[-1]]

devices = json.loads(sh("xcrun", "simctl", "list", "devices", "-j"))["devices"]
existing = {d["name"]: d["udid"] for d in devices.get(runtime["identifier"], [])}

lines = [f'RUNTIME_NAME="{runtime["name"]}"', f'RUNTIME_ID="{runtime["identifier"]}"']
for role, prefs in (("SMALL", small_prefs), ("LARGE", large_prefs)):
    name, dtype = pick(prefs)
    sim_name = f"Fitbod {role.title()} ({name})"
    udid = existing.get(sim_name) or sh("xcrun", "simctl", "create", sim_name, dtype, runtime["identifier"]).strip()
    lines += [f'{role}_UDID="{udid}"', f'{role}_NAME="{name}"']
    print(f"{role}: {name} → {udid} on {runtime['name']}")

with open(out_path, "w") as f:
    f.write("\n".join(lines) + "\n")
PY
  load_sims
  # Devices are not pre-booted: xcodebuild boots each one when its test
  # step starts, which avoids a long serial boot here and a stale
  # "Booting" state confusing destination matching later.
  cat "$SIMS_ENV"
}

cmd_build() {
  log "build-for-testing (generic iOS Simulator)"
  set -o pipefail
  # A generic destination needs no booted or matching device; the test
  # steps below run the same products on specific simulators.
  xcodebuild build-for-testing "${common_flags[@]}" \
    -destination "generic/platform=iOS Simulator" \
    2>&1 | pretty "$LOGS/build.log"
}

run_tests() {
  local label="$1" udid="$2"; shift 2
  local bundle="$RESULTS/$label.xcresult"
  rm -rf "$bundle"
  log "test-without-building [$label]"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  set -o pipefail
  xcodebuild test-without-building "${common_flags[@]}" \
    -destination "platform=iOS Simulator,id=$udid" \
    -resultBundlePath "$bundle" \
    -parallel-testing-enabled NO \
    "$@" 2>&1 | pretty "$LOGS/$label.log"
}

cmd_unit() {
  load_sims
  run_tests unit "$LARGE_UDID" -only-testing:fitbodTests
}

cmd_ui() {
  load_sims
  local size="${1:-large}"
  local udid
  if [[ "$size" == "small" ]]; then udid="$SMALL_UDID"; else udid="$LARGE_UDID"; fi
  run_tests "ui-$size" "$udid" -only-testing:fitbodUITests
}

cmd_evidence() {
  load_sims
  log "Exporting screenshots and summaries"
  local out="$CI_DIR/evidence"
  rm -rf "$out"; mkdir -p "$out"
  python3 "$ROOT/scripts/ci/collect_evidence.py" \
    --results "$RESULTS" --out "$out" \
    --small "$SMALL_NAME" --large "$LARGE_NAME" --runtime "$RUNTIME_NAME" \
    --xcode "$(xcodebuild -version | tr '\n' ' ')"
}

case "${1:-}" in
  select-xcode) cmd_select_xcode ;;
  inventory) cmd_inventory ;;
  simulators) cmd_simulators ;;
  build) cmd_build ;;
  unit) cmd_unit ;;
  ui) shift; cmd_ui "${1:-large}" ;;
  evidence) cmd_evidence ;;
  *) echo "usage: $0 {select-xcode|inventory|simulators|build|unit|ui small|ui large|evidence}" >&2; exit 2 ;;
esac
