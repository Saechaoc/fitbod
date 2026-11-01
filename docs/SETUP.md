# Run the native app

Open `fitbod.xcodeproj` in Xcode, select the **fitbod** scheme, select an iPhone
Simulator, and Run. The project uses SwiftUI, SwiftData, Swift Charts and
ActivityKit, with no package-install step or account setup. The minimum target
is iOS 26.4. Development verification uses Xcode 26.5 and iOS 26.5 Simulator.

For a physical iPhone, select your signing team for the app and
`FitbodWidgetsExtension` targets, then choose the connected device. Personal
installation through Xcode is the milestone distribution path.

## Command-line build

```sh
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/fitbod-build \
  build CODE_SIGNING_ALLOWED=NO
```

To run tests, first choose an available simulator with `xcrun simctl list devices
available`. Replace `SIMULATOR_ID` with its UUID:

```sh
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

Serial test execution is deliberate: UI tests manipulate an installed app and
some legacy suites exercise shared defaults. Run UI scenarios on a dedicated
test simulator so normal personal workout data is not affected.

## First launch and offline use

The bundled catalog has **900 source records**, of which **702** are imported:
strength, powerlifting, Olympic weightlifting and strongman. The seed includes
27 local Panatta machine additions. Importing happens off the main thread on
first launch; wait for the preparation screen to disappear.

Search, muscle/equipment filtering, instructions, custom exercises, routines,
set logging, workout history and rest deadlines use local data. No login,
backend or network connection is required for the workout journey. Optional
remote exercise imagery is not required to log a workout.

Catalog provenance, the pinned upstream revision and refresh procedure:
[`ExerciseSeed/SOURCE.md`](../fitbod/Resources/ExerciseSeed/SOURCE.md).
When expanding it, preserve the local additions and stable external IDs,
validate decoding, and verify reseeding against an existing store. Adding new
exercise categories may also require duration/distance inputs; this is roadmap
work, not a JSON-only change.

## Review the visual system

DEBUG build: **Today → Settings → Developer → Component gallery**. The gallery
uses real native controls; its inputs and actions only change sample state.
Open individual `fitbod/Design/*.swift` files for SwiftUI previews. The gallery
has normal, dark and accessibility-size previews.

The four tabs are **Today, Program, Progress, Library**. Open completed workout
history through **Today → Sessions** or **Progress → Workouts**. Settings opens
from the Today header. A UI routine is a `Split`; its sessions are
`SessionTemplate` records. The logger and software keyboard hide the tab bar.

Weight units currently change labels only. Saved numeric loads are not
converted when you switch units; an exercise's unit override takes priority.
Keep one unit convention for existing data until conversion and per-set unit
provenance are implemented.

[`design-system/README.md`](design-system/README.md) indexes concrete color,
typography, layout, iconography, interaction and accessibility rules.
[`CORE-SCREENS.md`](CORE-SCREENS.md) maps the reference designs to actual screens
and specifies their states and interactions.

## Persistence

`FitbodModelContainer` opens a local SQLite-backed SwiftData store using the
current baseline `SchemaV7`. Workout instances copy names, prescription and
sets when started. Later template edits do not rewrite those snapshots. An
unfinished workout is recovered from the store after relaunch; the timer uses
a session-keyed absolute deadline persisted in UserDefaults.

An incompatible store is moved, with its SQLite siblings, to
`Application Support/IncompatibleStores/<timestamp>/` before a fresh store is
created. This preserves the old files but does not convert their contents.
Compatible additive changes open in place. Settings offers backup and export.

The DEBUG-only `-fitbod-reset-store` launch argument moves the active store
aside, clears seed stamps, and removes the app's pending and delivered
notifications. It is for dedicated test simulators. Normal
launches do not reset data. Do not pass this argument when verifying relaunch.

`-fitbod-seed-demo-workout` adds deterministic active and finished workouts for
isolated UI checks. The full authored journey uses no demo workout. Both launch
arguments are restricted to DEBUG builds.

## Evidence

See [`VERIFICATION.md`](VERIFICATION.md) for recorded commands, results and
screenshots. Existing exploratory UI smoke tests are not sufficient evidence
of a complete workout journey; the milestone requires explicit assertions for
logging, relaunch and completed history.
