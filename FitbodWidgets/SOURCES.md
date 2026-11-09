# Widget extension source and resource membership

The existing `FitbodWidgetsExtension` target is embedded by `fitbod` in
`fitbod.xcodeproj`. No manual target creation or generated-stub replacement is
needed. This reference was reconciled against the project on 2026-11-08.

The extension compiles the widget bundle, Live Activity and Lock Screen/Island
views under `FitbodWidgets/`. Its synchronized membership also includes
`RestTimerAttributes`, shared BRU components, `Assets.xcassets` and the six
bundled fonts from `fitbod/`; `FitbodWidgets/Info.plist` registers those fonts
under `UIAppFonts`. App-side engine/controller/notification scheduling stays
in the app target. Check the project membership before changing shared files.

The app declares `NSSupportsLiveActivities`; the extension plist defines the
WidgetKit extension point. The invalid `com.apple.developer.usernotifications.live-activities`
entitlement was removed in `e72ae87e`; do not reintroduce it. Use the same
signing team for app and extension when installing on a physical iPhone.

Build the existing extension separately when changing it:

```sh
xcodebuild -project fitbod.xcodeproj -scheme FitbodWidgetsExtension \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/fitbod-widget-build \
  build CODE_SIGNING_ALLOWED=NO
```

The full test tier also builds it. Inspect the built `.appex` for `Assets.car`,
six `.ttf` files and `UIAppFonts` when resources change. The resource correction
shipped in `03199d32`; build/bundle success establishes packaging only.

[RM-008](../docs/ROADMAP.md#rm-008) retains installed Lock Screen/Island rendering
and rest lifecycle verification; [RM-007](../docs/ROADMAP.md#rm-007) retains the
unidentified repeated prompt. [RM-047](../docs/ROADMAP.md#rm-047) owns broader
physical denial/background/termination/VoiceOver checks. Record actual simulator
observations as simulator evidence; they do not close required phone checks.
[Archived implementation](../docs/archive/features/playtest-fixes.md#widget-resources-and-device-limits).
