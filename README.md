# Fitbod

A personal iOS app for detail-rich weight training: prescriptive routines,
fast set logging, an accurate rest timer, and history at the resolution
serious lifters train at. SwiftUI + SwiftData, local-only, iPhone.

Milestone 1 delivers **Chalkline**, the app's design system, and the core
journey built on it:

> find an exercise → build a routine → start a workout → log sets with a
> rest timer → close the app and come back → finish → see the summary,
> history, and last time's numbers next time.

| | |
|---|---|
| Design system | [docs/design-system/README.md](docs/design-system/README.md) · component map [components.md](docs/design-system/components.md) · in-app gallery (Settings → Component gallery) |
| Screen specs | [docs/design/screens.md](docs/design/screens.md) |
| Verification | [docs/verification.md](docs/verification.md) · screenshots in [docs/verification/ci/](docs/verification/ci/) |
| Exercise catalog | [docs/exercise-library.md](docs/exercise-library.md) |
| Roadmap | [docs/roadmap.md](docs/roadmap.md) |

## Requirements

- macOS with **Xcode 26.4 or newer** (the project targets iOS 26.4 and
  builds the app in Swift 6 language mode with complete concurrency
  checking). CI uses Xcode 26.6.
- An iPhone simulator (any size; the app is tested on iPhone SE 3rd
  generation and iPhone 17 Pro Max) or an iPhone on iOS 26.4+.
- No third-party dependencies, no package resolution, no backend.

## Run it

1. Open `fitbod.xcodeproj` in Xcode.
2. Select the **fitbod** scheme and an iPhone simulator, then **Run** (⌘R).
3. First launch imports the bundled exercise catalog (702 strength
   exercises from free-exercise-db) — a "Preparing library…" splash shows
   for a moment, once.

### On a physical iPhone

1. Xcode → target **fitbod** → *Signing & Capabilities* → choose your
   Personal Team (a free Apple ID works) for **fitbod** and
   **FitbodWidgetsExtension**. Change the bundle identifiers
   (`bodybuilding.fitbod…`) to something unique to you if Xcode asks.
2. Plug in the phone, select it as the run destination, ⌘R. Trust the
   developer certificate on the phone (Settings → General → VPN & Device
   Management) the first time.
3. Personal-team installs expire after 7 days; re-run from Xcode to renew.

Allow notifications when asked: the rest timer uses a local notification
and a Live Activity to tell you when rest is over while the phone is locked.

### Try it with realistic data

Edit the scheme (Product → Scheme → Edit Scheme → Run → Arguments) and add
launch arguments:

| Argument | Effect |
|---|---|
| `-seed-demo-history` | On an empty store, adds two routines and three weeks of finished workouts (History, previous performance and summaries have data). |
| `-reset-store` | Deletes the local store and app settings before launch (fresh install). **Deletes your data.** |
| `-ui-dark-mode` | Forces dark appearance. |
| `-ui-testing` | Hermetic mode used by UI tests: no notification prompt, no Live Activity, no animations. |
| `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL` | Launch at a large accessibility text size. |

## Test it

In Xcode: ⌘U runs everything (Swift Testing unit suites in `fitbodTests`,
XCUITest journey + layout audit in `fitbodUITests`).

From a terminal (same commands CI runs):

```bash
scripts/ci/ios-ci.sh simulators   # create "Fitbod Small/Large" simulators
scripts/ci/ios-ci.sh build        # build-for-testing (one build)
scripts/ci/ios-ci.sh unit         # unit tests
scripts/ci/ios-ci.sh ui large     # UI journey + layout audit on the large iPhone
scripts/ci/ios-ci.sh ui small     # … and on iPhone SE
scripts/ci/ios-ci.sh evidence     # export screenshots + summary to .ci/evidence
```

Highlights of what is covered:

| Guarantee | Test |
|---|---|
| Workout survives terminate + relaunch (sets, typed values, rest timer) | `WorkoutJourneyUITests.testEndToEndWorkoutJourneySurvivesRelaunch` (UI) · `WorkoutPersistenceTests.workoutSurvivesRelaunch` (on-disk store reopened) |
| Rest timer computed from an absolute deadline; backgrounding/relaunch never resets it | `RestTimerPersistenceTests` |
| Workouts are snapshots; routine edits/deletes never rewrite history | `WorkoutPersistenceTests.routineEditsNeverRewriteHistory`, `SessionFactoryTests` |
| Validation (reps required; weight unless bodyweight), finish keeps only performed work | `WorkoutLogicTests` |
| Previous performance never reads the workout in progress | `WorkoutLogicTests.previousExcludesCurrentWorkout` |
| Layout at small/large iPhone, default/accessibility text, dark mode | `LayoutAuditUITests` (+ screenshots) |

### CI

`.github/workflows/ios.yml` builds and tests every push to `claude/**`
branches and every pull request on a GitHub-hosted macOS runner (the only
way agent sessions without a Mac can run `xcodebuild`). A commit whose
message contains `[evidence]` gets its screenshots and test summary
committed back to `docs/verification/ci/` when the build and every test
step pass, so that folder always reflects the last fully green run. The
workflow is optional for local development and can be disabled from the
Actions tab.

## Project layout

```
fitbod/
  App/            app shell: RootView (tabs + workout cover), AppRouter, Today, launch switches, demo data
  DesignSystem/   Chalkline tokens, components, appearance, component gallery
  ExerciseLibrary/ library, filters, detail, custom exercises, catalog importer
  Routines/       routines list, detail, builder, prescription editor
  Sessions/       workout logger, set rows, rest timer, summary, workout rules (WorkoutLogic)
  History/        history tab
  Settings/       units, progression defaults, plate inventory
  Models/ Persistence/ Prescription/   SwiftData models, versioned schema, progression math
fitbodTests/      Swift Testing unit + persistence suites
fitbodUITests/    XCUITest journey + layout audit
FitbodWidgets/    rest-timer Live Activity
docs/             design system, screen specs, verification, roadmap
```

## Data

Everything is stored locally with SwiftData (no account, no sync). The
store survives app updates; schema changes go through
`FitbodSchemaMigrationPlan`. Deleting the app deletes the data.
