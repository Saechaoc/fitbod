# Test performance guide

This guide says where the fitbod test suite spends its time, what to do and not do when writing tests, and which changes pay off first.
It comes from an audit on 2026-10-31 of the repository, its result bundles, its CI history and a few small profiling runs.
It changes no code.
Every change in it is a proposal for later work.

Each claim carries one of three labels.
**Measured** means a number from a result bundle, a log or a run made for this audit.
**Hypothesis** means the code supports it but nobody has timed it yet.
**Unknown** means the evidence does not exist and the guide says how to get it.

Conditions for every local number: Apple M4 with 10 cores and 32 GB, macOS 26.4.1, Xcode 26.5 (17F42), the iOS 26.5 runtime, the dedicated `sw6 iPhone 17 Pro Max` simulator, Debug, `-parallel-testing-enabled NO` unless stated.
CI numbers come from GitHub Actions on `macos-26`, which GitHub documents as 3 vCPU (M1), 7 GB of memory and 14 GB of disk.

## 1. Diagnosis

### 1.1 What the suite is

The scheme `fitbod.xcodeproj/xcshareddata/xcschemes/fitbod.xcscheme` has one auto-created test plan with two testables, both with `parallelizable = "NO"`.

| Target | Framework | Files | Lines | Tests | Host |
| --- | --- | --- | --- | --- | --- |
| `fitbodTests` | Swift Testing only (no `XCTestCase`) | 189 | 33,480 | 1,170 `@Test` declarations in 189 `@Suite`s; a run reports 1,118 tests in 188 suites | App-hosted: `TEST_HOST` and `BUNDLE_LOADER` point at `fitbod.app` |
| `fitbodUITests` | XCTest with `XCUIApplication` | 58 | 11,122 | 202 `func test` methods in 55 classes | `TEST_TARGET_NAME = fitbod` |

Measured facts about the unit target: 103 suites carry `.serialized` across 92 files, 124 files use `@MainActor`, 65 files build a `FitbodModelContainer.make(inMemory: true)` container, 45 files (8,211 lines) are source-introspection tests that read Swift files and check strings, 6 files touch `UserDefaults`, 2 use disk stores, 7 render views through UIKit or `ImageRenderer`, and 3 use `.timeLimit`.
Four unit tests sleep: `Task.sleep` for 1 s in `fitbodTests/NewBlockBuilderFidelityTests.swift`, 50 ms twice in `fitbodTests/BRUCompositePrimitivesTests.swift` and 100 ms in `fitbodTests/RestTimerActivityControllerTests.swift`.

Measured facts about the UI target: 501 `waitForExistence` call sites, 48 `waitForNonExistence`, 135 `hittable(`, 113 `reveal(`, 445 `.tap()`, 142 calls to the shared launch helpers, 25 raw `XCUIApplication()` launches, 13 `relaunch(` calls, 17 long presses, 46 screenshots, 161 attachments (18 kept always), 11 OCR reads through Vision, 25 pixel-color assertions, 11 `Thread.sleep` sites, one `sleep(6)`, and 39 launches at a non-default text size in 11 files that cover AX3.
23 of the 58 files assert layout or accessibility sizes.
The target grew from 55 tests on 2026-10-28 (the Phase 0 baseline in `docs/conway-specs/assumptions.md`) to 202 today: 33 of the 58 files landed between 2026-10-28 and 2026-10-30.

There are no SPM packages, no script build phases and no `.xctestplan` files.
Debug builds use `-Onone`, incremental compilation and `ONLY_ACTIVE_ARCH = YES`.
The app target compiles under Swift 6 with complete concurrency checking; both test targets use Swift 5 mode.

### 1.2 What "200+ minutes" most plausibly measures

No recorded run reaches 200 minutes.
The runs on record:

| Run | Scope | Elapsed | Label |
| --- | --- | --- | --- |
| Local Phase 0 baseline, 2026-10-28, large phone | 1,026 tests, 55 of them UI | 15.8 min | Measured (`docs/conway-specs/assumptions.md`) |
| Local, 2026-10-29, large phone | `NoteSheetsUITests` (5 UI tests) plus 31 unit tests | 2.9 min; the 5 UI tests took 11, 18, 30, 36 and 43 s | Measured (result bundle under `DerivedData/fitbod-m1-orca/Logs/Test`) |
| CI, 13 runs on 2026-10-04, branch `claude/nifty-hypatia-yassxj` | build, unit (275 tests then), UI bundle on two phones (4 tests per phone then) | mean 30.1 min, max 55.8 min | Measured (`gh run list`, `gh api .../jobs`) |
| Local, this audit | unit target alone | 36 s wall, 22.0 s of test execution | Measured |

The arithmetic that gets to 200 minutes is this.
The Phase 0 baseline spent about 14.5 of its 15.8 minutes on 55 UI tests, which is about 16 s per UI test on the M4.
The five `NoteSheetsUITests` tests, written after the baseline, average 27.6 s each.
The 24-test sample from six October suites, run for this audit, averages 25.6 s per test (section 1.6).
At 16 to 28 s per test, the 202 UI tests of today need 54 to 93 minutes per phone on the M4, serially.
Running the bundle on both dedicated phones in sequence, as the verification tickets ask, needs 108 to 186 minutes, and a third pass at AX3 or a rerun of a failing suite takes it past 200.
On CI the same bundle runs on both phones inside one sequential job, on a runner with 3 vCPUs, so the elapsed time and the cumulative job time are the same number and it would be larger than the local one.
The runner's per-action cost is unmeasured for the current suites; if it is 1.5 to 2 times the M4's, the job needs 160 to 370 minutes and never finishes inside its `timeout-minutes: 120`.

So the most plausible reading is: **elapsed time of the full UI bundle run serially on both phones**, either locally or in the single CI job.
It is not compile time (31 s cold) and not unit test time (22 s).
This is a hypothesis.
Section 5 says how to replace it with a measured number in one run.

### 1.3 Where the time goes (measured)

**Build and simulator.**
A cold `build-for-testing` into an empty DerivedData takes 31 s on the M4; a warm rebuild with no change takes 1 s.
On CI the build step took 1.1 min.
Booting the dedicated simulator and waiting for `bootstatus` took 7 s locally.

**Unit target.**
1,118 tests in 188 suites ran in 22.0 s of execution and 36 s of `xcodebuild` wall time, with one known issue.
The sum of all case durations is 0.4 min and the median case takes about 0.02 s.
The four slowest cases are the only ones that matter:

| Case | Duration | Why |
| --- | --- | --- |
| `NewBlockBuilderFidelityTests` "Phase card titles and subtitles render in full on 390–402pt iPhones" | 7.0 s | Hosts `BlockBuilderView` in a window three times, sleeps 1 s each time, then runs Vision OCR at `.accurate` |
| `SeedTests` (suite "ExerciseLibraryImporter") | 4.3 s for the suite, 0.6 to 0.7 s per test | Each test imports the 702-exercise catalog into an in-memory store |
| "Indexed queries" | 0.9 s and 0.6 s | Builds large fixtures |
| `IncompatibleStoreRecovery` (a) | 1.0 s | Writes and moves a disk store |

Enabling `-parallel-testing-enabled YES` for the unit target made the run slower: 51 s instead of 36 s, because xcodebuild created "Clone 1 of sw6 iPhone 17 Pro Max" and ran the whole target in it.
Execution time was the same.

**UI target, anatomy of one test.**
`NoteSheetsUITests/testPinnedNoteSavesOnlyOnSave()` took 42.9 s on 2026-10-29.
Its top-level activities, from the result bundle:

| Activity | Time | Count in this test |
| --- | --- | --- |
| "Open bodybuilding.fitbod" (launch with `-fitbod-reset-store`, which deletes the store, then the catalog import, until the Today tab exists) | 5.0 s (5.4 s in the sibling test) | 1 |
| `waitForExistence` on an element that was already on screen | 1.0 to 1.1 s each | 9 |
| A tap, almost all of it "Wait for bodybuilding.fitbod to idle" | 1.1 to 2.8 s | 6 |
| A 1.2 s long press | 1.8 to 2.0 s | 4 |
| A short press then drag | 4.0 s | 1 |
| `exists` or a plain query | under 0.1 s | many |

Launch plus the nine satisfied waits are a third of the test.
The actions the test is about, the taps and presses, are another third.
Nothing in the test is slow for a reason the test needs.

**CI, per step (2026-10-04, run 37217658793 and its siblings).**

| Step | Time | Note |
| --- | --- | --- |
| Create simulators | up to 9.6 min on a fresh runner | Runtime download and device creation |
| Build for testing | 1.1 min | Generic simulator destination, `ARCHS=arm64` |
| Unit tests | 4.3 to 7.5 min | The 275 tests of that day executed in 0.3 min; 4 to 5 min is boot, `bootstatus`, install, a warm-up launch with `sleep 15`, test-host start and bundle writing |
| UI, large phone | 9.7 to 17.8 min | Four tests then: `WorkoutJourneyUITests` 249 to 282 s, `LayoutAuditUITests` tours 143 to 215 s |
| UI, small phone | 3.0 to 29.0 min | Same four tests |
| Collect evidence | 0.5 min | `scripts/ci/collect_evidence.py` flattens the bundle and downsizes attachments |

The workflow has run only on `claude/**` branches and pull requests, and the last run was 2026-10-04.
Nothing has run on `main`, where all work since then has landed.

### 1.4 Code-supported hypotheses, ranked by expected size

1. **Every launch resets the store and re-imports the catalog.**
   `UITestNavigation.launch` passes `-fitbod-reset-store` for `freshStore` and `seededWorkout`; `DebugLaunchReset.reset` deletes the store files and the whole defaults domain; `RootView.runSeed` then runs `ExerciseLibraryImporter.seedIfNeeded`, which decodes the 1.0 MB `fitbod/Resources/ExerciseSeed/exercises.json`, inserts 702 exercises, 17 muscle groups and their stimulus rows in 100-row batches, and the plate, stimulus and volume seeders.
   The launch helpers are called 142 times, `relaunch` 13 times and raw `XCUIApplication()` 25 times, so one bundle run launches about 180 times at 5 to 6 s each on the M4: 15 to 18 minutes per phone of launching.
   A launch that keeps the catalog should cost 1 to 2 s (unknown; the relaunch path measures it).
2. **Satisfied waits cost about a second each.**
   501 `waitForExistence` sites, and the measured 1.0 to 1.1 s even when the element is already there, put this at 5 to 10 s per test, or 15 to 30 minutes per phone per run.
3. **Animations run during tests.**
   No `UIView.setAnimationsEnabled(false)`, no launch argument that disables animations and no root `.transaction` exists in `fitbod/`.
   Each tap waits for the app to idle after the sheet, push or scroll animation, which is most of the 1.1 to 2.8 s per tap.
4. **Template tests are pure cost.**
   `fitbodUITests/fitbodUITests.swift` has `testExample`, which launches and asserts nothing, and `testLaunchPerformance`, which launches five times inside `measure` with no baseline, so it can never fail.
   `fitbodUITests/fitbodUITestsLaunchTests.swift` sets `runsForEachTargetApplicationUIConfiguration = true`, so `testLaunch` runs once per orientation and appearance combination and keeps a screenshot each time; the comment in `UITestNavigation.launch` notes that it leaves the phone in landscape.
5. **CI runs everything in one sequential job on both phones.**
   Elapsed time equals the sum of the steps.
   A build job plus a matrix of three test jobs would make elapsed time the longest step, for about three extra runner setups of compute.
6. **Both phones run every UI test.**
   `scripts/ci/ios-ci.sh ui small` and `ui large` both pass `-only-testing:fitbodUITests`, but only 23 of the 58 files assert layout or text sizes.
7. **CI has no test timeouts and no `-collect-test-diagnostics never`.**
   `run_tests` in `scripts/ci/ios-ci.sh` passes neither, so a hung test runs until the 120-minute job limit, and `docs/SETUP.md` records that a run with any failure waits up to ten minutes in `simctl diagnose` without the flag.
8. **The unit target launches the whole app before the first test.**
   `fitbodApp.init` runs `DebugLaunchReset.runIfRequested()` and opens the real store, and `RootView` seeds the catalog into it on the simulator; the tests then build their own in-memory containers.
   Measured wall time minus execution time is 14 s, part of it this launch.
9. **`.serialized` and `@MainActor` are applied broadly without stated reasons.**
   Of 103 `.serialized` suites, `SeedTests` is one of the few with a comment explaining it: the importer reads and writes `UserDefaults.standard`, which is process-wide.
   `PlateInventorySeeder` does the same.
   This blocks safe in-process parallelism, though in-process parallelism gains little today because execution is only 22 s.
10. **Width-insensitive work is repeated across text sizes.**
    39 launches pin a non-default text size; the 11 AX3 files rerun whole journeys at the larger size.
    That is the right test for layout, and the wrong test for copy or data assertions, which do not change with text size.

### 1.5 Unknowns

- Whether anyone measured 200 minutes, on which machine, and with which command.
  Ask for the result bundle or the terminal log; the measurement plan below produces one in a single run.
- The cost of a launch without the reset flag, and so the exact saving of hypothesis 1.
  `relaunch` measures it: read its "Open bodybuilding.fitbod" activity from any journey test's result bundle.
- Whether the scheme setting `parallelizable = "NO"` or `-parallel-testing-enabled NO` also turns off Swift Testing's in-process parallelism.
  Apple documents that `.serialized` has no effect when parallelization is disabled globally, but not which xcodebuild switch does that.
  The two unit runs showed the same 22 s of execution either way, so the answer changes nothing today.
- The per-test cost on the CI runner for the suites written in October.
  No CI run exists since 2026-10-04 because the workflow does not trigger on `main`.
- Whether clone-parallel UI runs are stable for the whole bundle on the M4.
  The 24-test sample (section 1.6) ran 2.25 times faster on four clones, with one failure in a file-picker test that passed serially; the full bundle is untested.

### 1.6 Profiling runs made for this audit

All runs used a scratch `-derivedDataPath`, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO` and `-collect-test-diagnostics never`.

| Run | Result |
| --- | --- |
| `build-for-testing`, cold, generic simulator destination | 31 s |
| `build-for-testing`, warm, no change | 1 s |
| Boot `sw6 iPhone 17 Pro Max` and wait for `bootstatus` | 7 s |
| Unit target, `-parallel-testing-enabled NO` | 36 s wall, 22.0 s execution, 1,118 passed, 1 known issue |
| Unit target, `-parallel-testing-enabled YES` | 51 s wall, same execution, ran on a clone |
| 24 UI tests from six suites, serial | 632 s wall (10.5 min); 24 passed; case durations sum to 614 s, mean 25.6 s, min 10 s, max 57 s (`PrescriptionEditorUITests/testHoldingAnRPEChipSetsADecimalTarget`) |
| The same 24 UI tests, `-parallel-testing-enabled YES -parallel-testing-worker-count 4` | 281 s wall (4.7 min), 2.25 times faster; 23 passed and 1 failed: `SettingsExportUITests/testRestoreAsksBeforeReplacingData` ("Files must close after saving"), which passed serially; mean case 27.9 s, 9 percent slower per case; xcodebuild hands whole classes to clones, so the four-test `PrescriptionEditorUITests` class set the floor of its clone |
| `build-for-testing`, cold, with `-showBuildTimingSummary` | 30 s wall; the summary attributes 178.9 s of task time to `SwiftCompile` (42 tasks) and 12.6 s to `SwiftEmitModule` (4 tasks), and under 3 s to everything else, so the cold build is compile-bound, parallel, and not worth optimizing |

The six sample suites were `NoteSheetsUITests`, `SkipWarmupsUITests`, `PrescriptionEditorUITests`, `SettingsExportUITests`, `WhyThisWeightSheetBRUUITests` and `BodySilhouetteUITests`.

## 2. Do and don't

Each rule says what to do, what to avoid, why, when the rule does not apply, and how to check that you followed it.
The rules use fitbod's own files as examples.

### 2.1 Pick the cheapest test that proves the behavior

**Do.**
Prove a rule in the unit target when the rule lives in a model, a service or a pure function: progression math, `TodayResolver`, `BlockLifecycleService`, exporters, seeders.
Prove a view's content in the unit target too, by hosting the view in a `UIHostingController` the way `NewBlockBuilderFidelityTests` does, or by rendering it with `ImageRenderer`.
Keep a UI test for what only the running app shows: a route is reachable, a sheet dismisses, a tap on a real control reaches the store, the keyboard appears, the app survives a relaunch.

**Don't.**
Don't write a UI test whose only assertion is that a label exists or a string reads a certain way.
`WhyThisWeightSheetBRUUITests.testWhyThisWeightSectionHeadVisible` opens the seeded workout, reveals the WHY control, opens the sheet and checks one heading; the heading's copy is already covered by `fitbodTests/PrescriptionExplanationTests.swift` and the sheet's inputs by `fitbodTests/WhySheetInputsTests.swift`.

**Why.**
A unit case costs about 0.02 s here (median, measured).
A UI case costs 11 to 43 s (measured) because it launches the app, imports the catalog and waits for animations.
That is a factor of 500 to 2,000 for the same assertion.

**Exceptions.**
Keep one journey per screen that proves the screen is reachable and wired, even if every assertion in it has a unit twin.
Keep layout tests that need the real window size and text size, since a hosted view can fake a width but not the whole phone's safe areas and tab bar.

**Verify.**
For each new UI test, name the behavior that a hosted-view or model test could not prove.
If you cannot name one, it is a unit test.

### 2.2 Test logic without the UI or the app host

**Do.**
Put logic in types that take their inputs as parameters: `TrainingDaysWriter` takes a `Calendar`, `FitbodModelContainer.make` takes `defaults:` and `storeURL:`, and `ExerciseLibraryImporter.seedIfNeeded` takes a `Bundle`.
Build the smallest fixture that exercises the rule: a few `Exercise` rows in an in-memory container, not the catalog.

**Don't.**
Don't reach for `@Query`-driven views, `RootView` or the app's shared container from a unit test.
Don't import the 702-exercise catalog to test a function that needs three exercises.

**Why.**
`SeedTests` pays 0.6 to 0.7 s per test for the import; tests with hand-made rows pay milliseconds.
A test that depends on the running app also depends on the app's launch state, which the host launches once per process and nobody controls.

**Exceptions.**
The importer's own tests need the real catalog, and they are the right place to assert its count and taxonomy.
Keep those, and keep them few.

**Verify.**
`rg -n "ExerciseLibraryImporter\(" fitbodTests` lists every test that imports the catalog.
Each one should be about the importer.

### 2.3 Expensive setup and fixtures

**Do.**
Build fixtures inside the test or in a small helper, and keep them minimal.
Share expensive read-only inputs at the suite level only when they are immutable: a decoded JSON array, a parsed source file for the introspection suites.
For the UI target, start from the smallest seeded state the test needs: `freshStore` for an empty app, `seededWorkout` when the test is about a workout.

**Don't.**
Don't make the catalog import part of every UI launch.
Today `-fitbod-reset-store` deletes the store files and the defaults domain, so the next launch re-imports everything; that is 3 to 4 s of the 5 to 6 s launch (hypothesis, from the launch activity and the import's work).
Don't share a mutable SwiftData container between tests; it hides ordering bugs and forces `.serialized`.

**Why.**
Setup time multiplies by test count.
About 180 launches per bundle run times 4 s is 12 minutes per phone.

**Exceptions.**
A test about the first launch itself, the "Preparing library…" splash, or an incompatible store needs the full reset and should ask for it by name.

**Verify.**
The result bundle's activity tree shows "Open bodybuilding.fitbod" per test; its duration is the setup cost.
Track it in the slowest-activities list from section 5.

### 2.4 Network, database, file system, defaults, system frameworks

fitbod has no network, no auth and no analytics, so this rule is about the store, the file system, `UserDefaults` and system frameworks.

**Do.**
Use `FitbodModelContainer.make(inMemory: true)` for every test that needs a store, as 65 files already do.
Use a disk store only to test disk behavior: `IncompatibleStoreRecovery` and the backup round trip.
Give each test its own `UserDefaults(suiteName:)` and remove the suite at the end.
Keep ActivityKit, Vision and UIKit rendering behind small seams so a test can skip them; `RestTimerActivityControllerTests` already uses a `StubScheduler`.

**Don't.**
Don't read or write `UserDefaults.standard` in code a test exercises.
`ExerciseLibraryImporter.seedIfNeeded` and `PlateInventorySeeder.seedIfNeeded` do, so `SeedTests` must clear the stamp before every test and must be `.serialized`.
Don't run Vision at `.accurate` where a `.fast` pass or an accessibility read answers the question.

**Why.**
Process-wide state is why suites need `.serialized`, and serialized suites cannot overlap with their own tests.
A disk store costs about 1 s per test for file moves and SQLite setup (measured on `IncompatibleStoreRecovery`).

**Exceptions.**
The two disk-store suites and the backup tests are the point of the disk.
Vision is the right tool for a "does this text get cut off" check that no accessibility API answers.

**Verify.**
`rg -n "UserDefaults.standard" fitbod fitbodTests` should list only code that cannot take an injected `UserDefaults`.
Today it lists the two seeders and their tests.

### 2.5 Deterministic injection: stubs and clocks

**Do.**
Inject the clock, the calendar and the scheduler, and default the parameter to the production value, as `TrainingDaysWriter` and `FitbodModelContainer.make(defaults:)` do.
Drive time by passing a `Date`, not by waiting for one to arrive.

**Don't.**
Don't sleep to let a timer fire.
`RestTimerActivityControllerTests` sleeps 100 ms; a stubbed scheduler can deliver the tick synchronously.

**Why.**
A stubbed clock makes the test instant and makes it fail for one reason only.

**Exceptions.**
The one test that checks the real rest timer keeps counting in the background (`WorkoutLoggerJourneyUITests`, the `sleep(6)` site) is about elapsed wall time and may sleep, with a comment that says so.

**Verify.**
A test that passes a `Date` or a `Calendar` should not also call `Date.now` or `Task.sleep`.

### 2.6 Sleeps, polling, expectations and timeouts

**Do.**
Wait on a condition, with a timeout that is a ceiling, not a duration: `XCTNSPredicateExpectation` with `XCTWaiter`, as `UITestNavigation.selectTab` and `type` do, or `waitForExistence` when the element may still be arriving.
Check `exists` first when the element is probably already there, then fall back to the wait.
Poll in small steps, 50 to 100 ms, when you must poll.

**Don't.**
Don't sleep a fixed time and hope: the 1 s `Task.sleep` in `NewBlockBuilderFidelityTests.recognizedText(inBuilderOfWidth:)` costs 3 s of its 7 s.
Don't poll in 0.5 s steps (`hittable`) or 1 s steps (`HeatmapHitAreaUITests` waits for the scroll bar to fade by comparing screenshots once a second).
Don't call `waitForExistence` on an element you just asserted; each call costs about 1 s even when it returns true (measured).

**Why.**
A fixed sleep is always either too long or flaky.
A satisfied `waitForExistence` still costs about a second here, 501 times per bundle.

**Exceptions.**
A wait that proves something takes time, such as a 1.2 s long press, is the behavior under test.
A small settle after a chart transition before a screenshot is acceptable when the assertion is a pixel read; name the reason in a comment and keep it under 0.5 s.

**Verify.**
`rg -n "Thread.sleep|Task.sleep|sleep\(" fitbodTests fitbodUITests` should list only sites with a comment that names the reason.
Today it lists 15.

### 2.7 UI tests: navigation, launches, queries, animations, state

**Do.**
Launch once per test, through `UITestNavigation.launch`, with the smallest state the test needs.
Navigate by accessibility identifiers (`set.reps.1.S1`, `resumeSlab.resume`), which are exact and cheap, over label predicates with `CONTAINS`, which scan the tree.
Disable animations for the test launch through a DEBUG launch argument, except in the tests listed under exceptions.
Reuse one launch for several assertions on the same screen when the assertions do not change state.
Take screenshots only where a human will look at them: journeys and layout audits.

**Don't.**
Don't launch more than once per test unless the test is about relaunching.
Don't `reveal` by swiping a page at a time when the target has an identifier and `scrollViews` can scroll to it; `reveal` swipes up to 12 times at slow velocity.
Don't attach `.keepAlways` screenshots on tests that assert nothing visual; `fitbodUITestsLaunchTests` keeps one per UI configuration.
Don't rely on `runsForEachTargetApplicationUIConfiguration`; it multiplies the test by every orientation and appearance in the plan.

**Why.**
Launch is 5 to 6 s, each animated transition 1 to 3 s, each slow swipe about a second.
A bundle with 445 taps and 113 reveals spends minutes on animation and swiping.

**Exceptions.**
Layout audits and anything that reads pixels or OCR need animations finished, not disabled; `waitUntilStill` covers them.
The tests that check a scroll bar fades or a chart transition settles are about animation and keep it on.

**Verify.**
Read the test's activity tree in the result bundle.
Every row that is not a tap, a type or an assertion is overhead to explain.

### 2.8 Snapshot, OCR and parameterized multiplication

**Do.**
Parameterize over the inputs that change the outcome.
`phaseCardTextRendersInFullOnNarrowPhones` checks three widths because the bug was width-specific; that is the right multiplication.
Run OCR once per screen and assert several strings from the one read.

**Don't.**
Don't rerun a whole journey per text size to check one screen's layout; launch straight to the screen at that size.
Don't multiply a UI test across phones when nothing in it depends on width.

**Why.**
Each extra parameter value multiplies the full cost of the test.
At the UI level that is tens of seconds per value; at the unit level it is milliseconds, so put the matrix there.

**Exceptions.**
AX3 journeys that must prove a whole flow survives the large size are legitimate, but one per flow is enough.

**Verify.**
For every parameterized or per-size test, write down which assertion changes with the parameter.

### 2.9 Test host requirements

**Do.**
Keep the unit target app-hosted, because it renders SwiftUI views in UIKit windows, reads `UIApplication.shared.connectedScenes` and uses `ImageRenderer`, which need an app process.
Make the host do nothing on launch when it runs under tests: detect the test environment in `fitbodApp` and skip `RootView`'s seeding and the real store.

**Don't.**
Don't let the host run the full first-launch import before the first unit test executes.

**Why.**
The host's launch is part of the 14 s gap between 22 s of execution and 36 s of wall time (hypothesis for the split).
Unit tests never read the host's store; 65 files build their own.

**Exceptions.**
None found.
If a future test needs the host's seeded store, give it an explicit seam instead.

**Verify.**
After the change, `xcrun xcresulttool get test-results summary` shows the same pass count and a shorter "Test run ... after N seconds" line.

### 2.10 Serialization, actor isolation and shared state

**Do.**
Write each suite so its tests share nothing mutable: a container per test, a defaults suite per test, no `static var`.
Then leave `.serialized` off.
Use `@MainActor` on a test only when it touches UIKit or a main-actor type.
When a suite must be serialized, say why in a comment next to the trait, as `SeedTests` does.

**Don't.**
Don't add `.serialized` because another suite has it, or `@MainActor` because the compiler suggested it.
103 suites are serialized today and almost none say why.

**Why.**
Swift Testing runs tests in parallel inside one process by default; `.serialized` removes that for the suite and `@MainActor` funnels its tests through one thread.
Today the whole target executes in 22 s, so the gain is small, but the cost shows up as the suite grows and as the serialized suites hide ordering bugs.

**Exceptions.**
Suites that touch process-wide state that cannot be injected stay serialized: `UIApplication.shared` windows, `UserDefaults.standard` until it is injected.

**Verify.**
`rg -n "\.serialized" fitbodTests` and check each hit has a reason on the same or the previous line.

### 2.11 Parallel execution and CI sharding

**Do.**
Keep the unit target serial at the xcodebuild level; the measured parallel run was 15 s slower because of clone creation.
Run the UI target on simulator clones locally, on the M4 only, once the sample in section 1.6 proves it stable: `-parallel-testing-enabled YES -parallel-testing-worker-count 3` on the dedicated phone.
On CI, split by job, not by clone: one build job, then a matrix of unit, UI large and UI small, each on its own runner.
Shard the UI bundle further with explicit `-only-testing:` lists when one job is still the long pole.

**Don't.**
Don't run clones on the 7 GB CI runner; each clone is a booted simulator with its own app.
Don't enable parallel testing in the scheme for both targets; the scheme pins `parallelizable = "NO"` on purpose and Xcode has dropped that setting before (see `CLAUDE.md`).

**Why.**
Elapsed time drops to the longest job; compute rises by one runner setup per job, 4 to 5 minutes each on `macos-26` (measured as per-step overhead).
Clones are isolated simulators, so UI tests that reset the app do not collide.

**Exceptions.**
The raw `XCUIApplication()` tests that depend on the simulator's own content size (`simctl ui ... content_size`) may not see that setting on a clone; move them to the launch helper, which pins the size per launch, before running clones.

**Verify.**
Three full runs with clones, no new failures, and the elapsed time divided by about the worker count.

### 2.12 Build caching and build reuse

**Do.**
Build once with `build-for-testing` and run every job with `test-without-building`, as `scripts/ci/ios-ci.sh` already does inside one job.
Pass the built products between CI jobs as an artifact so the matrix never rebuilds.
Keep `COMPILER_INDEX_STORE_ENABLE=NO` and `CODE_SIGNING_ALLOWED=NO` on test builds.
Locally, keep one DerivedData per checkout and never clean it to "fix" a test.

**Don't.**
Don't add `clean` to CI or local scripts; the cold build is 31 s locally and 1.1 min on CI, and the warm one is 1 s.
Don't build for a specific simulator id when a generic destination works; the generic build runs on every phone.

**Why.**
The build is already the cheap part.
The only way to make it expensive is to repeat it per job or per phone.

**Exceptions.**
A schema or build-setting change can leave stale products; a cold build once after such a change is fine.

**Verify.**
`xcodebuild -showBuildTimingSummary` on the cold build names any target that dominates; the CI log shows one build per run.

### 2.13 Retries and flakiness

**Do.**
Retry only the thing that failed for a reason outside the test: `run_tests` in `scripts/ci/ios-ci.sh` retries once when zero tests ran, which is the right rule.
Give every test a timeout ceiling with `-test-timeouts-enabled YES` and `-default-test-execution-time-allowance`, and record every test that exceeds it.
Measure flakiness on purpose: `-test-iterations 3` on a suspect suite, or three repeated runs with the same inputs.
Fix the synchronization when a test is flaky; do not retry it green.

**Don't.**
Don't add `-retry-tests-on-failure` to the normal run.
It hides the failure and doubles the cost of every flaky test.
Don't mark a test `continue-on-error` and forget it; the CI workflow marks all three test steps that way, so a red suite does not fail the job.

**Why.**
A retry that passes tells you the test is wrong, not that the app is right.
A hung test without a ceiling costs the whole 120-minute budget.

**Exceptions.**
`-run-tests-until-failure` and `-test-iterations` are the right tools when hunting a flake, in a separate run.

**Verify.**
The run's summary shows zero retried tests, and the attempt logs in `scripts/ci/ios-ci.sh`'s `$LOGS` folder exist only for runs where no test ran.

## 3. Code and configuration examples

Every "after" block is illustrative: it shows the shape of the change and has not been compiled or run.
Each example names the file and symbol it would change, the mechanism that saves time and how the behavior stays covered.

### 3.1 Check `exists` before waiting

File: `fitbodUITests/UITestNavigation.swift`, used by `hittable`, `selectTab`, `openSettings` and by `WorkoutUITestNavigation.openSeededWorkout`.

Before (current code in `openSeededWorkout`):

```swift
let resume = app.buttons["resumeSlab.resume"]
XCTAssertTrue(resume.waitForExistence(timeout: 10))
resume.tap()
XCTAssertTrue(app.textFields["set.reps.1.S1"].waitForExistence(timeout: 10))
```

After (illustrative):

```swift
extension UITestNavigation {
    /// True when `element` is on screen now, or appears within `timeout`.
    /// One snapshot answers the common case; the wait runs only when needed.
    @discardableResult
    static func appears(_ element: XCUIElement, within timeout: TimeInterval = 10) -> Bool {
        element.exists || element.waitForExistence(timeout: timeout)
    }
}

let resume = app.buttons["resumeSlab.resume"]
XCTAssertTrue(UITestNavigation.appears(resume))
resume.tap()
XCTAssertTrue(UITestNavigation.appears(app.textFields["set.reps.1.S1"]))
```

Mechanism: `exists` takes one accessibility snapshot, measured under 0.1 s; a satisfied `waitForExistence` measured 1.0 to 1.1 s.
Coverage: the fallback is the same wait with the same timeout, so an element that is still arriving is still waited for, and a missing element still fails.
Expected gain: hypothesis, 5 to 10 s per test, because most of the 501 call sites wait for elements that are already there.
Start with the helpers, which cover most call sites, then the tests.

### 3.2 Reset user data, keep the catalog

Files: `fitbod/App/DebugLaunchReset.swift` (`runIfRequested`, `reset`, `freshness`), `fitbodUITests/UITestNavigation.swift` (`freshStore`, `seededWorkout`, `launch`).

Before (current code in `launch`):

```swift
static let freshStore = [resetFlag]
static let seededWorkout = [resetFlag, "-fitbod-seed-demo-workout"]
// ...
app.launchArguments = (textSize?.launchArguments ?? []) + arguments + [resetSignalFlag]
app.launch()
XCTAssertTrue(tab("Today", in: app).waitForExistence(timeout: 90), "The tab bar never appeared", file: file, line: line)
if resets {
    assertFreshStore(in: app, file: file, line: line)
}
```

After (illustrative), the app side:

```swift
// DebugLaunchReset.swift
static let userDataArgument = "-fitbod-reset-user-data"

/// Deletes what a user creates and resets what a user edits, and keeps
/// the seeded catalog and its stamp so the next launch skips the import.
static func resetUserData(in container: ModelContainer, defaults: UserDefaults, domain: String) throws {
    let context = ModelContext(container)
    try context.delete(model: Session.self)
    try context.delete(model: Block.self)
    try context.delete(model: Split.self)
    try context.delete(model: SessionTemplate.self)
    try context.delete(model: RoutineFolder.self)
    try context.delete(model: PlateInventory.self)
    try context.delete(model: Exercise.self, where: #Predicate { $0.isCustom })
    // Archived flags, user-edited stimulus weights and volume targets reset here too.
    try context.save()
    let seedVersion = defaults.integer(forKey: ExerciseLibraryImporter.seedVersionKey)
    defaults.removePersistentDomain(forName: domain)
    defaults.set(seedVersion, forKey: ExerciseLibraryImporter.seedVersionKey)
}
```

The test side keeps the contract: `launch` passes the new flag by default, `freshness` reports "fresh, catalog kept" and lists any user row that survived, and `assertFreshStore` accepts either fresh value.
Tests about the first launch pass `resetFlag` explicitly.

Mechanism: the launch skips `ExerciseLibraryImporter.seedIfNeeded`'s decode of the 1.0 MB JSON and its 700-row insert.
Coverage: the fresh-store signal still proves the test starts from no user data; it now also has to prove the list of reset entities is complete, which is the risk in this change.
The enumerated list must be kept in step with the schema, so the signal should count rows per user-created type and fail the launch when any remain.

Alternative with less code to maintain: after the first full reset and import in a run, copy the seeded store with SQLite's `VACUUM INTO` to a golden file, and let later resets restore that file instead of deleting the store.
That keeps the exact fresh-store semantics and no entity list, at the price of regenerating the golden file whenever `fitbod/Resources/ExerciseSeed/SEED_VERSION.txt` or the schema changes.

Expected gain: hypothesis, 3 to 4 s per launch, about 180 launches per bundle run per phone.

### 3.3 Delete the template tests

Files: `fitbodUITests/fitbodUITests.swift`, `fitbodUITests/fitbodUITestsLaunchTests.swift`.

Before:

```swift
@MainActor
func testExample() throws {
    let app = XCUIApplication()
    app.launch()
}

@MainActor
func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}

final class fitbodUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }
    // testLaunch: launch, then keep a screenshot forever
}
```

After (illustrative): delete `testExample` and `testLaunchPerformance`, and replace `fitbodUITestsLaunchTests` with one assertion and no fan-out.

```swift
final class LaunchUITests: XCTestCase {
    @MainActor
    func testFreshLaunchShowsTheTabBar() {
        let app = UITestNavigation.launch(UITestNavigation.freshStore)
        XCTAssertTrue(UITestNavigation.tab("Today", in: app).exists)
    }
}
```

Mechanism: `testExample` asserts nothing; `measure` runs its block five times and cannot fail without a baseline; `runsForEachTargetApplicationUIConfiguration` repeats `testLaunch` for every orientation and appearance in the plan and keeps a screenshot each time.
Coverage: nothing is lost, because none of the three asserted a behavior.
If launch time matters, it belongs in a separate performance test plan with a committed baseline, run on a schedule.
Expected gain: hypothesis, 30 to 60 s per phone per run, plus the landscape orientation that the next test must undo.

### 3.4 Disable animations for test launches

Files: `fitbod/App/DebugLaunchReset.swift` or a sibling DEBUG hook, `fitbod/fitbodApp.swift`, `fitbodUITests/UITestNavigation.swift`.

After (illustrative), the app side:

```swift
// A DEBUG launch argument, next to the reset flags.
static let noAnimationsArgument = "-fitbod-disable-animations"

static func applyAnimationPreference() {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains(noAnimationsArgument) {
        UIView.setAnimationsEnabled(false)
    }
    #endif
}
```

And on the root view, so SwiftUI transactions follow:

```swift
RootView()
    .transaction { transaction in
        if DebugLaunchReset.animationsDisabled { transaction.disablesAnimations = true }
    }
```

The test side adds the flag in `launch` and `relaunch`, with an opt-out parameter for the layout audits, `waitUntilStill` users and the two tests that are about animation.

Mechanism: after a tap, XCUITest waits for the app to idle, and animations keep it busy; the measured tap cost here is 1.1 to 2.8 s, where the tap itself is a fraction.
Coverage: the assertions do not change; sheets still present and dismiss, just without the 0.3 to 0.5 s transition.
Risk: a test could pass with animations off and fail with them on, for example a tap during a transition; keep one journey per flow with animations on.
Expected gain: hypothesis, 0.2 to 0.5 s per tap, 445 taps per bundle run.

### 3.5 Inject `UserDefaults` into the seeders

Files: `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift` (`seedIfNeeded`), `fitbod/Settings/PlateInventorySeeder.swift`, `fitbodTests/SeedTests.swift`.

Before:

```swift
public func seedIfNeeded(bundle: Bundle = .main) async throws {
    let bundled = try Self.bundledSeedVersion(bundle: bundle)
    let stored = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
    // ...
}

@Suite("ExerciseLibraryImporter", .serialized)
struct SeedTests {
    private static func resetStamp() {
        UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
    }
    // every test: Self.resetStamp()
}
```

After (illustrative):

```swift
public func seedIfNeeded(bundle: Bundle = .main, defaults: UserDefaults = .standard) async throws {
    let bundled = try Self.bundledSeedVersion(bundle: bundle)
    let stored = defaults.integer(forKey: Self.seedVersionKey)
    // ... and the stamp at the end writes to `defaults`.
}

@Suite("ExerciseLibraryImporter")
struct SeedTests {
    /// A defaults domain nobody else reads, dropped when the test ends.
    private func isolatedDefaults() throws -> UserDefaults {
        let name = "SeedTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Seed inserts at least 600 strength exercises (LIB-01 / FOUND-05)")
    func strengthOnlyCount() async throws {
        let container = try InMemoryContainer.makeEmpty()
        let importer = ExerciseLibraryImporter(modelContainer: container)
        try await importer.seedIfNeeded(defaults: isolatedDefaults())
        // ...
    }
}
```

`RootView.runSeed` keeps calling the production default, so the app is unchanged.
Mechanism: the suite no longer shares a stamp through the process, so it drops `.serialized` and its tests can overlap with each other and with every other suite.
Coverage: the stamp logic runs exactly as before, against an isolated domain; the test that checks the stamp short-circuits a second call still works by reusing the same `defaults` instance.
Expected gain: small in time (the suite is 4.3 s), large in determinism; it also removes the one reason `.serialized` has a comment in this target.

### 3.6 Replace the fixed sleep in the fidelity test

File: `fitbodTests/NewBlockBuilderFidelityTests.swift`, `recognizedText(inBuilderOfWidth:)`.

Before:

```swift
host.view.layoutIfNeeded()
try await Task.sleep(for: .seconds(1))
```

After (illustrative):

```swift
host.view.layoutIfNeeded()
// SwiftUI renders on a later run-loop turn. Wait until the first title is drawn, 1 s at most.
let deadline = ContinuousClock.now + .seconds(1)
repeat {
    try await Task.sleep(for: .milliseconds(50))
} while !hostViewHasRendered(host) && ContinuousClock.now < deadline
```

where `hostViewHasRendered` walks `host.view` for a `UILabel` or drawn text, or runs a `.fast` Vision pass that looks for "Accumulation".
Mechanism: the sleep is a ceiling instead of a fixed cost; the three widths currently pay 3 s of the test's 7 s.
Coverage: the `.accurate` read and the ten expected strings stay as they are.
Expected gain: hypothesis, 2 to 3 s of the unit target's 22 s; low priority, listed for completeness.

### 3.7 CI: one build job, a matrix of test jobs, timeouts and no diagnostics

Files: `.github/workflows/ios.yml`, `scripts/ci/ios-ci.sh` (`run_tests`).

Before (`run_tests` flags today):

```bash
xcodebuild test-without-building "${common_flags[@]}" \
  -destination "platform=iOS Simulator,id=$udid" \
  -parallel-testing-enabled NO \
  "$@"
```

After (illustrative), the flags:

```bash
xcodebuild test-without-building "${common_flags[@]}" \
  -destination "platform=iOS Simulator,id=$udid" \
  -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 420 \
  -maximum-test-execution-time-allowance 900 \
  -resultBundlePath "$RESULTS/$label.xcresult" \
  "$@"
```

The allowance must clear the slowest legitimate journey; `WorkoutJourneyUITests` took 282 s on the runner, so 420 s is the default and 900 s the ceiling.

After (illustrative), the workflow shape:

```yaml
jobs:
  build:
    runs-on: macos-26
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - run: scripts/ci/ios-ci.sh build
      - uses: actions/upload-artifact@v4
        with:
          name: test-products-${{ github.sha }}
          path: build/DerivedData/Build/Products   # the .xctestrun files and Debug-iphonesimulator/

  test:
    needs: build
    runs-on: macos-26
    timeout-minutes: 60
    strategy:
      fail-fast: false
      matrix:
        job: [unit, ui-large, ui-small]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: test-products-${{ github.sha }}
          path: build/DerivedData/Build/Products
      - run: scripts/ci/ios-ci.sh simulators
      - run: scripts/ci/ios-ci.sh ${{ matrix.job == 'unit' && 'unit' || format('ui {0}', matrix.job == 'ui-large' && 'large' || 'small') }}
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: results-${{ matrix.job }}-${{ github.sha }}
          path: build/results
```

The evidence step moves to a small job that needs all three and merges their bundles.
The products path must match `scripts/ci/ios-ci.sh`'s `-derivedDataPath`, so `test-without-building` finds the same `Build/Products` it would have built.

Mechanism: elapsed time becomes the longest test job plus the build and the artifact transfer, instead of the sum of all steps.
Compute rises by two extra runner setups and two extra simulator creations, 5 to 15 minutes in total.
Coverage: the same three commands run on the same phones; nothing is skipped.
`timeout-minutes` per job and the test allowance turn a hung run into a bounded, attributed failure.

Also add `push: branches: [main]` to the triggers.
Nothing has run in CI since 2026-10-04 because the work moved to `main`.

### 3.8 Local clone-parallel UI run on the M4

Command (verified flags, Xcode 26.5):

```bash
xcodebuild test-without-building \
  -project fitbod.xcodeproj -scheme fitbod -configuration Debug \
  -derivedDataPath build/DerivedData \
  -destination 'platform=iOS Simulator,id=79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE' \
  -only-testing:fitbodUITests \
  -parallel-testing-enabled YES \
  -parallel-testing-worker-count 3 \
  -collect-test-diagnostics never \
  -resultBundlePath build/results/ui-large-clones.xcresult \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

`-parallel-testing-enabled YES` on the command line overrides the scheme's `parallelizable = "NO"` without editing the scheme, so the serial default stays for everyone else.
The unit target stays out of this command; section 1.3 measured it slower under clones.
Section 1.6 records the 24-test sample.
Run the full bundle three times before trusting it.

## 4. Prioritized plan

Impact numbers are per phone per full run on the M4 unless the row says otherwise.
"Elapsed" is wall time a developer or a PR waits for; "compute" is runner minutes billed.
Every impact is a hypothesis until the measurement plan in section 5 confirms it; the rows say which measurement does.

### Quick wins

| Finding | Repository evidence | Proposed change | Expected impact | Effort | Reliability risk | Validation |
| --- | --- | --- | --- | --- | --- | --- |
| Template UI tests assert nothing and multiply launches | `fitbodUITests/fitbodUITests.swift` (`testExample`, `testLaunchPerformance`), `fitbodUITests/fitbodUITestsLaunchTests.swift` (`runsForEachTargetApplicationUIConfiguration = true`) | Delete the two; replace the launch test with one asserted launch (section 3.3) | Hypothesis: 30 to 60 s elapsed and compute per phone; no more landscape carry-over | Small | None; no assertion is lost | Test count drops; bundle wall time before and after |
| CI runs without a test timeout or `-collect-test-diagnostics never` | `scripts/ci/ios-ci.sh` `run_tests`; `docs/SETUP.md` on the ten-minute `simctl diagnose` | Add the flags from section 3.7 | Bounded failures: up to 10 min saved per failing step, and a hung test ends at 7 to 15 min instead of 120 | Small | Low; the allowance must clear the 282 s journey | Force one failure on a branch and read the step time |
| Satisfied `waitForExistence` costs about 1 s | 501 call sites; the activity timeline in section 1.3 | `appears` helper, applied first in `hittable`, `selectTab`, `openSettings`, `openSeededWorkout` (section 3.1) | Hypothesis: 5 to 10 s per UI test, 15 to 30 min per phone | Small to medium | Low; same wait as the fallback | `NoteSheetsUITests` wall time before and after, then the full bundle |
| Fixed-step polling in helpers | `hittable` sleeps 0.5 s per step; `HeatmapHitAreaUITests` compares screenshots once a second; 11 `Thread.sleep` sites | 100 ms steps, or an `XCTNSPredicateExpectation` on `isHittable` | Hypothesis: 0.2 to 0.4 s per `hittable` miss; small overall | Small | Low | Per-test durations of the suites that use `hittable` most |
| Unit target under clones is slower | Section 1.3: 51 s against 36 s | None; keep the unit target serial and write that down in `docs/SETUP.md` | Avoids a 15 s regression | Small | None | The unit run stays at about 36 s |
| CI never runs on `main` | `.github/workflows/ios.yml` triggers | Add `main` to `push.branches`, with the PR plan from section 5.4 | Feedback, not speed: the first measured CI number for the October suites | Small | Billing | A push to `main` produces a run |

### Moderate refactors

| Finding | Repository evidence | Proposed change | Expected impact | Effort | Reliability risk | Validation |
| --- | --- | --- | --- | --- | --- | --- |
| Every launch re-imports the catalog | `UITestNavigation.launch`, `DebugLaunchReset.reset`, `RootView.runSeed`; "Open bodybuilding.fitbod" 5.0 to 5.4 s | `-fitbod-reset-user-data` or a golden store (section 3.2); the full reset stays opt-in | Hypothesis: 3 to 4 s per launch, 9 to 12 min per phone; CI larger | Medium | Medium; the reset list must be complete and the signal must prove it | The fresh-store signal counts user rows; full bundle on both phones, pass list diffed against the serial baseline |
| Animations run during tests | No animation switch in `fitbod/`; taps 1.1 to 2.8 s in the timeline | `-fitbod-disable-animations` in `launch`, opt-out for layout and animation tests (section 3.4) | Hypothesis: 0.2 to 0.5 s per tap, 1.5 to 4 min per phone | Medium | Medium; a transition bug could hide; keep one animated journey per flow | Idle-wait durations in the activity tree before and after |
| One sequential CI job | `.github/workflows/ios.yml`; Oct 4 step times | Build job plus a matrix of unit, UI large, UI small (section 3.7) | Elapsed drops from the sum of steps to the longest step; compute rises 5 to 15 min per run | Medium | Low; artifact size and path matching | Run wall time and billable minutes for three runs |
| Both phones run width-insensitive suites | `scripts/ci/ios-ci.sh` `cmd_ui`; 23 of 58 files assert layout | Name the width-sensitive suites in a list the small-phone job uses; the nightly run keeps the full bundle on both phones | Hypothesis: the small-phone job shrinks by about 60 percent | Medium | Medium; a width bug in an "insensitive" suite waits for the nightly run | The list is reviewed per new suite; nightly green on both phones |
| The unit host launches the full app | `fitbodApp.init`, `RootView.runSeed`; 14 s between execution and wall time | Detect the test host and skip seeding and the real store (section 2.9) | Hypothesis: 5 to 10 s per unit run | Medium | Low to medium; a test that silently relied on the host's store would surface | Same pass count; shorter wall time |
| Seeders read `UserDefaults.standard` | `ExerciseLibraryImporter.seedIfNeeded`, `PlateInventorySeeder.seedIfNeeded`, `SeedTests` | Inject `defaults:` with a production default (section 3.5) | Small time gain; removes process-wide state and a `.serialized` | Small to medium | Low | `SeedTests` passes without `.serialized`, three repeated runs |

### Larger architectural changes

| Finding | Repository evidence | Proposed change | Expected impact | Effort | Reliability risk | Validation |
| --- | --- | --- | --- | --- | --- | --- |
| The UI bundle runs serially on one phone | Scheme `parallelizable = "NO"`; the sample in section 1.6 ran 2.25 times faster on four clones | Clone-parallel local runs with 3 or 4 workers (section 3.8), M4 only | Measured on the sample: elapsed divided by 2.25 with four workers; compute unchanged; not for CI | Medium, plus stabilization | Medium; one file-picker test (`SettingsExportUITests.testRestoreAsksBeforeReplacingData`) failed on a clone and passed serially; clone creation, memory, raw-launch tests that read the simulator's content size | Three full runs; zero new failures; wall time |
| The UI bundle is one CI shard | `-only-testing:fitbodUITests` once per phone | Shard the bundle into 2 or 3 `-only-testing` lists per phone as matrix entries | Elapsed divided by the shard count; compute rises 4 to 5 min per shard | Medium | Low to medium; shard lists must cover every suite | A script lists every suite and fails when one is in no shard |
| Copy and structure checks live in UI tests | 11 BRU, Copy and Smoke-named UI files; `WhyThisWeightSheetBRUUITests`; 45 unit files already introspect source | Per smoke test, keep the journey or move the check to a hosted-view unit test; keep one reachability journey per screen | Each moved test goes from 10 to 40 s to under 1 s | Large | Medium; a hosted view does not prove navigation, so the kept journey must | A table per screen: journey test, unit tests, what each proves |
| Text-size reruns repeat whole journeys | 39 sized launches in 11 AX3 files | Launch straight to the screen at the size under test; one AX3 journey per flow | Hypothesis: half of the sized-launch time | Large | Medium; the direct route must exist as a DEBUG launch argument | The AX3 assertions stay; durations per file |
| Broad `.serialized` and `@MainActor` | 103 serialized suites, 124 `@MainActor` files, few reasons | Remove the trait where the suite shares nothing; comment the rest | Small today (22 s of execution); prevents growth and hides fewer ordering bugs | Large, spread over time | Low with isolated fixtures | Three repeated unit runs with `-parallel-testing-enabled NO`, then with Swift Testing's parallelism, same pass list |

### The first five actions

1. Run the baseline from section 5.2 once on each phone, serially, so the 200-minute figure becomes a measured number with a result bundle.
2. Delete the template tests and add the CI timeout and diagnostics flags: two small PRs with no behavior change.
3. Add `appears` to `UITestNavigation`, use it in the four helpers, and measure `NoteSheetsUITests` before and after.
4. Build the data-only reset or the golden store, with the fresh-store signal extended to prove it, and measure the full bundle on the large phone.
5. Split the CI workflow into a build job and a matrix, add `main` to the triggers, and read the first run's wall time against the Oct 4 numbers.

Elapsed time and compute are different numbers.
Actions 2, 3 and 4 cut both, because they remove work.
Action 5 and the sharding rows cut elapsed time and add compute.
Clone-parallel local runs cut elapsed time and leave compute alone, but they need a Mac with the memory for three booted simulators.

## 5. Measurement and regression prevention

### 5.1 Fixed conditions

Record these with every measurement, and change one at a time.

| Condition | Value for the baseline |
| --- | --- |
| Machine | Apple M4, 10 cores, 32 GB; on mains power; Xcode closed; no other simulator booted |
| Toolchain | Xcode 26.5 (17F42), iOS 26.5 runtime |
| Phones | `sw6 iPhone 17 Pro Max` (`79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE`), `sw6 iPhone 17e` (`C2512FF6-0EC6-4044-8B18-53E451AB0899`); never a personal device |
| Configuration | Debug, `CODE_SIGNING_ALLOWED=NO`, `COMPILER_INDEX_STORE_ENABLE=NO`, `-parallel-testing-enabled NO`, `-collect-test-diagnostics never` |
| Cache | Cold means a fresh `-derivedDataPath`; warm means an immediate second run with no change |
| Simulator state | Booted and settled before `xcodebuild` starts; `simctl ui <id> content_size large` and `appearance light` |
| Repeats | Three runs per configuration; report the median and keep the minimum and maximum |

### 5.2 The baseline commands

```bash
DD=build/DerivedData; R=build/results; mkdir -p "$R"
PM=79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE   # sw6 iPhone 17 Pro Max
SE=C2512FF6-0EC6-4044-8B18-53E451AB0899   # sw6 iPhone 17e
COMMON=(-project fitbod.xcodeproj -scheme fitbod -configuration Debug -derivedDataPath "$DD"
        CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO)

# Build once, cold, with per-target timings.
rm -rf "$DD"
/usr/bin/time -l xcodebuild build-for-testing "${COMMON[@]}" \
  -destination 'generic/platform=iOS Simulator' -showBuildTimingSummary \
  > "$R/build-cold.log" 2>&1

xcrun simctl boot "$PM"; xcrun simctl bootstatus "$PM" -b

# Unit target.
/usr/bin/time -l xcodebuild test-without-building "${COMMON[@]}" \
  -destination "platform=iOS Simulator,id=$PM" -only-testing:fitbodTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath "$R/unit.xcresult" > "$R/unit.log" 2>&1

# UI bundle, large phone, serial. Repeat with $SE for the small phone.
/usr/bin/time -l xcodebuild test-without-building "${COMMON[@]}" \
  -destination "platform=iOS Simulator,id=$PM" -only-testing:fitbodUITests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath "$R/ui-large.xcresult" > "$R/ui-large.log" 2>&1
```

Read the numbers out of the bundles:

```bash
xcrun xcresulttool get test-results summary --path build/results/ui-large.xcresult
xcrun xcresulttool get test-results tests   --path build/results/ui-large.xcresult > build/results/ui-large-tests.json
xcrun xcresulttool get test-results activities --test-id 'NoteSheetsUITests/testPinnedNoteSavesOnlyOnSave()' \
  --path build/results/ui-large.xcresult
```

The `tests` JSON is a tree of `testNodes` whose `nodeType` is "Test Case" for a case, with `duration` and `result`.
A 40-line Python script that flattens it, sums per suite and prints the slowest 20 cases is worth committing as `scripts/ci/test_timing_report.py`; the audit used one in its scratch folder.
`-showBuildTimingSummary` prints the per-target table at the end of the build log.
`/usr/bin/time -l` prints wall time and maximum resident memory for the `xcodebuild` process; sample simulator memory with `top -l 1 -stats pid,mem,command | grep -i simulator` while the UI run is on.

### 5.3 What to track

| Metric | Source | Why it matters |
| --- | --- | --- |
| Total elapsed per command | `/usr/bin/time` wall clock | The number people feel |
| Build time, cold and warm, per target | `-showBuildTimingSummary`, the log | Separates compile from test cost |
| Test execution time | `xcresulttool ... summary`, "Test run ... after N seconds", and per-bundle durations | The part the test code controls |
| Slowest 20 cases and 10 suites | The flattened `tests` JSON | Where to look next |
| Launch cost per UI test | The "Open bodybuilding.fitbod" activity | Tracks the reset and import changes |
| Retries | `scripts/ci/ios-ci.sh` attempt logs; the summary's retry counts | Must stay at zero |
| Flakiness | Three repeats; any test with mixed results | A flaky test is a bug, not a cost |
| Resource use | `/usr/bin/time -l` max RSS; `top` samples during UI runs; booted simulator count | Decides the clone worker count |
| Tests per run per phone | `-enumerate-tests` or the summary's counts | Proves a split still runs everything |

Keep a committed baseline file, for example `docs/test-timing/baseline.json`, with the median numbers and the conditions from 5.1.
Update it on purpose, in the same PR as the change that moved it.

### 5.4 Targets and budgets (proposed)

| Scope | Now (measured or projected) | Target after the quick wins and the reset change | Budget per change |
| --- | --- | --- | --- |
| Unit target, local, wall | 36 s | 30 s | A new unit case over 1 s needs a comment that names why |
| UI case, local, median | about 16 to 28 s (projected from the baseline and the Oct 29 bundle) | 10 s | A new UI case adds at most 30 s; a journey at most 90 s |
| UI bundle, one phone, serial, local | 54 to 93 min (projected) | 35 min | The median full run may grow at most 10 percent between baseline updates |
| UI bundle, one phone, 4 clones, local | 2.25 times faster than serial on the 24-test sample | 15 min (hypothesis) | Same |
| CI, PR run | no current run | 25 min elapsed | A PR run over 30 min blocks the merge until explained |
| CI, `main` run | no current run | 45 min elapsed, matrix | Same |
| CI, nightly | no current run | no elapsed target; 120 min per job, timeouts per test | Any test over its allowance is a failure to fix, not a reason to raise the allowance |

The targets are proposals.
Set them from the first measured baseline, not from this table, and tighten them after each action in section 4.

### 5.5 Where every test still runs

Splitting the suites by trigger is safe only if every test still runs somewhere on a schedule.

| Trigger | Runs | What it does not run | Where that runs instead |
| --- | --- | --- | --- |
| Pull request and push to `main` | Unit target; a UI smoke list of one reachability journey per screen on the large phone | The rest of the UI bundle; the small phone; AX3 suites | The `main` matrix and the nightly run |
| Push to `main` (matrix) | Unit; full UI bundle on the large phone; the width-sensitive list on the small phone | Width-insensitive suites on the small phone | Nightly |
| Nightly or on demand | Unit; full UI bundle on both phones; AX3 suites; `-test-iterations 3` on the suites that flaked that week | Nothing | Nothing |

The smoke list, the width-sensitive list and the shard lists are plain files of `-only-testing:` entries, checked by a script that enumerates the bundle with `-enumerate-tests` and fails when a suite is in no list.

### 5.6 Reporting

Report three numbers separately in every PR that touches test performance: the PR feedback time (the smoke run), the full-suite wall time per phone, and CI compute minutes per run.
A change that moves only the first is a feedback win, not a suite win.
Say which conditions from 5.1 differed from the baseline.

### 5.7 Keeping it from regressing

- The timing report runs in CI and uploads with the result bundle; a nightly job compares the slowest 20 against the baseline and opens an issue when a case grows by more than 50 percent or the full run by more than 10 percent.
- A new UI test file needs a line in a list: smoke, width-sensitive or neither.
- `rg` checks in the PR template: no new `Thread.sleep` or `Task.sleep` without a comment, no new `UserDefaults.standard` in app code, no new `.serialized` without a reason, no new `runsForEachTargetApplicationUIConfiguration`.
- Every retry is visible: the summary step prints attempt counts, and a retried run is not green.

## 6. Checklist for every new or modified test

- Is this the cheapest test type that proves the behavior, and can you name what a cheaper one could not prove?
- Does the fixture hold only what the assertions read?
- Does the test build its own container and defaults, and share nothing mutable with its suite?
- Is every injected clock, calendar, scheduler and bundle passed in, with the production default on the parameter?
- Is there a `sleep`? If so, is it a ceiling on a condition, and does a comment say what it waits for?
- For a UI test: one launch, the smallest seeded state, identifiers over label scans, `appears` before a wait, animations off unless the test is about them.
- For a UI test: does every screenshot and attachment have a reader?
- For a parameterized or per-size test: which assertion changes with the parameter?
- Is `.serialized` or `@MainActor` there for a reason written beside it?
- Which list does a new UI suite belong to: smoke, width-sensitive or neither?
- Did you run it three times, and did its duration fit the budget in section 5.4?
- Does the result bundle's activity tree show only taps, typing and assertions, plus overhead you can explain?

## 7. Summary

The biggest opportunities, in order:

1. The UI bundle grew from 55 to 202 tests in the last three days of October, and each test pays 5 to 6 s to reset and re-import the catalog, about a second per satisfied wait and 1 to 3 s per animated tap.
   Keeping the catalog across launches, checking `exists` before waiting and turning animations off for most launches should remove a third to a half of every UI test, by hypothesis.
2. CI runs everything in one sequential job on both phones and has not run at all since 2026-10-04.
   A build job plus a matrix, `main` in the triggers, test timeouts and `-collect-test-diagnostics never` turn it into a bounded run whose elapsed time is its longest job.
3. On the M4, simulator clones for the UI target alone cut the sample's elapsed time by 2.25 times with four workers, with one failure to understand; the full bundle still needs three clean runs.
4. The unit target is not the problem: 1,118 tests execute in 22 s, and the fixes there (the seeders' `UserDefaults`, the fidelity sleep, the host's launch) are about determinism and growth, not minutes.
5. Template tests and width-insensitive reruns are pure cost that nobody will miss.

The missing evidence:

- No record of the 200-minute run exists in the repository, the result bundles or CI; the figure is consistent with the full bundle run serially on both phones, and section 5.2 produces the real number in one run.
- No CI run has executed the October suites, so the runner's cost per test is unknown.
- The cost of a launch without the reset flag is unmeasured; the relaunch activity in any journey's bundle gives it.
- Whether clone runs stay stable across the full bundle is unmeasured beyond the 24-test sample, where one file-picker test failed.
- Whether `-parallel-testing-enabled NO` also disables Swift Testing's in-process parallelism is undocumented; it changes nothing at today's 22 s.
