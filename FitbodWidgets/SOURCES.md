# FitbodWidgets Widget Extension — Manual Xcode Wiring

> **STATUS:** Source files ready. Widget Extension target NOT yet added to `fitbod.xcodeproj`.
>
> **Why this isn't auto-wired:** Adding a new `PBXNativeTarget` (with its own
> `XCConfigurationList`, `PBXSourcesBuildPhase`, `PBXResourcesBuildPhase`, target
> dependency, "Embed App Extensions" build phase on the main app target, and a
> shared file membership for `RestTimerAttributes.swift`) is too risky to attempt
> via Edit-tool surgery on `project.pbxproj`. Xcode regenerates the pbxproj
> aggressively, and a malformed pbxproj prevents the project from opening at all.
>
> Per plan `02-02-PLAN.md` § "Risk acknowledgment" — the planner pre-approved
> the fallback of writing the source files and surfacing this manual step in
> the SUMMARY when the executor runs in autonomous mode.

## What's already done by plan 02-02 (no action required)

- [x] `FitbodWidgets/FitbodWidgetsBundle.swift` — `@main` `WidgetBundle` with `RestTimerLiveActivity()`
- [x] `FitbodWidgets/RestTimerLiveActivity.swift` — `ActivityConfiguration` with lock-screen + `dynamicIsland { ... }` (compact / minimal / expanded)
- [x] `FitbodWidgets/RestTimerLockScreenView.swift` — non-Dynamic-Island lock-screen card view
- [x] `FitbodWidgets/Info.plist` — `NSExtensionPointIdentifier = com.apple.widgetkit-extension` + `NSSupportsLiveActivities = YES`
- [x] `FitbodWidgets/FitbodWidgets.entitlements` — sandbox enabled, no app group needed
- [x] `fitbod/Sessions/RestTimer/RestTimerAttributes.swift` — `ActivityAttributes` shared between main app and widget
- [x] `fitbod/Sessions/RestTimer/RestTimerActivityController.swift` — main-app side of ActivityKit with debounce + silent fallback
- [x] `fitbod/Sessions/RestTimer/RestTimerLiveActivityBridge.swift` — glue layer the engine in plan 02-03 will hold
- [x] `fitbod/fitbod.entitlements` — added with `com.apple.developer.usernotifications.live-activities = YES`
- [x] `fitbod.xcodeproj/project.pbxproj` — `INFOPLIST_KEY_NSSupportsLiveActivities = YES` added to both Debug + Release configs of the main app target; `CODE_SIGN_ENTITLEMENTS = fitbod/fitbod.entitlements` wired

## What YOU need to do in Xcode (one-time, ~3 minutes)

### Step 1 — Add the Widget Extension target

1. Open `fitbod.xcodeproj` in Xcode.
2. **File → New → Target…**
3. In the iOS template chooser, select **Widget Extension**.
4. Click **Next**.
5. Fill in:
   - **Product Name:** `FitbodWidgets`
   - **Team:** (your personal team — same as main app)
   - **Organization Identifier:** `bodybuilding` (matches main app's `bodybuilding.fitbod`)
   - **Bundle Identifier:** (Xcode will auto-fill `bodybuilding.fitbod.FitbodWidgets`; leave default)
   - **Language:** Swift
   - **Include Live Activity:** **CHECKED** (this auto-adds the `ActivityKit` framework link)
   - **Include Configuration Intent:** **UNCHECKED** (Phase 2 doesn't use widget configuration)
6. Click **Finish**.
7. When Xcode asks **"Activate FitbodWidgets scheme?"** → click **Activate**.

### Step 2 — Replace Xcode's generated stub files with the ones already in the repo

Xcode will create stubs in a new `FitbodWidgets/` folder. **Delete these stubs**
(the auto-generated `FitbodWidgets.swift`, `FitbodWidgetsLiveActivity.swift`,
`FitbodWidgetsBundle.swift`, etc.) — keep the **target** but remove the
**files** Xcode generated. Then drag the existing `FitbodWidgets/` files from
this folder into the new target's group in the Xcode navigator:

- `FitbodWidgetsBundle.swift`
- `RestTimerLiveActivity.swift`
- `RestTimerLockScreenView.swift`
- `Info.plist` (already exists — Xcode created its own; **replace** with the repo's copy, OR keep Xcode's and just add `NSSupportsLiveActivities = YES` + the `NSExtension > NSExtensionPointIdentifier = com.apple.widgetkit-extension` block)
- `FitbodWidgets.entitlements` (set as `CODE_SIGN_ENTITLEMENTS` on the target)

When prompted, **CHECK "Copy items if needed" UNCHECKED** (the files are
already in place — we just need Xcode to reference them) and **CHECK
"FitbodWidgets" target membership**.

### Step 3 — Add `RestTimerAttributes.swift` to BOTH targets

`fitbod/Sessions/RestTimer/RestTimerAttributes.swift` is currently auto-discovered
into the main `fitbod` target via `PBXFileSystemSynchronizedRootGroup`. The
widget extension needs the same file in its membership too.

1. In Xcode's project navigator, find `fitbod/Sessions/RestTimer/RestTimerAttributes.swift`.
2. With the file selected, open the **File Inspector** (right sidebar, first tab).
3. Under **Target Membership**, **CHECK** the `FitbodWidgets` checkbox in addition
   to the already-checked `fitbod` checkbox.

### Step 4 — Verify the main app embeds the widget extension

1. Select the `fitbod` target in the project editor.
2. **General** tab → scroll to **Frameworks, Libraries, and Embedded Content**.
3. Confirm `FitbodWidgets.appex` is listed with **Embed: Embed Without Signing**
   (Xcode usually adds this automatically when you add the widget target).
4. If missing, click `+`, search for `FitbodWidgets.appex`, add it, and set
   embed mode.

### Step 5 — Build + smoke-test

1. **⌘B** — the project should compile. If `RestTimerAttributes` is unresolved
   in `RestTimerLiveActivity.swift`, Step 3 wasn't completed correctly.
2. **⌘R** to run the app on a simulator. The Live Activity won't render on the
   simulator (Apple gates Dynamic Island visuals to physical hardware), but
   the code will silently fall back per RESEARCH §6 Pitfall 3 — no crash.
3. For visual verification of the lock screen + Dynamic Island, deploy to a
   physical iPhone 14 Pro or newer.

## File-by-file target membership table

| File | `fitbod` target | `FitbodWidgets` target |
|------|:---------------:|:----------------------:|
| `fitbod/Sessions/RestTimer/RestTimerAttributes.swift` | ✅ | ✅ |
| `fitbod/Sessions/RestTimer/RestTimerActivityController.swift` | ✅ | ❌ |
| `fitbod/Sessions/RestTimer/RestTimerLiveActivityBridge.swift` | ✅ | ❌ |
| `fitbod/Sessions/RestTimer/RestTimerEngine.swift` | ✅ | ❌ |
| `fitbod/Sessions/RestTimer/RestTimerNotificationScheduler.swift` | ✅ | ❌ |
| `FitbodWidgets/FitbodWidgetsBundle.swift` | ❌ | ✅ |
| `FitbodWidgets/RestTimerLiveActivity.swift` | ❌ | ✅ |
| `FitbodWidgets/RestTimerLockScreenView.swift` | ❌ | ✅ |
| `FitbodWidgets/Info.plist` | ❌ | (target's INFOPLIST_FILE) |
| `FitbodWidgets/FitbodWidgets.entitlements` | ❌ | (target's CODE_SIGN_ENTITLEMENTS) |
| `fitbod/fitbod.entitlements` | (target's CODE_SIGN_ENTITLEMENTS) | ❌ |

## Frameworks required by the widget extension target

- `WidgetKit.framework` — link, NOT embed (system framework)
- `SwiftUI.framework` — link, NOT embed
- `ActivityKit.framework` — link, NOT embed

When you select "Include Live Activity" in the Widget Extension template
(Step 1), Xcode adds all three automatically.

## When this manual step is complete

Plan `02-02`'s acceptance criterion #13 (the `PBXNativeTarget` for
`FitbodWidgets`) is satisfied. The remaining acceptance criteria are
already satisfied by the source files this plan checked in.

Plan `02-03` ("RestTimer integration façade") will then wire the
`RestTimerLiveActivityBridge` into `RestTimerEngine` via a new
`activityDelegate: RestTimerActivityControlling?` initializer parameter,
and the in-app overlay will compose with the Live Activity such that both
channels stay in sync. No further Xcode changes are required for plan
`02-03` — only Swift code.
