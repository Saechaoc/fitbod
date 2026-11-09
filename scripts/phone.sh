#!/usr/bin/env bash
#
# phone.sh — build the app for the connected iPhone and install it.
#
#   FITBOD_PHONE=<udid> scripts/phone.sh
#
# Builds Debug for the device with the project's signing team, then installs
# over the existing app, which keeps its data. It does not launch the app:
# iOS refuses a launch from the Mac while the phone is locked, so tap the icon.
#
# Environment:
#   FITBOD_PHONE     the phone's hardware UDID (required), the id that
#                    `xcodebuild -showdestinations` and `xcrun xctrace list
#                    devices` print. Keep it out of the repository.
#   FITBOD_PHONE_DD  DerivedData (default ~/Library/Caches/fitbod-phone-build,
#                    outside /tmp so the build stays warm across restarts).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHONE="${FITBOD_PHONE:?set FITBOD_PHONE to the hardware UDID of the phone}"
DD="${FITBOD_PHONE_DD:-$HOME/Library/Caches/fitbod-phone-build}"
mkdir -p "$DD"

xcodebuild -project "$ROOT/fitbod.xcodeproj" -scheme fitbod -configuration Debug \
  -destination "id=$PHONE" -derivedDataPath "$DD" -allowProvisioningUpdates \
  build > "$DD/build.log" 2>&1 || {
    grep -E "\.swift:[0-9]+:[0-9]+: error:|^xcodebuild: error:|error: (No Accounts|No profiles|Provisioning)" "$DD/build.log" | head -20 >&2
    echo "build failed; see $DD/build.log" >&2
    exit 1
  }
xcrun devicectl device install app --device "$PHONE" "$DD/Build/Products/Debug-iphoneos/fitbod.app"
echo "Installed $(git -C "$ROOT" rev-parse --short HEAD). Unlock the phone and tap Fitbod to launch."
