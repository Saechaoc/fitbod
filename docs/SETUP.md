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

### Test tiers

`scripts/test.sh` runs the same tests in two tiers. Set `FITBOD_TEST_DEVICE` to
a dedicated simulator's UUID first.

| Tier | Command | Runs | Typical time |
|---|---|---|---|
| Developer feedback | `scripts/test.sh fast` | Incremental build, then every unit test in one serial process. Pass `-only-testing:` flags to run something else, such as one UI class. | About 30 s |
| Full verification | `scripts/test.sh full` | Build, unit tests serially, every UI class sharded over `FITBOD_TEST_WORKERS` simulators (default 2), widget build | About 55 to 60 min with 2 shards, against 98 min serially, when no UI test stalls |

The full tier keeps each guarantee of the serial run:

- Each shard is a serial run on its own simulator, so the tests in a class
  stay together and in order. The script creates the simulators for shards
  2 to N once, named `<device name> shard K`, using the same model and runtime.
- Before each run, every shard is booted, pinned to default text and light
  mode, and checked. Its app is then uninstalled, so no store is left over
  from an earlier run.
- Shards are split from `scripts/ui-test-timings.json`, longest first, so the
  same classes land on the same shard each time. A class missing from the
  file counts as the median. Refresh it from a full run without idle-wait
  stalls, because one stalled test would skew the balance:
  `python3 scripts/test_results.py timings <bundle> > scripts/ui-test-timings.json`.
- The run merges every bundle and fails unless the merged result ran exactly
  the tests the build enumerates: none missing, none extra, none run twice.
  `python3 scripts/test_results_test.py` checks that guard in under a second.
- Each worktree builds into its own DerivedData folder by default, so two
  worktrees running tests at once never test each other's build.
- Unit tests never run in parallel processes, and their host app starts
  from an uninstalled app in both tiers, so a store left by a UI run cannot
  change their result.
- A test command after which no test started (the runner hung or never
  bootstrapped) is retried once on the rebooted phone. A run in which any
  test started is never retried, so a flaky test stays red.

`-parallel-testing-enabled YES` is not used. xcodebuild reuses cached clones
whose text size can differ from the device's, and a trial run hung.

Keep two shards on the 12-core M4. With four, each full run failed one or two
tests that type text or close a sheet, a different test each time, all of
which pass serially. With two, the UI tests passed in all four runs. A test that
waits 60 seconds per step after typing (T101) still sets a shard's length, and
each shard's summary line counts those idle-wait stalls.

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
