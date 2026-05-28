# Codebase Structure

**Analysis Date:** 2026-05-28

## Directory Layout

```
fitbod/                              # Repo root
├── fitbod.xcodeproj/                # Xcode project (objectVersion 77, synchronized FS groups)
├── fitbod/                          # Main app target (~245 Swift files)
│   ├── fitbodApp.swift              # @main App — builds ModelContainer, hosts RootView
│   ├── Info.plist
│   ├── fitbod.entitlements
│   ├── App/                         # Root + first-launch lifecycle (2 files)
│   ├── Views/                       # Today-tab composites (9 files)
│   ├── Models/                      # SwiftData @Model entities (19 files + Enums/)
│   │   └── Enums/                   # Raw-string-backed domain enums (14 files)
│   ├── Persistence/                 # Versioned schemas + migration plan (8 files)
│   ├── Design/                      # BRU design system primitives (21 files)
│   ├── Routines/                    # Routine builder + folder mgmt (18 files)
│   ├── Sessions/                    # Active workout logger + rest timer (32 files)
│   │   └── RestTimer/               # Date-based engine + Live Activity bridge (7 files)
│   ├── Periodization/               # Blocks, phases, mesocycle week pages (19 files)
│   ├── Prescription/                # Progression strategies + plate calc + warmup (14 files)
│   ├── Progress/                    # Per-exercise charts, PRs, weekly tonnage (17 files)
│   ├── Fatigue/                     # MEV/MAV/MRV math + plateau detection + UI (21 files)
│   ├── ExerciseLibrary/             # Library browse, filter, custom editor, seed (23 files)
│   ├── Settings/                    # Units, volume targets, plate inventory editor (6 files)
│   ├── Export/                      # CSV / JSON export pipelines (6 files)
│   ├── Backup/                      # ZIP backup archive + restore (7 files)
│   ├── Assets.xcassets/             # BRU colorsets + volume-zone colorsets + AppIcon
│   └── Resources/
│       ├── ExerciseSeed/            # exercises.json, SEED_VERSION.txt, SOURCE.md
│       └── Fonts/                   # Space Grotesk, JetBrains Mono, Bebas Neue, Geist
├── FitbodWidgets/                   # Widget extension (6 files)
│   ├── FitbodWidgetsBundle.swift    # @main WidgetBundle
│   ├── RestTimerLiveActivity.swift  # ActivityConfiguration declaration
│   ├── RestTimerLockScreenView.swift
│   ├── RestTimerDynamicIslandCompactView.swift
│   ├── RestTimerDynamicIslandExpandedView.swift
│   ├── Info.plist
│   └── FitbodWidgets.entitlements
├── fitbodTests/                     # Swift Testing unit suites (~110 files)
│   ├── TestSupport/                 # In-memory container helper
│   ├── Fatigue/                     # FatigueModel, plateau, volume zone suites (16 files)
│   ├── Persistence/                 # SchemaV6 migration suite
│   └── Phase6/                      # Export, backup, PR/charts suites
│       ├── BRU/                     # BRU grep audit for Phase 6
│       ├── Fixtures/                # JSON + CSV golden fixtures
│       └── Support/                 # Schema-name regression
├── fitbodUITests/                   # XCUIApplication UI tests (~17 files)
│   └── Phase6/                      # Progress + Settings BRU UI smoke tests
└── .planning/                       # GSD planning artifacts (out-of-tree)
    ├── codebase/                    # This document + STACK / INTEGRATIONS / ARCHITECTURE
    └── graphs/                      # graphify snapshot — graph.json + GRAPH_REPORT.md
```

## Directory Purposes

**`fitbod/App/`** — App lifecycle.
- Contains: `RootView.swift` (the splash gate + tab bar host), `SeedState.swift` (`@Observable` seed lifecycle).
- Touch when: changing tab order, splash-vs-tabs gating, first-launch wiring.

**`fitbod/Views/`** — Today-tab composites and other shared composite views.
- Contains: `TodayView.swift` (Today root), `BlackSlabCTA.swift`, `BlockContextBand.swift`, `LiftListSection.swift`, `LiftListRow.swift`, `IntentChip.swift`, `ResumeWorkoutSlab.swift`, `TodayStatStrip.swift`, `WeekTickerCells.swift`.
- Touch when: editing the Today-tab layout above the lift list.

**`fitbod/Models/`** — SwiftData `@Model` entities (production V6 shape).
- 16 `@Model` classes + 1 Codable struct (`PlateSpec`) + `Exercise+Preview.swift` helper + `WarmupConfig.swift` Codable struct.
- Enums in `Models/Enums/` are NOT `@Model` — they are `String`-raw `Sendable` enums backing `*Raw: String` columns (FOUND-03).
- Touch when: adding a field → also add a SchemaV7 wrapper in `Persistence/` and a migration stage.

**`fitbod/Persistence/`** — Versioned schemas + migration plan.
- `FitbodSchemaMigrationPlan.swift` — single source of truth for the V1→V6 chain (5 stages, 2 custom).
- `SchemaV1.swift … SchemaV6.swift` — namespaced `VersionedSchema` wrappers. V1/V3 hold nested `@Model` classes for migrations that move fields; V4/V5/V6 use typealiases pointing at top-level `Models/` types because production runtime IS the latest version.
- `PreviewModelContainer.swift` — in-memory container factory for `#Preview` and tests, with a 4-muscle / 2-exercise fixture.

**`fitbod/Design/`** — BRU brutalist design system primitives.
- Tokens: `Color+BRU.swift` (12 adaptive color tokens), `BRUFont.swift` (7 semantic type roles).
- Chrome: `BRUHeaderBar.swift`, `BRUTabBar.swift`, `BRUDivider.swift`, `BRUSectionHead.swift`.
- Atoms: `BRUButton.swift`, `BRUChip.swift`, `BRUPillButton.swift`, `BRUCornerBadge.swift`, `BRUDashedSlot.swift`, `BRUDisplay.swift`, `BRUReadout.swift`, `BRUSpark.swift`, `BRUSupersetBracket.swift`, `BRUPhoneFrame.swift`, `BRUActionPopover.swift`.
- Composites: `CalibratingProgressMeter.swift`, `PlateStackViz.swift`, `PlateTallyRow.swift`, `SetCompletionGlyph.swift`.

**`fitbod/Routines/`** — Routine template builder.
- Entry: `RoutinesListView.swift` (no longer in tab bar; reached from Program tab's "+ NEW" menu), `RoutineBuilderView.swift` (the editor).
- Drafts: `RoutineDraft.swift`, `RoutineFolderDraft.swift`.
- Per-exercise editor: `PrescriptionEditorRow.swift` (hotspot — 467 lines), `PerSetOverrideRow.swift`, `SetRowsContainer.swift`, `WarmupConfigSheet.swift`.
- Composition: `RoutineRow.swift`, `RoutineExerciseCard.swift`, `BottomActionBar.swift`, `InlineExerciseSearchRow.swift`, `RoutineBuilderDayTabs.swift`, `MoveRoutineSheet.swift`, `NewFolderSheet.swift`, `SupersetAssignmentSheet.swift`, `RoutineDuplicator.swift`, `PrescriptionDefaults.swift`.

**`fitbod/Sessions/`** — Active workout + history.
- Entry: `SessionLoggerView.swift` (active workout root), `SessionHistoryView.swift` + `SessionHistoryRow.swift` + `SessionHistoryStatStrip.swift` (history list).
- Snapshot factory: `SessionFactory.swift` — the ONLY sanctioned entry point for `Routine → Session`.
- Card: `SessionExerciseCard.swift` (hotspot — 506 lines) — one card per snapshotted `SessionExercise`.
- Set rows: `SetRow.swift`, `SetTypeChip.swift`, `PrescriptionWeightCell.swift`, `PreviousColumn.swift`, `PreviousMatchingIntent.swift`, `PlateStackDisclosure.swift`, `WarmupRampRows.swift`, `TempoEntryRow.swift`, `PartialRepsRow.swift`, `ClusterSubRepChipRow.swift`, `InlineRPEChipRow.swift`, `DecimalRPEPickerSheet.swift`.
- Banners / chrome: `BumpBanner.swift`, `CalibratingBadge.swift`, `InSessionPRBanner.swift`, `InSessionPRState.swift`, `WorkoutHeaderToolbar.swift`, `WorkoutNotesSheet.swift`, `PinnedNoteCapsule.swift`, `PinnedNoteSheet.swift`, `PerSetNoteSheet.swift`, `ResumeWorkoutBanner.swift`, `WhyThisWeightSheet.swift`, `SwapExerciseSheet.swift`, `AddUnplannedExerciseButton.swift`, `WeeklyTonnageSparkCard.swift`.
- `RestTimer/` subfolder: `RestTimerEngine.swift` (`@Observable @MainActor`, Date-based — survives lock), `RestTimerActivityController.swift` + `RestTimerLiveActivityBridge.swift` (ActivityKit), `RestTimerNotificationScheduler.swift` (UNUserNotificationCenter), `RestTimerAttributes.swift` (shared with widget), `RestTimerOverlay.swift` (in-app overlay), `RestTimerProgressArc.swift`.

**`fitbod/Periodization/`** — Blocks + phases + mesocycle navigation.
- Entry: `ProgramView.swift` (Program tab root, BRU empty-state surface), `BlockBuilderView.swift` (full-screen editor for a new/edited block).
- Drafts: `BlockDraft.swift`, `BlockPhaseDraft.swift`.
- Templates / presets: `BlockTemplates.swift`, `StartBlockCTA.swift`, `BlockPickerMenu.swift`.
- Cards / rows: `BlockCard.swift`, `BlockRow.swift`, `BlockPhaseEditorRow.swift`, `BlockNameField.swift`.
- Week pages: `MesocycleWeekPage.swift`, `MesocycleWeekContext.swift`, `BlockOverviewScreen.swift`.
- Review: `BlockReviewView.swift`, `E1RMHelper.swift`.
- Banners: `ConsiderDeloadBanner.swift`, `DeloadWeekBanner.swift`.
- Tokens: `BlockPhaseColors.swift` (color rotation per phase).

**`fitbod/Prescription/`** — Progression math + plate calc + warmup ramp.
- Strategies: `ProgressionStrategy.swift` (protocol + `PrescriptionExplanation` + `HistoryPoint`), `DoubleProgressionStrategy.swift`, `RPEAutoregStrategy.swift`, `BlockPeriodizedStrategy.swift`, `HybridStrategy.swift`, `ProgressionStrategyFactory.swift`.
- Periodization math: `PeriodizationEngine.swift` (pure — phase/week resolution from a `Block`).
- RPE calibration: `Calibration.swift`, `TuchschererTable.swift`.
- One-rep-max: `OneRepMaxEstimator.swift`.
- Plate calc: `PlateCalculator.swift`.
- Warmup: `WarmupRamp.swift`.
- Advisories: `FatigueAdvisory.swift`, `StubFatigueAdvisory.swift`.

**`fitbod/Progress/`** — Read-side charts and views.
- Entry: `ProgressHomeView.swift` (Progress tab root, 3 sections: Recent / Trends / Compare).
- Drilldowns: `ExerciseProgressView.swift`, `ExercisePRsView.swift`, `WeeklyTonnageView.swift`, `SessionComparisonView.swift`, `WeekDetailView.swift`.
- Aggregators / detectors: `WeeklyTonnageAggregator.swift`, `MuscleVolumeProvider.swift`, `PRDetector.swift`, `SessionComparator.swift`, `SeriesBuilder.swift`, `OneRepMax.swift`.
- Filters / colors: `ChartFilterState.swift`, `WeeklyTonnageFilterChips.swift`, `ProgressFilterChip.swift`, `SeriesToggleChipRow.swift`, `ProgressColors.swift`.

**`fitbod/Fatigue/`** — Weekly volume / fatigue surface.
- Math: `FatigueModel.swift` (pure weighted-set rollup), `PlateauDetector.swift`, `RPVolumeLandmarks.swift`, `VolumeZone.swift`, `MondayAtMidnight.swift`, `DeloadAdvisor.swift`.
- Seeders: `MuscleVolumeTargetSeeder.swift`, `StimulusWeightSeeder.swift`, `StimulusWeightTable.swift`.
- UI: `FatigueSurfaceView.swift`, `BodySilhouetteView.swift`, `MuscleRegionPaths.swift`, `MuscleVolumeBar.swift`, `PerMuscleDetailView.swift`, `MuscleVolumeTargetStepper.swift`, `SuggestedActionChip.swift`, `StallBadge.swift`, `TryVariationSheet.swift`, `WeeklyRecapSheet.swift`, `DeloadAdvisoryBanner.swift`, `DeloadSignalDetailSheet.swift`.

**`fitbod/ExerciseLibrary/`** — Library browse + custom-exercise editor + seed.
- Entry: `ExerciseLibraryView.swift` (used as picker from RoutineBuilder), `ExerciseDetailView.swift`, `ExerciseHistoryView.swift` + `ExerciseHistoryRow.swift`.
- Seed: `ExerciseLibraryImporter.swift` (`@ModelActor`), `ExerciseDTO.swift` (decode shape), `SeedError.swift`, `EquipmentMapper.swift`, `MuscleRegionMap.swift`.
- Filters: `FilterState.swift`, `FilterChip.swift`, `FilterPickerSheet.swift`, `ExerciseFilterBar.swift`, `IntentFilterChipRow.swift`, `MusclePickerSheet.swift`.
- Custom: `CustomExerciseDraft.swift`, `CustomExerciseEditor.swift`, `CustomExerciseImagePicker.swift`.
- Rows: `ExerciseRow.swift`, `MuscleWeightRow.swift`, `PRStripFooter.swift`, `EmptyLibraryView.swift`, `ExerciseDeletion.swift`.

**`fitbod/Settings/`** — Settings tab.
- Entry: `SettingsView.swift` (hotspot — 832 lines; full reskin to BRU).
- Editors: `MuscleVolumeTargetEditor.swift`, `PlateInventoryEditor.swift`, `PlateCalculatorSheet.swift`.
- Seeders / defaults: `PlateInventorySeeder.swift`, `PlateInventory+Defaults.swift`.

**`fitbod/Export/`** — CSV / JSON exporters.
- `ExportService.swift` (`@ModelActor`), `CSVExporter.swift`, `JSONExporter.swift`, `CSVFile.swift` + `JSONFile.swift` (`FileDocument` wrappers for `ShareLink`), `ExportDTOs.swift`.

**`fitbod/Backup/`** — Full-store ZIP backup + restore.
- `BackupArchiver.swift` (`@ModelActor`), `BackupRestorer.swift`, `BackupManifest.swift`, `FitbodBackupFile.swift` (`FileDocument`), `UTType+FitbodBackup.swift`, `ZIPReader.swift`, `ZIPWriter.swift` (homegrown ZIP; no third-party dependency).

**`fitbod/Resources/ExerciseSeed/`** — Bundled yuhonas/free-exercise-db payload.
- `exercises.json` (~1.0 MB, ~800 entries; filtered to strength/powerlifting/olympic at seed time → ~702 inserted), `SEED_VERSION.txt` (integer stamp; bumped to invalidate `UserDefaults["exercise_seed_version"]`), `SOURCE.md` (Unlicense attribution).

**`fitbod/Resources/Fonts/`** — Embedded type.
- `SpaceGrotesk-Bold.ttf`, `SpaceGrotesk-SemiBold.ttf`, `JetBrainsMono-Bold.ttf`, `JetBrainsMono-Regular.ttf`, `BebasNeue-Regular.ttf` (Program empty-state hero only), `Geist-Regular.ttf` (Program empty-state body only), `LICENSES/` subdirectory.

**`fitbod/Assets.xcassets/`** — Adaptive colorsets.
- BRU palette (12): `bruInk`, `bruPaper`, `bruSignal`, `bruFaint`, `bruHair`, `bruMuted`, `bruBg`, `bruBg2`, `bruAmber`, `bruGreen`, `bruTabSurface`, `bruTabSeparator`.
- Volume-zone palette (4): `VolumeBelowMEVGray`, `VolumeOverMRVRed`, `VolumeNearMRVAmber`, `VolumeProductiveGreen`.
- Plus `AppIcon` and (legacy) `AccentColor` — note: `AccentColor` is banned in feature code per BRU contract; the colorset exists for the Xcode template but is unused.

**`FitbodWidgets/`** — Widget extension target.
- Single widget (`RestTimerLiveActivity`) wrapped in `FitbodWidgetsBundle`. Bridged from main app via `ActivityKit`. Cross-target color access via `fitbod/Design/Color+BRU.swift` (the same file is compiled into both targets, looking up adaptive colorsets in the shared asset catalog).

**`fitbodTests/`** — Swift Testing unit suites (mostly `@Test` + `#expect`).
- ~110 files at the top level. Notable buckets:
  - Schema: `SchemaV1Tests.swift`, `SchemaV2MigrationTests.swift`, `SchemaV3MigrationTests.swift`, `SchemaV4MigrationTests.swift` (hotspot — canonical V3→V4 backfill gate), `Persistence/SchemaV6MigrationTests.swift`.
  - Cascade / relationships: `CascadeRuleTests.swift`, `EnumPersistenceTests.swift`, `IndexedQueryTests.swift`.
  - Strategies: `DoubleProgressionStrategyTests.swift`, `RPEAutoregStrategyTests.swift`, `BlockPeriodizedStrategyTests.swift`, `HybridStrategyTests.swift`, `TuchschererTableTests.swift`, `ProgressionRoundingTests.swift`, `PrescriptionDefaultsTests.swift`.
  - Sessions: `SessionFactoryTests.swift`, `SessionFactoryPhase3Tests.swift`, `ActiveSessionConflictTests.swift`, `AddUnplannedExerciseTests.swift`, `MidSessionSwapTests.swift`, `ManualOverrideTests.swift`, `NotesPersistenceTests.swift`, `SetRowCommitTests.swift`, `SessionBlockSnapshotTests.swift`, `PreviousMatchingIntentTests.swift`, `PreviousColumnQueryTests.swift`.
  - Periodization: `PeriodizationEngineTests.swift`, `BlockBuilderViewActivationTests.swift`, `BlockBuilderViewCopyTests.swift`, `BlockCardWeekNavigationTests.swift`, `BlockOverviewScreenWeekCarouselTests.swift`, `BlockReviewMathTests.swift`, `BlockReviewTriggerTests.swift`, `BlockTemplatesTests.swift`, `BlockDraftSaveTests.swift`, `BlocksSectionTests.swift`, `SingleActiveBlockInvariantTests.swift`, `RoutineBlockLinkageTests.swift`.
  - Rest timer: `RestTimerEngineTests.swift`, `RestTimerActivityControllerTests.swift`, `RestTimerNotificationSchedulerTests.swift`, `RestTimerBRUCopyTests.swift`, `RestTimerOverlayCopyTests.swift`.
  - BRU contract: `BRUFoundationsTests.swift`, `BRUPrimitivesTests.swift`, `BRUCorePrimitivesTests.swift`, `BRUCompositePrimitivesTests.swift`, `BRUGrepAuditTests.swift`, `Phase3BRUGrepAuditTests.swift`, `BRUPhase5GrepAuditTests.swift`, plus per-surface `*BRUCopyTests.swift` / `*BRUTests.swift` files.
  - Plate: `PlateCalculatorTests.swift`, `PlateInventoryTests.swift`.
  - Fatigue subfolder: `Fatigue/FatigueModelWeeklyVolumeTests.swift`, `Fatigue/DeloadAdvisorTests.swift`, `Fatigue/PlateauDetectorTests.swift`, `Fatigue/VolumeZoneTests.swift`, `Fatigue/FrequencyHitsTests.swift`, `Fatigue/MuscleRegionPathsTests.swift`, `Fatigue/MuscleVolumeTargetSeederTests.swift`, `Fatigue/StimulusWeightSeederTests.swift`, `Fatigue/OneRepMaxEstimatorTests.swift`, `Fatigue/SuggestedActionTests.swift`, `Fatigue/BodySilhouetteViewBRUTests.swift`, `Fatigue/FatigueSurfaceViewBRUTests.swift`, `Fatigue/WeeklyRecapSheetBRUTests.swift`, `Fatigue/WeeklyRecapTriggerTests.swift`, `Fatigue/FatigueAdvisoryCanonicalityTests.swift`, `Fatigue/FatigueTestFixtures.swift`, `Fatigue/VolumeZoneVerbCopyTests.swift`.
  - Phase 6 subfolder: `Phase6/CSVExporterTests.swift`, `Phase6/JSONExporterTests.swift`, `Phase6/ExportDocumentSnapshotTests.swift`, `Phase6/BackupArchiverTests.swift`, `Phase6/BackupRoundTripTests.swift`, `Phase6/BackupVersionSkewTests.swift`, `Phase6/ZIPRoundTripTests.swift`, `Phase6/PRDetectorTests.swift`, `Phase6/SeriesBuilderTests.swift`, `Phase6/SessionComparatorTests.swift`, `Phase6/WeeklyTonnageAggregatorTests.swift`, `Phase6/WeeklyTonnageFilterStateTests.swift`, `Phase6/InSessionPRStateTests.swift`, `Phase6/OneRepMaxTests.swift`, plus `*CopyTests.swift` siblings, with `Phase6/Fixtures/` golden files (`csv/`, `json/`) and `Phase6/Support/SchemaNamesRegressionTest.swift`.
- Test helper: `TestSupport/InMemoryContainer.swift` (the canonical empty-store factory for tests that want a clean room).

**`fitbodUITests/`** — XCUIApplication smoke tests (XCTest-based — Swift Testing does not support UI automation).
- Top level: `fitbodUITests.swift`, `fitbodUITestsLaunchTests.swift`, `NewBlockModalUITests.swift`, `RoutineBuilderBRUUITests.swift`, `SessionLoggerBRUUITests.swift`, `SessionHistoryBRUUITests.swift`, `MuscleVolumeTargetEditorUITests.swift`, `PerMuscleDetailUITests.swift`, `BodySilhouetteUITests.swift`, `DeloadAdvisoryBannerUITests.swift`, `VolumeBarsUITests.swift`, `WeeklyRecapUITests.swift`, `PlateCalculatorSheetBRUUITests.swift`, `PrescriptionWeightCellBRUUITests.swift`, `WhyThisWeightSheetBRUUITests.swift`, `PlateauOverrideUITests.swift`, `Phase5BRUSmokeUITests.swift`.
- `Phase6/`: `ProgressChartBRUUITests.swift`, `ProgressHomeBRUUITests.swift`, `SettingsBRUUITests.swift`.

## Key File Locations

**Entry points:**
- `fitbod/fitbodApp.swift` — `@main struct fitbodApp: App`.
- `fitbod/App/RootView.swift` — splash gate + tab bar.
- `FitbodWidgets/FitbodWidgetsBundle.swift` — `@main struct FitbodWidgetsBundle: WidgetBundle`.

**Configuration:**
- `fitbod/Info.plist` — bundle metadata, `UIAppFonts`.
- `fitbod/fitbod.entitlements` — main app entitlements.
- `FitbodWidgets/Info.plist` + `FitbodWidgets/FitbodWidgets.entitlements` — widget extension.

**Core schema + migration:**
- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` — single source of truth for the V1→V6 chain.
- `fitbod/Persistence/SchemaV6.swift` — current production version (`Schema(SchemaV6.models)` is what `fitbodApp.init()` registers).
- `fitbod/Persistence/PreviewModelContainer.swift` — in-memory container factory for previews + tests.

**Testing:**
- `fitbodTests/TestSupport/InMemoryContainer.swift` — empty in-memory container for hermetic tests.
- `fitbodTests/Phase6/Fixtures/` — golden CSV / JSON fixtures for export round-trip tests.

## Hotspot Files

| File | Lines | Why it's hot |
|------|-------|--------------|
| `fitbod/App/RootView.swift` | 325 | Tab bar host, splash gate, seed task wiring, NavigationPath ownership. Frequently touched as new tab-level behavior lands. |
| `fitbod/Routines/PrescriptionEditorRow.swift` | 467 | 5-chip prescription row + collapsible Advanced section + per-set overrides. Touched on every change to per-exercise prescription UX. |
| `fitbod/Sessions/SessionExerciseCard.swift` | 506 | Per-exercise active-workout card. Hosts BumpBanner, CalibratingBadge, WarmupRampRows, StallBadge, SuggestedActionChip, PlateStackDisclosure, plus the SetRow grid. Phase 3/3.1/5 each added new wiring. |
| `fitbod/Settings/SettingsView.swift` | 832 | Single-screen settings root with 6 sections (Units & Calibration, Volume Targets, Smart Progression, Export, Backup, About) + share/file-importer wiring. Largest single view file. |
| `fitbodTests/SchemaV4MigrationTests.swift` | 226 | Canonical correctness gate for the PIVOT-03 V3→V4 custom backfill (intent / progressionKind hoist with mode-of-children tie-break). |

## Naming Conventions

**Files:**
- Views: `<Feature><Surface>View.swift` (e.g., `RoutineBuilderView`, `SessionLoggerView`, `ProgressHomeView`).
- Cards / rows: `<Subject>Card.swift` / `<Subject>Row.swift` (e.g., `SessionExerciseCard`, `LiftListRow`).
- Drafts: `<Entity>Draft.swift` (e.g., `RoutineDraft`, `BlockDraft`).
- Sheets: `<Subject>Sheet.swift` (e.g., `WhyThisWeightSheet`, `WarmupConfigSheet`).
- `@Model` entities: noun, no suffix (e.g., `Exercise`, `Routine`, `Session`, `SetEntry`).
- Schema wrappers: `SchemaV<N>.swift`.
- BRU primitives: `BRU<Atom>.swift` (e.g., `BRUButton`, `BRUChip`, `BRUDivider`).
- Tests: `<Subject>Tests.swift` for behavior, `<Subject>CopyTests.swift` for verbatim copy regressions, `<Subject>BRUTests.swift` for BRU contract.

**Directories:** `PascalCase`, plural noun for collections (`Models`, `Routines`, `Sessions`), feature-singular for domain areas (`Periodization`, `Fatigue`).

**Types:** All Swift symbols are `PascalCase`; enum cases `camelCase`. Persisted enum-backing fields end in `Raw: String` with a computed `var <name>: <Enum>` accessor in an extension (FOUND-03).

## Where to Add New Code

**New SwiftData field on an existing entity:**
1. Add field to the top-level `Models/<Entity>.swift` (must have a literal default value — FOUND-02).
2. Create `Persistence/SchemaV7.swift` (typealias-only if additive-lightweight; nested `@Model` if you need to keep the old shape readable).
3. Append a `MigrationStage` to `FitbodSchemaMigrationPlan.stages` + register `SchemaV7.self` in `schemas`.
4. Bump `fitbodApp.init()` to `Schema(SchemaV7.models)` and `PreviewModelContainer.make()` to match.
5. Add a `SchemaV7MigrationTests.swift` under `fitbodTests/` (or `fitbodTests/Persistence/`) — mirror the `SchemaV4MigrationTests` shape.

**New `@Model` entity:**
- Implementation: `fitbod/Models/<NewEntity>.swift`. Every property defaulted/optional; `@Attribute(.unique) var id: UUID = UUID()`.
- Enum-backed fields: corresponding raw-string enum in `fitbod/Models/Enums/`.
- Cascade rules: declare on the OWNING side via `@Relationship(deleteRule:inverse:)`. Forward sides are plain optionals.
- Wire into next `SchemaVn.models`.

**New SwiftUI view inside an existing feature:**
- Place beside siblings in the matching feature folder (e.g., a new session-time banner → `fitbod/Sessions/<Name>Banner.swift`).
- Use BRU primitives from `fitbod/Design/`. Do NOT introduce `Capsule`, `RoundedRectangle`, `Color.accentColor`, `Image(systemName:)` in chrome, or Apple HIG semantic fonts in feature code — the `*BRUGrepAuditTests` will fail.
- Hold ephemeral state via `@Observable` drafts; never wrap `@Query` in a view model.

**New feature (whole new area):**
- New folder under `fitbod/<NewFeature>/`. Xcode picks it up automatically (project uses `PBXFileSystemSynchronizedRootGroup`, objectVersion 77 — no `.pbxproj` edits required for new files).
- Tests in `fitbodTests/<NewFeature>Tests.swift` (or a subfolder if many).

**New progression strategy:**
- Implementation: `fitbod/Prescription/<Name>Strategy.swift` conforming to `ProgressionStrategy` (`Sendable`, value type, no `ModelContext`).
- Register in `ProgressionStrategyFactory.make(for:)`.
- Add corresponding `ProgressionKind` case in `fitbod/Models/Enums/ProgressionKind.swift`.
- Add `<Name>StrategyTests.swift` under `fitbodTests/` — mirror `DoubleProgressionStrategyTests`.

**New BRU primitive:**
- Implementation: `fitbod/Design/BRU<Atom>.swift`. Public init; document tokens used.
- Tests: `fitbodTests/BRUPrimitivesTests.swift` or `BRUCompositePrimitivesTests.swift`.

**New asset color:**
- Add a colorset to `fitbod/Assets.xcassets/` with adaptive light/dark variants.
- Expose via a `public static let` on `Color` in `fitbod/Design/Color+BRU.swift` (the cross-target API). Do NOT rely on the generated `Color.bru*` extensions — they are app-target-internal and not visible from `FitbodWidgets`.

**New `@ModelActor` background job:**
- Implementation: a `@ModelActor public final class` colocated with its domain (`fitbod/Export/`, `fitbod/Backup/`, `fitbod/ExerciseLibrary/`).
- Caller obtains `modelContext.container` and constructs the actor via the synthesized init.
- Idempotency: keep a `UserDefaults` version stamp (seed pattern) or a per-row flag (`userEditedWeight` / `userEdited`).

**New unit test:**
- Swift Testing for everything except UI: `import Testing` + `@Test` + `#expect`.
- Hermetic SwiftData: build via `InMemoryContainer.makeEmpty()` (test target) or `PreviewModelContainer.make(seedFixture: false)`.
- UI tests stay in `fitbodUITests/` using `XCUIApplication` (XCTest).

## Special Directories

**`fitbod/Backup/`** — Homegrown ZIP writer + manifest. Not generated; checked in.
- The ZIP code (`ZIPReader.swift`, `ZIPWriter.swift`) avoids a third-party dependency.

**`fitbod/Resources/ExerciseSeed/exercises.json`** — Vendored from `yuhonas/free-exercise-db` (Unlicense / public domain). Committed verbatim; `SOURCE.md` documents the provenance. Filtered at seed time to `["strength","powerlifting","olympic weightlifting","strongman"]` — cardio/stretching/plyometrics dropped.

**`fitbod/Resources/Fonts/`** — Five font files committed alongside `LICENSES/`. Registered via `UIAppFonts` in `Info.plist`. Bebas Neue + Geist are limited to the Program empty-state hero per inline comment in `ProgramView.swift`.

**`.planning/graphs/`** — `graphify` snapshot (graph.json + GRAPH_REPORT.md). Generated, not authored. Useful for community/module discovery; not used at runtime.

**`build/`, `graphify-out/`, `.gitnexus/`, `.repowise/`, `.claude/`** — Build outputs / tooling caches. Not part of the app target. Excluded via `.gitignore`.

**Xcode project model:** `fitbod.xcodeproj` uses synchronized file-system groups (`PBXFileSystemSynchronizedRootGroup`, `objectVersion = 77`). New files dropped into existing folders are picked up automatically — no manual `.pbxproj` edits required for typical adds. Adding a brand-new top-level folder under `fitbod/` requires an Xcode project sync (open the project once).

## Confidence

- **Direct-read (high confidence):** the directory tree (`find … -type d`), the per-folder file counts (`find | awk | sort | uniq -c`), the actual file lists in `App/`, `Models/`, `Models/Enums/`, `Persistence/`, `Design/`, `Periodization/`, `Sessions/`, `Sessions/RestTimer/`, `Routines/`, `Progress/`, `Fatigue/`, `Prescription/`, `ExerciseLibrary/`, `Settings/`, `Export/`, `Backup/`, `Views/`, `Resources/Fonts/`, `Resources/ExerciseSeed/`, `Assets.xcassets/`, `FitbodWidgets/`, `fitbodTests/` (top level + `Fatigue/`, `Persistence/`, `Phase6/` subdirs), `fitbodUITests/`. Hotspot line counts verified via `wc -l`. Hotspot rationale and BRU contract come from direct reads of each hotspot file's header.
- **Inferred from filename patterns:** the role of each file (e.g., "`BumpBanner.swift` = banner shown on weight bump in session card") is inferred from the name where the file wasn't read in full. The inference is corroborated for `SessionExerciseCard`, `PrescriptionEditorRow`, `RoutineBuilderView`, `SessionLoggerView`, `ProgramView`, `BlockBuilderView`, `RoutineDraft` (headers read) but is name-driven for the long tail.
- **Inferred from CLAUDE.md:** the Xcode project model details (`PBXFileSystemSynchronizedRootGroup`, objectVersion 77) come from in-file comments in `ProgramView.swift` and CLAUDE.md; the project file itself was not opened.
- **Test bucket categorization:** based on filename grouping, not on reading each test file.
