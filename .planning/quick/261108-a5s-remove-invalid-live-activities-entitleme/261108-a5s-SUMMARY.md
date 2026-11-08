---
quick_id: 261108-a5s
status: complete
date: 2026-11-08
commit: e72ae87e
---

# Summary

Removed `com.apple.developer.usernotifications.live-activities` from `fitbod/fitbod.entitlements`.
Apple does not recognise that key, so automatic signing failed for device builds.
Live Activities only need `NSSupportsLiveActivities`, which is still set.
Updated the matching note in `FitbodWidgets/SOURCES.md`.

## Verification

- Debug device build for iPhone 15 Pro Max (iOS 26.7.2) with team EFPQ72E256 and no entitlements override: BUILD SUCCEEDED.
- Installed and launched with `devicectl`: the app launched.

## Not checked

- No Live Activity was started on the phone after the change.
- No unit or UI tests were run, because this change only affects signing.
