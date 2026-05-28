# Testing Patterns

**Analysis Date:** 2026-05-28

## Test Framework Split — Confirmed

Stack guidance in `CLAUDE.md` says: Swift Testing for unit tests, XCTest for UI tests. The codebase follows this exactly.

| Target | Framework | File count | Evidence |
|--------|-----------|------------|----------|
| `fitbodTests/` | **Swift Testing** (`@Test`, `@Suite`, `#expect`, `Issue.record`) | 98 of 98 top-level `.swift` files | `grep -l "import Testing"` matches all 98; `grep -l "import XCTest"` matches zero |
| `fitbodUITests/` | **XCTest** (`XCTestCase`, `XCUIApplication`) | 17 of 18 | `import Testing` appears in only one auxiliary file; all 17 actual test classes inherit `XCTestCase` |

233 `@Suite` declarations across the unit-test target (some files declare multiple suites, e.g., one per BRU primitive). Total includes the `fitbodTests/Fatigue/`, `fitbodTests/Persistence/`, `fitbodTests/Phase6/`, and `fitbodTests/TestSupport/` subdirectories (not just the flat root).

Snapshot/image-diff testing is **not** used — confirmed by inspection; `BRUPeriodizationRegressionTests.swift:7` explicitly notes "Framework choice: XCTest body-structure assertions (NOT image-diff snapshots)." The string "snapshot" appears in a few tests but refers to value-equality snapshots of `@Observable` drafts (`CustomExerciseDraft.snapshot()`), not visual snapshots.

## Test File Organization

**Location:** Flat under `fitbodTests/` for the bulk of unit tests, with four small subdirectories:

- `fitbodTests/TestSupport/` — shared helpers (currently one file: `InMemoryContainer.swift`).
- `fitbodTests/Persistence/` — Schema V6 migration tests separated out (`SchemaV6MigrationTests.swift`). V1-V5 migration suites are still at the root (`SchemaV1Tests.swift`, `SchemaV2MigrationTests.swift`, `SchemaV3MigrationTests.swift`, `SchemaV4MigrationTests.swift`).
- `fitbodTests/Fatigue/` — 16 files covering fatigue model, deload advisor, body silhouette, weekly recap, plateau detection, 1RM estimator, volume zones, stimulus seeder.
- `fitbodTests/Phase6/` — export/backup/PR-detection tests, with sub-folders `Fixtures/csv/`, `Fixtures/json/` (real golden-file artifacts), `Support/`, `BRU/`.

**Naming:** `<FeatureName>Tests.swift`, suffixed by intent for variants:
- `*MigrationTests.swift` for schema migrations.
- `*BRUTests.swift` for BRU primitive contracts (`BRUCorePrimitivesTests`, `MuscleVolumeBarBRUTests`, etc.).
- `*CopyTests.swift` for UI copy assertions (`SessionLoggerCopyTests`, `RoutinesListBRUCopyTests`).
- `*GrepAuditTests.swift` for source-tree token audits.
- `*RegressionTests.swift` for tightly-scoped regression guards.

## Test Structure — Swift Testing

The canonical shape (`fitbodTests/PeriodizationEngineTests.swift:13-48`):

```swift
import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("PeriodizationEngine", .serialized)
struct PeriodizationEngineTests {
    private func makeBlock(...) -> Block { ... }

    @Test("phase resolves accumulation on day zero")
    func phaseOneInAccumulationOnDayZero() {
        let block = makeBlock()
        #expect(PeriodizationEngine.phase(for: block, on: block.startDate)?.kind == .accumulation)
    }
}
```

Conventions observed:

- `struct` test suites (not `class`) — instantiated fresh per `@Test`, so no shared state between tests. Each test starts with a clean container.
- `@Suite("HumanReadableName", .serialized)` — `.serialized` is used universally for suites that touch SwiftData or shared statics. Parallel test runs are not assumed.
- `@MainActor` at the suite level when any test touches `@Model` instances or SwiftUI components.
- `@Test("descriptive sentence")` — every test names what it asserts in plain English. Function names mirror the description in camelCase.
- `#expect(...)` for non-fatal assertions; `Issue.record(...)` for explicit failure cases that don't fit `#expect`. `#require` is also used but less common.
- Failure messages are passed as the trailing string to `#expect`, citing the source-of-truth artifact: `#expect(BRUDisplaySize.hero.pointSize == 56, "hero pointSize must be 56 per UI-SPEC v2 line 24")` (see `fitbodTests/BRUCorePrimitivesTests.swift:38`).

## In-Memory `ModelContainer` Pattern

Centralized in `fitbodTests/TestSupport/InMemoryContainer.swift`:

```swift
enum InMemoryContainer {
    static func makeEmpty() throws -> ModelContainer    // SchemaV1, hermetic
    static func makeCurrent() throws -> ModelContainer  // SchemaV6, hermetic
    static func makeWithFixture() -> ModelContainer     // PreviewModelContainer.make()
}
```

All three use `ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)` and register `FitbodSchemaMigrationPlan` so schema-version transitions are exercised. **41 test files** use `InMemoryContainer.*`; **59 test files** use `isStoredInMemoryOnly: true` directly (most of these are the schema-migration suites that need to bootstrap a specific historical schema rather than `.makeCurrent()`).

The pattern for schema-migration tests is: build an in-memory container at the *target* version with the *full* migration plan registered, then write fixtures and reopen. SwiftData runs the chain automatically. See `fitbodTests/SchemaV4MigrationTests.swift:49-58`.

## Fixtures and Test Data

- **`PreviewModelContainer.make(seedFixture:)`** is the shared production+test fixture factory (`fitbod/Persistence/PreviewModelContainer.swift`). Seeds 4 muscles + 2 exercises deterministically. Reused by both Xcode previews and `InMemoryContainer.makeWithFixture()` so previews and tests cannot drift apart.
- **`fitbodTests/Fatigue/FatigueTestFixtures.swift`** holds fatigue-domain fixtures used across the Fatigue subdirectory.
- **`fitbodTests/Phase6/Fixtures/PRFixtures.swift`** and **`SessionFixtures.swift`** hold export/PR-detection fixtures.
- **`fitbodTests/Phase6/Fixtures/csv/example-export.csv`** and **`json/example-export.json`** are real golden files for export round-trip tests.
- **`fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift`** locks the public name surface so renames break loudly.

## Coverage Shape — What's Tested

The unit-test target is dense and follows the build phases. Coverage by subsystem (file-name grouping):

| Subsystem | Coverage |
|-----------|----------|
| Schema / persistence / migration | `SchemaV1Tests`, `SchemaV2MigrationTests`, `SchemaV3MigrationTests`, `SchemaV4MigrationTests`, `Persistence/SchemaV6MigrationTests`, `EnumPersistenceTests`, `CascadeRuleTests`, `DTODecodingTests`, `IndexedQueryTests`, `SeedTests` |
| Periodization / blocks | `PeriodizationEngineTests`, `BlockBuilderViewActivationTests`, `BlockBuilderViewCopyTests`, `BlockCardWeekNavigationTests`, `BlockDraftSaveTests`, `BlockOverviewScreenWeekCarouselTests`, `BlockPeriodizedStrategyTests`, `BlockReviewMathTests`, `BlockReviewTriggerTests`, `BlocksSectionTests`, `BlockTemplatesTests`, `NewBlockBuilderFidelityTests`, `RoutineBlockLinkageTests`, `SessionBlockSnapshotTests`, `SingleActiveBlockInvariantTests`, `TodayViewBlockStackingTests`, `BRUPeriodizationAuditTests`, `BRUPeriodizationRegressionTests` |
| BRU design contract | `BRUCorePrimitivesTests`, `BRUCompositePrimitivesTests`, `BRUFoundationsTests`, `BRUPrimitivesTests`, `BRUGrepAuditTests`, `BRUPhase5GrepAuditTests`, `Phase3BRUGrepAuditTests`, `Phase3BRUPrimitivesTests`, `Phase3BRUSurfacesTests`, plus a *BRUTests / *BRUCopyTests file per consumer surface |
| Sessions / logger | `ActiveSessionConflictTests`, `AddUnplannedExerciseTests`, `MidSessionSwapTests`, `SessionFactoryTests`, `SessionFactoryPhase3Tests`, `SessionLoggerBRUCopyTests`, `SessionLoggerCopyTests`, `SessionWidgetsBRUCopyTests`, `SetRowCommitTests`, `SetTypeChip*` (under chip tests), `SupersetGroupTests`, `NotesPersistenceTests`, `PreviousColumnQueryTests`, `PreviousMatchingIntentTests` |
| Progression / prescription | `DoubleProgressionStrategyTests`, `HybridStrategyTests`, `RPEAutoregStrategyTests`, `ManualOverrideTests`, `PrescriptionDefaultsTests`, `PrescriptionEditorBlockCaseFilterTests`, `PrescriptionExplanationTests`, `ProgressionRoundingTests`, `TuchschererTableTests`, `WarmupConfigTests`, `WarmupRampTests`, `WarmupDeloadIntegrationTests`, `PlateCalculatorTests`, `PlateInventoryTests`, `StallBadgeBRUTests` |
| Fatigue / volume / recovery (`fitbodTests/Fatigue/`) | `DeloadAdvisorTests`, `FatigueModelWeeklyVolumeTests`, `FrequencyHitsTests`, `MuscleVolumeTargetSeederTests`, `OneRepMaxEstimatorTests`, `PlateauDetectorTests`, `StimulusWeightSeederTests`, `SuggestedActionTests`, `VolumeZoneTests`, `VolumeZoneVerbCopyTests`, `WeeklyRecapSheetBRUTests`, `WeeklyRecapTriggerTests`, `FatigueAdvisoryCanonicalityTests`, `DeloadVolumeApplicationTests`, `DeloadAdvisoryBannerBRUTests` |
| Export / backup / PRs (`fitbodTests/Phase6/`) | `BackupArchiverTests`, `BackupRoundTripTests`, `BackupVersionSkewTests`, `CSVExporterTests`, `JSONExporterTests`, `ZIPRoundTripTests`, `ExportDocumentSnapshotTests`, `InSessionPRStateTests`, `OneRepMaxTests`, `PRDetectorTests`, `PRsAndComparisonCopyTests`, `SeriesBuilderTests`, `SessionComparatorTests`, `WeeklyTonnageAggregatorTests`, `WeeklyTonnageFilterStateTests`, `WeeklyTonnageViewCopyTests`, `ExerciseProgressViewCopyTests` |
| Rest timer | `RestTimerActivityControllerTests`, `RestTimerBRUCopyTests`, `RestTimerEngineTests`, `RestTimerNotificationSchedulerTests`, `RestTimerOverlayCopyTests` |
| Routines | `RoutineBuilderBRUCopyTests`, `RoutineBuilderCopyTests`, `RoutineBuilderHeaderPickersTests`, `RoutineDraftValidationTests`, `RoutineDuplicationTests`, `RoutineFolderDraftTests`, `RoutinesListBRUCopyTests`, `RoutinesListCopyTests` |
| Exercise library | `CustomExerciseDraftTests`, `ExerciseHistoryIntentSplitTests`, `ExerciseHistoryViewCopyTests`, `ExerciseLibraryPickerModeTests`, `FilterStatePredicateTests`, `EmptyStateTests` |
| Settings | `SettingsUnitsIntegrationTests`, `UserSettingsTests`, `MuscleVolumeTargetEditorBRUTests`, `MuscleVolumeTargetStepperBRUTests`, `PerMuscleDetailViewBRUTests` |
| Today / history surfaces | `TodayViewBRUCopyTests`, `TodayViewBlockStackingTests`, `HistoryBRUCopyTests`, `SuggestedActionChipBRUTests`, `MuscleVolumeBarBRUTests` |

This maps almost 1:1 onto the architecture clusters in `ARCHITECTURE.md`. Every numbered phase plan in the project's `.planning/` history has at least one corresponding `*Tests.swift` file.

## SchemaV4MigrationTests — Hotspot

`fitbodTests/SchemaV4MigrationTests.swift` (226 lines, 11 `@Test` cases) is the Repowise-flagged test hotspot (5 commits in the last 90 days, 99.7th percentile churn). It exists because Phase 3.1's `intent` + `progressionKind` pivot moved per-exercise fields up to the per-session level, requiring a custom V3→V4 migration with most-common-value backfill and documented tie-break rules (`.strength` for intent ties, `.double` for progression ties).

The file follows the canonical migration-test shape: a `makeContext()` helper opens an in-memory container at `Schema(SchemaV5.models)` with the *full* `FitbodSchemaMigrationPlan` registered, so on-disk fixtures written at any prior schema migrate forward automatically. Tests 1-7 exercise pure helpers (entity-count freeze checks, nested-type identity vs top-level type identity via `ObjectIdentifier`, plan wiring assertions, `FitbodSchemaMigrationPlan.modeRaw(of:tieBreak:)` directly). Tests 8-10 are the end-to-end gates: write fixture rows at SchemaV3 into a file-backed store, close, reopen at SchemaV5, assert that SwiftData has run `migrateV3toV4` + `migrateV4toV5` correctly and that the V5 `Routine.intentRaw` / `Session.progressionKindRaw` fields hold the expected backfilled values. The high churn reflects the schema bumping from V4 → V5 → V6 — each new schema requires updating the migration-plan wiring assertions (`#expect(names == ["SchemaV1", ..., "SchemaV6"])` at line 94) and the entity-count freezes. The test file is the canonical correctness gate the project leans on, not a fragile suite.

## UI Tests — `fitbodUITests/`

XCTest with `XCUIApplication`. 17 test classes covering BRU surface smoke tests and a few interactive flows. Naming: `*BRUUITests.swift` for BRU-chrome render checks, `*UITests.swift` for feature flows. There is also `fitbodUITests/Phase6/` for the export/PR UI surface.

Shape (`fitbodUITests/Phase5BRUSmokeUITests.swift:26-70`):
```swift
final class Phase5BRUSmokeUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws { ... continueAfterFailure = false; app = XCUIApplication() }

    @MainActor private func waitForSeedComplete(timeout: TimeInterval = 60) { ... }
    @MainActor private func selectTodayTab() { ... }
    @MainActor private func scrollUntilVisible(text: String, maxSwipes: Int = 10) -> Bool { ... }
}
```

Conventions:
- Helpers are `@MainActor` private methods on the test class (no shared test-support layer for UI tests yet).
- First-launch seed of ~800 exercises is handled with a 60-second wait on the "Preparing library…" splash before any tab interaction.
- Tab selection is done by accessibility label on `tabBars.buttons["Today" | "Program" | "Progress" | "Settings"]`.
- Assertions are mostly `staticTexts[...].waitForExistence(timeout: ...)` — element-existence checks, not value or interaction checks.
- Empty-state branches are tolerated: if a precondition (active block, scheduled routine) isn't met, the test logs and skips instead of failing.

`fitbodUITests/fitbodUITests.swift` is the Xcode-template default and is effectively empty (`testExample` just launches the app and asserts nothing); it can be deleted or kept as the launch-performance harness (it does run `XCTApplicationLaunchMetric()` in `testLaunchPerformance`).

## CI / Test Plan Wiring — Gap

- **No `.xctestplan` files** exist anywhere in the repo (`find` returned zero matches).
- **No CI** — `.github/` is absent, no `fastlane/`, no `xcodebuild` wrapper in `scripts/`.
- **No shared Xcode scheme for the app target.** Only `FitbodWidgetsExtension.xcscheme` is in `xcshareddata/`. The `fitbod` app's test scheme lives in `xcuserdata/`, meaning test invocation is configured per-developer-machine.
- The single recurring CLAUDE memory note (`feedback_gsd_executor_chunk_skip_claudemd.md`) implies tests are run via `xcodebuild` from the command line as part of GSD execution, not via Xcode's GUI.

This is acceptable for a single-developer personal project but is the obvious gap if a second contributor or hosted CI is ever added.

## How to Run

From `CLAUDE.md` memory + observed comments in test files:
```bash
# Whole suite
xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'

# One suite
xcodebuild test -scheme fitbod -only-testing:fitbodTests/BRUCorePrimitivesTests

# UI tests run separately and must use a simulator (not a device target)
xcodebuild test -scheme fitbod -only-testing:fitbodUITests
```

(Note: the user-memory `feedback_gsd_executor_chunk_skip_claudemd.md` flags that `xcodebuild` output should be filtered when invoked from agents; SourceKit phantom diagnostics on Swift Testing files should be ignored in favor of `xcodebuild` truth.)

## Observable Coverage Gaps

- **`fitbod/App/RootView.swift`** is the highest-churn production file (99.9th percentile, 23 commits/90d) but has no dedicated unit-test file. It is exercised transitively via `TodayViewBlockStackingTests` and the UI-test smoke suites, but the tab-bar binding, `initialSelectedTab()` debug arg parsing, and pop-to-root re-tap binding are not directly asserted.
- **`fitbod/Settings/SettingsView.swift`** is the worst-health hotspot (7.6/10) and has only `SettingsUnitsIntegrationTests` — most of its 600+ lines are uncovered.
- **`fitbod/Sessions/SessionExerciseCard.swift`** (99.4th percentile churn) has no dedicated test file; covered indirectly by `SessionLoggerBRUCopyTests` and the UI logger smoke test.
- **No SwiftUI snapshot tests of any kind.** The trade-off (BRU grep audits + copy tests instead of visual snapshots) is intentional but means visual regressions are caught by eye only.

**Confidence:** High for framework split, file organization, in-memory-container pattern, fixture organization, and the SchemaV4 hotspot characterization (all directly verified by file inspection and grep). High for the gap list (CI / xctestplan / shared scheme absence is verified by `find` + `ls`). Medium for coverage shape — the per-subsystem file list is mechanical from filenames; what each test actually asserts has been spot-checked but not exhaustively read.
