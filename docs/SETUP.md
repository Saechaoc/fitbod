# Run the native app

Open `fitbod.xcodeproj` in Xcode, select the **fitbod** scheme, select an iPhone
Simulator, and Run. The project uses SwiftUI, SwiftData, Swift Charts and
ActivityKit, with no package-install step or account setup. The minimum target
is iOS 26.4. Development verification uses Xcode 26.5 and iOS 26.5 Simulator.
Those local toolchain versions were checked on 2026-11-08; use
`xcodebuild -version` and `xcrun simctl list runtimes` on another machine.
Agent workflow: [AGENTS.md](../AGENTS.md), [CLAUDE.md](../CLAUDE.md),
[development/testing policy](DEVELOPMENT.md), [conventions](../CONVENTIONS.md)
and [technical contracts](../ARCHITECTURE.md). Current work and acceptance
live only in [ROADMAP.md](ROADMAP.md).

For a physical iPhone, the app, `FitbodWidgetsExtension` and test targets inherit
the development team from the project's Debug/Release build settings. On another
developer's Mac, select their team at the project level, then choose the connected
device. Personal installation through Xcode is the milestone distribution path.

## Command-line build

```sh
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/fitbod-build \
  build CODE_SIGNING_ALLOWED=NO
```

The app already embeds `FitbodWidgetsExtension`; no new target is needed.
Its shared source/resource membership and standalone build command are in
[`FitbodWidgets/SOURCES.md`](../FitbodWidgets/SOURCES.md). A successful build
or resource inspection does not prove installed Lock Screen/Island rendering;
that observation remains [RM-008](ROADMAP.md#rm-008).

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

`scripts/test.sh` offers unit feedback and full verification. Set `FITBOD_TEST_DEVICE` to
a dedicated simulator's UUID first.

| Tier | Command | Runs | Typical time |
|---|---|---|---|
| Developer feedback | `scripts/test.sh fast` | Incremental build, then every unit test in one serial process. Pass `-only-testing:` flags to run something else, such as one UI class. | About 35 s; 70 to 90 s right after UI tests or a cold build |
| Full verification | `scripts/test.sh full` | Build, unit tests serially, every UI class sharded over `FITBOD_TEST_WORKERS` simulators (default 2), widget build | About 14 min with 2 shards; the UI target alone takes 23 min serially |

Routine checks belong to the agent; a feature needs no personal sign-off when
its agreed scope, appropriate checks and docs are complete. Run the unit target
for app changes and affected existing UI checks for changed routes/interactions
or stored data. New prototype UI tests protect data; copy/styling uses simulator
inspection. Documentation-only changes run their relevant checkers. Exact effort,
stability and release triggers are in [DEVELOPMENT.md](DEVELOPMENT.md).

To include both the unit target and one affected UI suite:

```sh
scripts/test.sh fast -only-testing:fitbodTests -only-testing:fitbodUITests/WorkoutExitUITests
```

Both tiers reset their dedicated installation. For a persistence journey, the
test resets only on its initial launch and omits reset on subsequent relaunches.
The full tier pins default text/light mode, so it does not prove dark/AX3 or
the two-phone release matrix. Run those configurations explicitly when their
stability/release trigger is reached.

The full tier keeps each guarantee of the serial run:

- Each shard is a serial run on its own simulator, so the tests in a class
  stay together and in order. The script creates the simulators for shards
  2 to N once, named `<device name> shard K`, using the same model and runtime.
- Before each run, every shard is booted, pinned to default text and light
  mode, and checked. Its app is then uninstalled, so no store is left over
  from an earlier run.
- Both tiers also delete the backups UI tests saved to On My iPhone, named
  `fitbod-t41-` or `fitbod-backup-` and 8 characters, which an uninstall
  keeps. The Files picker shows only the first dozen, so leftovers hid the
  backup a test had just saved. A backup with the app's dated name stays.
- Shards are split from `scripts/ui-test-timings.json`, longest first, so the
  same classes land on the same shard each time. A class missing from the
  file counts as the median. The file comes from Gate 4's serial run on
  2026-11-01. Refresh it from a full run without idle-wait stalls, because
  one stalled test would skew the balance:
  `python3 scripts/test_results.py timings <bundle> > scripts/ui-test-timings.json`.
- The run merges every bundle and fails unless the merged result ran exactly
  the tests the build enumerates: none missing, none extra, none run twice.
  `python3 scripts/test_results_test.py` checks that guard in under a second.
- Each worktree builds into its own DerivedData folder by default, so two
  worktrees running tests at once never test each other's build.
- Unit tests never run in parallel processes, and their host app starts
  from an uninstalled app in both tiers, so a store left by a UI run cannot
  change their result.
- The unit tests' host app can hang for about 5.5 min before it connects
  ("test daemon not ready") when it is the first test launch after UI tests
  on the same phone. So when the UI test runner is installed, a run that
  launches the host reboots the phone first, which costs about 20 s.
- A test command after which no test started (the runner hung or never
  bootstrapped, as Gate 4's unit run did on 2026-11-01) is retried once on
  the rebooted phone, and test enumeration up to twice. A run in which any
  test started is never retried, so a flaky test stays red.
- Every UI test gets a 7-minute allowance, 15 at most, so a hung test fails
  instead of stalling its shard.

`-parallel-testing-enabled YES` is not used. xcodebuild reuses cached clones
whose text size can differ from the device's, and a trial run hung.

Two shards are the tested default on the 12-core M4 Pro. On 2026-10-31,
before T101's keyboard fix and T143's cut, four
shards failed one or two tests that type text or close a sheet in each full
run, a different test each time, all of which pass serially; two shards passed
all four runs. Try more shards only with three clean full runs.
Each shard's summary line counts idle-wait stalls, the 60-second
waits after typing that T101 removed, so a returning stall shows.

### Captures and phone installs

`scripts/shot.sh <name> [launch args]` captures one seeded state on the dedicated 390pt simulator, in light and in dark, into the ignored `.ci/shots/`.
Set `FITBOD_SHOT_DEVICE` to that simulator's UUID first.
It launches on an empty store with the launch arguments you pass, for example `scripts/shot.sh today-resume -fitbod-seed-demo-workout`.
It builds into the DerivedData folder `scripts/test.sh` uses, so a capture after a test run is an incremental build; do not run it while tests run from the same worktree.
A state behind a tap, such as a sheet, needs the simulator driven by hand.

`FITBOD_PHONE=<udid> scripts/phone.sh` builds Debug for a connected iPhone and installs it over the existing app, which keeps its data.
The id is the hardware UDID that `xcodebuild -showdestinations` prints; keep it out of the repository.
The script does not launch the app, because iOS refuses a launch from the Mac while the phone is locked.

### Local simulator reuse

Reuse existing dedicated test devices across tasks and worktrees by default.
One or two booted devices will usually cover local work. Boot or create more
when concurrent runs, isolation or required model/runtime coverage needs them;
there is no hard device limit. Dedicated means disposable test data, not
permanent ownership by one task. Never use a simulator containing personal
workout data.

Only one run may use a device at a time, including tests, captures and manual
inspection: the scripts reset the installed app and its data. Reuse the same
UUID for sequential unit and UI tests in either worktree. If it is busy, wait
or use another dedicated device.
Keep each worktree's separate DerivedData directory. The test runner already
reboots a reused device when the unit host needs it after UI tests.

Reuse the existing iPhone 17e for 390pt checks and existing matching shard
devices for full runs. Shut down idle extras after use; shutdown does not erase
data. Coordinate device use between runs; the scripts do not lock devices.

## First launch and offline use

The bundled seed v3 has **901 source records**, of which **703** are eligible for import:
strength, powerlifting, Olympic weightlifting and strongman. The seed includes
27 local Panatta machine additions and Single-Leg Kneeling Leg Curl.
These are bundled-data counts, not a guarantee of the size of an installed
library with custom/archived exercises. Importing happens off the main thread on
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
history through **Progress → Workouts**. Settings opens
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
A store is moved aside only when Core Data reports that it cannot infer a
migration to the current schema.
Any other failed open, such as an unreadable or damaged file, leaves the store
files in place and shows the "Training data did not open" screen
([RM-001](ROADMAP.md#rm-001)).
Its Try again button opens the same store again.
Prove populated backup/recovery ([RM-029](ROADMAP.md#rm-029)) before
schema-changing work; move-aside preservation is not a tested restore or
migration promise.

The DEBUG-only `-fitbod-reset-store` launch argument deletes the active store
files, clears the app's saved defaults, seed stamps included, and removes the
app's pending and delivered notifications.
It is for dedicated test simulators. Normal
launches do not reset data. Do not pass this argument when verifying relaunch.

`-fitbod-seed-demo-workout` adds deterministic active and finished workouts for
isolated UI checks. The full authored journey uses no demo workout. Both launch
arguments are restricted to DEBUG builds.

Every Today state opens from one DEBUG launch argument on an empty store.
`fitbod/App/TodayStatesSeed.swift` lists `-fitbod-seed-today-ready`, `-empty`, `-done`, `-rest`, `-attach` and `-pick`.
The scheduled session is `-fitbod-seed-block-states`, the open workout is `-fitbod-seed-demo-workout`, and the first-run state needs no seed.

## Evidence

Record the tested commit, configuration, commands, results and limitations in
the relevant [roadmap entry](ROADMAP.md). Download CI logs and screenshots from
the Actions run's `fitbod-ci-<sha>` artifact, retained for 14 days; local CI runs
write to ignored `.ci/`. Keep detailed output there rather than committing
reports or screenshot bundles.
Archive finished substantial implementation plans in `docs/archive/features/`
with historical scope/build/results and an RM backlink. A required unavailable
phone check stays explicit in the roadmap as **Implemented; verification pending**;
the archive does not close it or block unrelated work.

Exploratory UI smoke tests do not establish a complete workout journey.
[Release checks](ROADMAP.md#rm-048) require explicit assertions for logging,
relaunch and completed history across the required configurations.
