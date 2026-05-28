# Codebase Concerns

**Analysis Date:** 2026-05-28

## Hotspots

### `fitbod/App/RootView.swift` (326 lines, 23 commits / 90d, 99.9th %ile churn)

Single view absorbs four orthogonal responsibilities: (1) seed orchestration (`runSeed()` at `fitbod/App/RootView.swift:220-252` chains exercise import + plate inventory seed + stimulus weight seed + muscle volume target seed), (2) splash gating (`shouldShowSplash` at `:123-131`), (3) the entire tab-bar UI (custom non-`TabView` `VStack`+`BRUTabBar` at `:169-206` — replaces the SwiftUI primitive because `.toolbar(.hidden, for: .tabBar)` does not work outside a `NavigationStack`), and (4) per-tab `NavigationPath` ownership (only `progressPath` is wired today; `today` / `program` / `settings` paths still TBD per `:158-162`). Recent commits churn the tab cast: `f477b0c` renamed Routines→Program, `3b0a2fa` removed Library tab, `9053c33` wired `BRUTabBar`, `5a3d677` deleted `PlaceholderTabView`. Each cycle re-edits the `Tab` enum, the `BRUTab` mapping (`:262-282`), and the seed payload, and any new tab will continue to require multi-section edits. **Fix approach:** extract `runSeed()` into a `SeedCoordinator` actor; lift the `Tab` enum + `BRUTabBar` wiring into a dedicated `TabRouter` view; keep `RootView` to splash-vs-router selection only.

### `fitbod/Periodization/BlockBuilderView.swift` (1,603 lines, 40 commits / 90d)

Largest source file in the app and the dominant churn surface this week (10 of the 10 most-recent commits, all `feat(new-block)…` / `refactor(new-block)…`). One Swift file holds the `BlockBuilderView` (top-level), 20 `fileprivate struct` subviews (`NewBlockTopBar`, `NewBlockNameBand`, `NewBlockMetricsBand`, `NewBlockTimelinePreview`, `NewBlockTimelineSegment`, `NewBlockDeloadStripes`, `NewBlockPhaseEditorRow`, `NewBlockInlineMetricColumn`, `NewBlockAddPhaseSlot`, `NewBlockAddPhaseTypeSheet`, `NewBlockLinkedRoutinesBand`, `NewBlockUndoToast`, `NewBlockBottomActionBar`, `NewBlockInkRule`, `NewBlockDurationSheet`, `NewBlockDaysSheet`, plus preset chip + stepper button helpers — markers at `:381`, `:468`, `:526`, `:573`, `:624`, `:692`, `:782`, `:983`, `:1197`, `:1361`, `:1424`, `:1589`), a fileprivate token system (`:381-466`), and a fileprivate preset palette + 5-slot ordered color scheme (per `260528-l4s-SUMMARY.md`). Active extraction has started — `BlockNameField.swift` was split out in quick task `260528-c6i` — but the file is still a magnet for every New Block iteration. **Fix approach:** continue per-band extraction following the `BlockNameField.swift` pattern (extract `NewBlockMetricsBand`, `NewBlockTimelinePreview`, `NewBlockPhaseEditorRow` into their own files); promote `NewBlockScreenTokens` out of `fileprivate` if reused elsewhere.

### `fitbod/Routines/PrescriptionEditorRow.swift` (467 lines, 6 commits / 90d, 99.6th %ile)

Single editor view holds 13 distinct sub-concerns (chip row + chip labels + advanced section + sets + reps range + RPE range + rest + tempo + partial reps + auto warm-up + per-set overrides + preview — `// MARK:` markers at `:44`, `:61`, `:82`, `:119`, `:159`, `:176`, `:215`, `:260`, `:277`, `:327`, `:338`, `:375`, `:451`). Was rewritten twice in 90 days: `0b9da46` ("Phase 2.1 Plan 05 REWRITE — replaces the 8-row VStack…") and `66a3f94` ("canonicalize PrescriptionEditorRow to 8-row layout"). The header comment at `:5-18` documents three prior structural rewrites; the chip-row + advanced-section duality means every prescription field has two visual representations to keep in sync. **Fix approach:** extract `chipRow`, `advancedSection`, and the per-axis editors (reps / RPE / rest / tempo / per-set overrides) into separate view files so the row file stays a layout coordinator.

### `fitbod/Sessions/SessionExerciseCard.swift` (506 lines, 9 commits / 90d, 99.4th %ile)

Card view owns Phase 3 prescription rendering + Phase 5 plateau detection + warm-up ramp wiring + plate stack disclosure + try-variation sheet + deload signal sheet + per-set notes + swap/remove context menu + pinned-note editing — 9 `@State`/`@Query`/`@Environment` properties (`fitbod/Sessions/SessionExerciseCard.swift:46-60`) and 6 callback closures (`:40-44`). Carries TWO `@Environment(\.modelContext)` injections (`ctx` at `:37`, `phase5ModelContext` at `:60`) because Phase 5 grafted onto the existing card without consolidating. Recent commits (`b8ed92c` BRU rewrite, `e465715` DeloadAdvisoryBanner mount, `734711c` StallBadge + SuggestedActionChip wire, `6c8cd18` BumpBanner + CalibratingBadge + WarmupRampRows + PrescriptionWeightCell + PlateStackDisclosure) each added a new sub-concern. **Fix approach:** collapse the two `modelContext` environments; extract Phase 5 plateau handling (`:305-347`, `plateauSignal` / `suggestedAction` / `presentingTryVariation` / `presentingDeloadSignalSheet`) into a child view or `@Observable` engine; pull `currentExplanation()` (`:373-443`) out into a free function under `Prescription/`.

### `fitbod/Settings/SettingsView.swift` (832 lines, 7 commits / 90d, 99.3th %ile)

Single Settings view threads 6 logical sections (Profile band, Units & Calibration, Volume Targets, Smart Progression, Export, Backup, About) plus 15 `@State` properties for export + backup + restore plumbing (`fitbod/Settings/SettingsView.swift:44-65`) including async render flags, file importer state, two-step destructive confirmation, preflight error routing, and a restorer reference. Recent commits each added a new section: `dee4b42` (lb/kg toggle), `0d99cbf` (Smart Progression), `c3426bb` (Volume Targets), `f786ffc` (Export CSV/JSON), `2c4f381` (Backup/Restore), `dc83f00` (BRU reskin Prescription Settings), `667d793` (BRU reskin — Form→ScrollView). The 06.1 BRU reskin (`667d793`) replaced Apple `Form`/`Section`/`navigationTitle` with `BRUHeaderBar` + `ScrollView` + `LazyVStack` + `BRURow`, but the file kept absorbing scope. **Fix approach:** extract each section (`exportSection`, `backupSection`, `smartProgressionSection`, etc.) into its own file under `fitbod/Settings/Sections/`; lift export + backup + restore async state into a `@Observable` `SettingsActionsCoordinator`.

## Architecture Smells

### Files over 500 LOC (14)

| Lines | File |
|---|---|
| 1,603 | `fitbod/Periodization/BlockBuilderView.swift` |
| 957 | `fitbod/Periodization/ProgramView.swift` |
| 859 | `fitbod/Fatigue/WeeklyRecapSheet.swift` |
| 832 | `fitbod/Settings/SettingsView.swift` |
| 662 | `fitbod/Periodization/BlockOverviewScreen.swift` |
| 656 | `fitbod/Sessions/WhyThisWeightSheet.swift` |
| 604 | `fitbod/Sessions/SessionFactory.swift` |
| 588 | `fitbod/ExerciseLibrary/ExerciseDetailView.swift` |
| 586 | `fitbod/Export/ExportDTOs.swift` |
| 570 | `fitbod/Backup/BackupRestorer.swift` |
| 524 | `fitbod/Periodization/BlockReviewView.swift` |
| 512 | `fitbod/Settings/PlateInventoryEditor.swift` |
| 511 | `fitbod/Routines/RoutinesListView.swift` |
| 506 | `fitbod/Sessions/SessionExerciseCard.swift` |

CLAUDE.md "Use the iOS 17 API surface" stack guide does not set a file-size limit, but the cluster around Periodization (`BlockBuilderView` 1,603 + `ProgramView` 957 + `BlockOverviewScreen` 662 + `BlockReviewView` 524 = 3,746 LOC across 4 files) is the strongest extraction candidate.

### TODO / FIXME / HACK comments (6 hits across 3 files)

- `fitbod/Periodization/BlockOverviewScreen.swift:87-91` and `:202` — `FIXME(v2): force re-init when the day rolls over` (week carousel goes stale past midnight; documented as intentionally deferred).
- `fitbod/Progress/SeriesToggleChipRow.swift:22`, `:44`, `:54` — `TODO: wire e1RM and VOLUME cells to chart series in a later iteration`. Three of the four series toggle cells are inert stubs.
- `fitbod/Sessions/PinnedNoteSheet.swift:7` — historical `TODO` reference (the comment notes the TODO was resolved). No live debt.

No `// HACK` / `// XXX` markers exist in the source tree.

### `try!` outside test scaffolding (12 hits)

`try! ModelContainer(...)` is the documented fast-fail for previews, but it has bled into production view files:

- `fitbod/Settings/PlateCalculatorSheet.swift:443`
- `fitbod/Periodization/BlockOverviewScreen.swift:606`
- `fitbod/Persistence/PreviewModelContainer.swift:47`
- `fitbod/Views/BlockContextBand.swift:139`
- `fitbod/Views/LiftListSection.swift:85`
- `fitbod/Views/LiftListRow.swift:116`
- `fitbod/Views/BlackSlabCTA.swift:138`
- `fitbod/Views/ResumeWorkoutSlab.swift:158`
- `fitbod/ExerciseLibrary/ExerciseHistoryView.swift:469`
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift:556`, `:566`

All are inside `#Preview { }` blocks (manually verified for `ExerciseDetailView.swift:556`, `BlackSlabCTA.swift:138`, `ResumeWorkoutSlab.swift:158`). Previews are not shipped, but the fan-out means a SchemaV6 migration that silently rejects a preview container would crash Xcode preview-by-preview rather than fail closed in one place. **Fix approach:** route all preview containers through `PreviewModelContainer.make(...)` — one site for the `try!`, callers stay clean.

### Silent SwiftData saves (15 hits)

`try? ctx.save()` / `try? context.save()` swallows persistence errors at write sites: `PlateInventoryEditor.swift:111,364,376,475`, `PlateInventorySeeder.swift:73`, `MuscleVolumeTargetEditor.swift:165`, `PlateCalculatorSheet.swift:453`, `MuscleVolumeTargetSeeder.swift:65`, `StimulusWeightSeeder.swift:81`, `PerMuscleDetailView.swift:282`, `RoutinesListView.swift:90,202,222,464`, plus `FitbodSchemaMigrationPlan.swift:126,200` and `CustomExerciseEditor.swift:289`. If SwiftData throws on save (constraint violation, disk full, schema mismatch) the UI proceeds as if the write succeeded; the next launch reads back the prior value. The pattern is also inside the V5→V6 migration `bumpPlateauToleranceDefault` (`fitbod/Persistence/FitbodSchemaMigrationPlan.swift:126`), where a silent failure would leave the tolerance un-bumped without telemetry. **Fix approach:** at minimum, log via `OSLog`; ideally route through a `PersistenceErrorCoordinator` that surfaces a banner in DEBUG and dispatches a `Logger.error(...)` in release.

### Cross-cutting logging is absent

- `OSLog.Logger` is imported and used in exactly ONE file: `fitbod/App/RootView.swift:53,70,249` (seed errors). All other `try?` swallow + `// FIXME` deferrals leave zero runtime telemetry.
- Zero `print()` calls in source (good — no stray debug output).

### Layering: views reaching into `modelContext.insert/fetch/save/delete` directly (6 files)

`fitbod/App/RootView.swift` (seed entry — acceptable), `fitbod/Export/ExportService.swift` and `fitbod/Backup/BackupArchiver.swift` (services — acceptable), but also `fitbod/ExerciseLibrary/CustomExerciseEditor.swift`, `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift` (importer — acceptable), and `fitbod/ExerciseLibrary/CustomExerciseDraft.swift` (a draft model — the only one that's a clear layering smell; the draft should hand back rows for the view to insert). CLAUDE.md's "MV-VM-lite per FOUND-06" pattern is mostly intact.

### `ObservableObject` / `@Published` / `@StateObject` in new code

Zero hits. The codebase is fully on `@Observable` (12 files: `App/SeedState.swift`, `Progress/ChartFilterState.swift`, `Progress/PRDetector.swift`, `Periodization/BlockDraft.swift`, `Periodization/BlockPhaseDraft.swift`, `Routines/RoutineDraft.swift`, `Routines/RoutineFolderDraft.swift`, `Sessions/InSessionPRState.swift`, `Sessions/RestTimer/RestTimerEngine.swift`, `ExerciseLibrary/FilterState.swift`, `ExerciseLibrary/CustomExerciseDraft.swift`, `ExerciseLibrary/CustomExerciseEditor.swift`). Matches CLAUDE.md "Don't mix `@Published` and `@Observable`."

### `fatalError` outside `fitbodApp.swift`

One: `fitbod/fitbodApp.swift:44` (`ModelContainer` creation failure — documented as intentional unrecoverable). No other `fatalError` calls in `fitbod/`. Healthy.

### Production-code force-unwraps

`try! ModelContainer` only (counted above). No `as!` / non-preview `try!` / implicit-unwrap (`!`) on production-path bindings were found. (The single `SeedError.swift:22` comment that mentions force-unwrap is documentation explaining the *avoidance* of one.)

## Test Gaps

### Hotspot views with no direct test file

| Hotspot | Tests touching it |
|---|---|
| `fitbod/App/RootView.swift` | **None** (no `RootView*Tests.swift`). `TodayViewBlockStackingTests.swift` exercises a subview only. |
| `fitbod/Periodization/BlockBuilderView.swift` | 3: `BlockBuilderViewActivationTests.swift`, `BlockBuilderViewCopyTests.swift`, `NewBlockBuilderFidelityTests.swift` (all source-string + copy guards, not behavior). |
| `fitbod/Routines/PrescriptionEditorRow.swift` | 4: `PrescriptionEditorBlockCaseFilterTests.swift`, `Phase3BRUGrepAuditTests.swift`, `RoutineBuilderBRUCopyTests.swift`, `RoutineBuilderCopyTests.swift`. |
| `fitbod/Sessions/SessionExerciseCard.swift` | 5: `SessionLoggerBRUCopyTests.swift`, `PrescriptionExplanationTests.swift`, `Phase3BRUGrepAuditTests.swift`, `SessionLoggerCopyTests.swift`, `OptionalRowRenderingTests.swift`. |
| `fitbod/Settings/SettingsView.swift` | 2 unit + 1 audit: `UserSettingsTests.swift`, `SettingsUnitsIntegrationTests.swift`, `Phase6/BRU/BRUGrepAuditPhase6Tests.swift`. |
| `fitbod/Views/TodayView.swift` (493 LOC) | 2: `TodayViewBlockStackingTests.swift`, `TodayViewBRUCopyTests.swift`. |

### Tests are skewed toward source-string / BRU-audit guards

Of 137 `*.swift` files in `fitbodTests/`, the majority are copy-verification or BRU-grep audits (`*BRUCopyTests`, `Phase3BRUGrepAuditTests`, `Phase3BRUSurfacesTests`, `BRUPeriodizationAuditTests`, etc.). Behavioral tests — `SessionFactoryTests`, `PlateauDetectorTests`, `DeloadAdvisorTests`, `FatigueModelWeeklyVolumeTests`, `SchemaV4MigrationTests`, `BackupRoundTripTests` — exist for engine + persistence layers but not for the hotspot views themselves.

### Test-to-source ratio

137 test files / 245 source files = 0.56. Not alarming for a personal SwiftUI app, but the test-file weight (24,933 LOC total) is concentrated in copy guards, not interaction.

## Design System Drift

### Adoption tally (CLAUDE.md mem `project_bru_design_system_unimplemented.md` — out of date)

The premise that "BRU is locked in 02-UI-SPEC.md but never shipped" is **no longer accurate** for committed code. Counts:

- **BRU primitives ship in `fitbod/Design/`** (20 components): `BRUActionPopover`, `BRUButton`, `BRUChip`, `BRUCornerBadge`, `BRUDashedSlot`, `BRUDisplay`, `BRUDivider`, `BRUFont`, `BRUHeaderBar`, `BRUPhoneFrame`, `BRUPillButton`, `BRUReadout`, `BRUSectionHead`, `BRUSpark`, `BRUSupersetBracket`, `BRUTabBar`, plus `Color+BRU`, `PlateStackViz`, `PlateTallyRow`, `SetCompletionGlyph`, `CalibratingProgressMeter`.
- **113 source files reference a `BRU*` symbol** (out of ~203 view-adjacent Swift files).
- **`Color.bru*` tokens: 979 hits**; `Color(.systemXXX)` Apple-HIG tokens: 51 hits (a 19:1 BRU-to-HIG ratio). The remaining `Color(.system…)` hits are in 1 file — likely accent / role-based color use.
- **`BRUHeaderBar` used by 36 surfaces**; SwiftUI `.navigationTitle` / `.navigationBarTitleDisplayMode` still used in 15 files (`PlateInventoryEditor.swift`, `MuscleVolumeTargetEditor.swift`, `DeloadSignalDetailSheet.swift`, `WeeklyRecapSheet.swift`, `TryVariationSheet.swift`, `DeloadAdvisoryBanner.swift`, `ExerciseProgressView.swift`, `WeekDetailView.swift`, `WeeklyTonnageView.swift`, `ProgressHomeView.swift`, `WarmupConfigSheet.swift`, `MoveRoutineSheet.swift`, plus `BRUHeaderBar.swift` itself and `PerMuscleDetailView.swift`).
- **`Form { }` survives in 4 files**: `fitbod/Sessions/PinnedNoteSheet.swift`, `fitbod/ExerciseLibrary/MuscleWeightRow.swift`, `fitbod/ExerciseLibrary/CustomExerciseEditor.swift`, `fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift`.
- **`List { }` (Apple HIG) used in 9 files** vs the BRU-style `VStack`/`LazyVStack` pattern that dominates elsewhere. List use is concentrated in `Sessions/` and `ExerciseLibrary/`.

**Updated assessment:** BRU adoption is high but not total. The drift is now **partial** rather than complete — specific holdouts in `ExerciseLibrary/`, a handful of sheets (`PinnedNoteSheet`, `WarmupConfigSheet`, `MoveRoutineSheet`), and parts of Progress + Fatigue still mix Apple HIG primitives with BRU chrome. CLAUDE.md memory pointer should be updated to "BRU is the default design system; ~5 surfaces still use Apple HIG primitives."

## Schema Migration Risk

### `fitbodTests/SchemaV4MigrationTests.swift` is in the hotspot list (5 commits / 90d, 99.7th %ile)

The V3→V4 stage is a CUSTOM migration (`fitbod/Persistence/FitbodSchemaMigrationPlan.swift:144-201`) backfilling `Routine.intentRaw` + `Routine.progressionKindRaw` + `Session.intentRaw` + `Session.progressionKindRaw` from per-exercise children (PIVOT-03). The closure body is extracted into `internal static func backfillSessionLevelFields(in:)` so the test suite can invoke it directly — but the comment at `:28-33` documents the only-real-protection: *"the user wiped + reseeded a fresh SchemaV3 database earlier today, so there are no real V3 rows that need migrating for v1 ship."* In production, the closure runs against an empty input by design.

### V5→V6 default-value bump (`fitbod/Persistence/FitbodSchemaMigrationPlan.swift:103-127`)

`bumpPlateauToleranceDefault` rewrites `UserSettings.plateauTolerance` from 0.005 → 0.02 *iff the existing value is within 1e-9 of 0.005*. Edge case: a user who manually set their tolerance to exactly 0.005 (the prior default) will silently get bumped to 0.02; a user who set 0.005000001 keeps their value. This is acceptable for a single-user personal app but is the kind of decision that breaks if the app ever ships. The `try? context.save()` at `:126` swallows write errors.

### 6 schema versions in 90 days

`SchemaV1.swift` … `SchemaV6.swift` — 5 migration stages registered (`FitbodSchemaMigrationPlan.swift:57-59`). Every version is still in `schemas: [...]` (`:53-55`), correct per Apple's docs, but every schema deprecation requires keeping the historical types compileable forever. The CUSTOM V3→V4 stage's `didMigrate` closure depends on `SchemaV3.RoutineExercise` and `SchemaV3.SessionExercise` nested types staying intact (`:168-169`); any future refactor that touches `SchemaV3.swift` risks silently breaking the V3→V4 path for the (currently empty) population of V3-shape stores.

## Planning ↔ Code Drift

### Quick task velocity has spiked (14 tasks in `260524*`–`260528*` window)

`260522-jgo`, `260524-ilf`, `260525-g32`, `260525-gen`, `260525-gop`, `260527-th4`, `260528-c6i`, `260528-cby`, `260528-dum`, `260528-ejb`, `260528-gox`, `260528-gr0`, `260528-l4s` — every commit between `1641dc6` and `f174380` is a New-Block iteration. The user is operating in rapid-iteration mode on the New Block screen, which explains the `BlockBuilderView.swift` churn but means design briefs in `bru-screens/New-block/` (untracked working-tree files) will continue to lag the committed implementation. The memory pointer `feedback_ui_briefs_lag_committed_code.md` is current and accurate.

### Untracked design assets

`bru-screens/New-block/` and `bru-screens/New-modal/` are present in the working tree but unignored AND untracked (`git status`). The committed `bru-screens/` directory holds `.jsx` mockups (`block-builder.jsx`, `block-overview.jsx`, etc.); the newer `.png`/`.html` assets live alongside but were never added. Pattern repeats with `.planning/quick/260528-c6i-extract-reusable-blocknamefield-swiftui-/` (planning artifact for the most recent quick task — untracked).

### Working-tree drift: `fitbod/Design/BRUActionPopover.swift` is untracked but **imported by committed code**

`fitbod/Periodization/ProgramView.swift:190` calls `BRUActionPopover(items: …)`. The component file `fitbod/Design/BRUActionPopover.swift` exists in the working tree but is untracked. The build only works because the file is on disk locally. **This is a real risk:** a `git stash`, `git clean -fd`, or fresh clone will break the build. Add to commit immediately.

### Tracked build artifacts

`git ls-files build/` returns 5,358 entries — `build/Release-iphoneos/`, `build/fitbod.build/`, `build/XCBuildData/`, etc. Total tracked files: 6,173, so **87% of tracked files are derived build artifacts**. The `.gitignore` (a single line, `fitbod.xcodeproj/xcuserdata/`) does not exclude `build/`. The branch is also 334 commits ahead of `origin/main`. **Fix approach:** add `build/`, `DerivedData/`, `*.xcuserstate`, `.DS_Store`, `*.dSYM`, `*.app`, `*.xcarchive`, `graphify-out/`, `.repowise/`, `.gitnexus/parse-cache/` to `.gitignore`; run `git rm -r --cached build/`; commit. Without this, every `xcodebuild` invocation produces a dirty working tree and ongoing diff noise.

## Build / Tooling Risk

### Personal team signing

CLAUDE.md confirms personal team distribution. Provisioning profiles for personal teams expire every 7 days — re-running from Xcode re-signs. Acceptable for a single-user developer install; flagged here only because it means the app cannot be left running on the device for >1 week without a Mac in arm's reach.

### No CI infrastructure

No `.github/` directory; no `Fastfile`; no `xcodebuild` wrapper scripts in `scripts/` (only `scripts/generate_app_icon.swift`). Every test run requires manual Xcode + Simulator on the dev machine. The 24,933 LOC test suite is gated only by what the developer chooses to run pre-commit.

### No SwiftLint, no `.swiftformat`, no `.swift-format` config

The CLAUDE.md stack guide flags SwiftLint as "Optional for v1" — that decision is currently being applied. `swift-format` ships with Xcode 16 but no build phase or pre-commit hook invokes it. Formatting consistency is maintained by author discipline alone.

### `.gitignore` is one line

`fitbod.xcodeproj/xcuserdata/` is the only ignored path. Everything else — `build/` artifacts, `.DS_Store`, `*.xcuserstate`, `.repowise/`, `.gitnexus/parse-cache/`, `graphify-out/`, `.claude/` runtime — relies on either `git add` discipline or post-hoc `git rm --cached`. See the tracked-build-artifacts entry above for the impact.

### 6,173 tracked files, branch 334 commits ahead of `origin/main`

The remote (`origin/main`) is materially behind the local branch. If the dev machine fails, the most recent 334 commits — including the entire BRU reskin, every recent New Block iteration, and the SchemaV5/V6 migration code — exist only on the local disk.

### No app extension target verification automation

Per memory pointer `project_extension_infoplist_not_in_resources.md`, the Xcode project pbxproj must be manually kept consistent (extension Info.plist must NOT appear in `PBXResourcesBuildPhase`). No script or pre-build check enforces this; a regression would surface as a duplicate-output build failure with no telemetry.

---

**Confidence:** HIGH for hotspot citations + file-path counts (every claim is `git log` / `grep` / `wc -l` verifiable). MEDIUM for risk severity — this is a single-user personal app, so "tech debt" reads differently than for a shipping product (e.g., `try? save()` swallowing a real persistence error is annoying for one user, catastrophic for thousands). LOW confidence on the migration-risk severity: V3→V4 backfill has no real-world V3 population to migrate per the migration plan's own header comment, so the risk is theoretical.

*Concerns audit: 2026-05-28*
