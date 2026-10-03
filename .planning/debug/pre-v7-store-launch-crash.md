---
status: resolved
trigger: "App crashes at launch when opening any pre-V7 on-disk store: SwiftData/SchemaEntity.swift:604: Fatal error: Inverse Relationship does not exist"
created: 2026-10-02
updated: 2026-10-03
---

# Debug: pre-V7 store launch crash

## Symptoms

- **Expected:** Installing the current build over an older install opens the existing store, walks the SwiftData migration chain forward to SchemaV7, and keeps all user data (exercises, routines, sessions, blocks).
- **Actual:** The app terminates during `ModelContainer` creation in `fitbodApp.init()`.
- **Error:** `SwiftData/SchemaEntity.swift:604: Fatal error: Inverse Relationship does not exist` (console via `xcrun simctl launch --console-pty`).
- **Timeline:** Introduced by the V7 program-graph refactor (Phase 7, commits 2026-06-10). A V6 store created 2026-05-25 crashes; V7 stores created 2026-06-11 open fine; fresh installs open fine.
- **Reproduction:**
  1. Build `main` @ 519673a for the iPhone 17e simulator (`E299C90A-F6A1-4324-A35B-FFB5541E0AB7`).
  2. Install the app, then replace `Library/Application Support/default.store*` in its data container with the V6 backup at `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/store-backups/EAE53A7A-70A6-43AB-BFF9-125B6537C549/`.
  3. Launch. The app dies with the fatal error above.
  - Helper script: `scratchpad/try-store.sh <backup-dir> <label>`.

## Current Focus

- **CHANGE OF PLAN (user decision, 2026-10-02), which overrides everything below:** this is a greenfield single-user app with no production data, so schema history is dropped instead of frozen. Do NOT continue the frozen-schema work and do NOT commit wip/frozen-schemas-wip.patch or any frozen SchemaV1-V6 code. New target:
  1. Keep only SchemaV7, with a header noting that it is the baseline and that history was reset on 2026-10-02.
  2. Delete SchemaV1-V6.swift and all migration stages and helpers from the plan (schemas = [SchemaV7.self], stages = []), and remove them from the project file.
  3. FitbodModelContainer.make(inMemory:) is the only way to build a container, and it uses Schema(versionedSchema: SchemaV7.self).
  4. Recover incompatible stores: move default.store, -shm and -wal to Application Support/IncompatibleStores/<ISO8601>/, log with os.Logger, then create a fresh store. Inject the store URL so recovery can be tested, and add a Swift Testing test for it.
  5. Delete the migration-only tests and fix the remaining Schema(SchemaVn.models) references in fitbodTests and fitbod/Persistence. List any references in UI files instead of editing them.
  6. E2E on the iPhone Air simulator over the V6 backup (moved aside) and a V7 backup (data intact). Run the unit tests with -parallel-testing-enabled NO.
  7. Update Resolution, commit only exact paths, and remove the hist worktrees.

- **ADDENDUM (user decision):** build the on-disk container from the baseline schema WITHOUT a migrationPlan. Keep the SchemaV7 VersionedSchema type for documentation. Delete FitbodSchemaMigrationPlan entirely if nothing else needs it. With no plan, SwiftData applies automatic lightweight migration for additive changes, and anything it cannot infer falls through to the move-aside recovery. In E2E, verify that a V7 backup still opens in place after an additive change, by simulating a throwaway optional or defaulted attribute in a test-only model. Do NOT edit fitbod/Models (the orchestrator is adding SessionExercise.exerciseNameSnapshot on branch m1-journey).

- status: RESUMED 2026-10-02. The WIP patch and FitbodModelContainer.swift have been re-applied to the working tree, which also keeps the debugger's fitbodTests edits: 39 files switched to FitbodModelContainer.make, plus the new TestSupport/MigrationStoreHarness.swift. Its last note before the rate limit: "Fix the InMemoryContainer doc comment, then build the tests." Previously PAUSED (usage limit reached). Nothing committed for this session. Commit 4f991f1 on main is from another session and is unrelated.
- hypothesis (confirmed by code reading, not yet by a fixed build): SchemaV1-V6 all reference live production `@Model` types (V4-V6 through typealiases, despite the earlier note). In V7 those types have relationships whose inverses point at V7-only entities (`SessionTemplate`, `SessionExerciseTemplate`, `Split`, `SplitSessionSlot`). SwiftData builds every schema in the migration plan while it looks for the store's source version, so any pre-V7 store crashes with "Inverse Relationship does not exist". Fix: freeze V1-V6 as self-contained nested snapshots, matched to the true era-end model sources.
- true era-end model source SHAs (see Evidence): V1=3ec52f7, V2=0e6f48b, V3=52ef02d, V4=4274de7, V5=96c9370, V6=612b60d.
- files touched (all reverted from the working tree, so app sources match HEAD and compile as before):
  - WIP saved as a patch: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/wip/frozen-schemas-wip.patch` (2625 lines). It covers FitbodSchemaMigrationPlan.swift, PreviewModelContainer.swift, SchemaV1-V6.swift and fitbodApp.swift. Its compile state was unverified when it was saved.
  - New file `fitbod/Persistence/FitbodModelContainer.swift` (shared container factory) moved to `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/wip/FitbodModelContainer.swift`.
  - No fitbodTests changes yet; the regression test is not written.
- generator script: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/gen_schema.py` emits frozen nested schemas from the git model sources. Other helpers: `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/bi.sh`, `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/v4ext.txt`.
- historical stores: DONE (the generator finished after the pause). See `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/hist/MANIFEST.md`. There are 9 builds (V1 b7fe9bb, V1clean 3ec52f7, V2 3db5f72, V2clean 0e6f48b, V3 52ef02d, V4 4274de7, V5 96c9370, V6 e3cc942, V6clean 612b60d), and each has a full store and a small store. The small stores are 276-360 KB, single-file and checkpointed. Each era folder also has HIST- user data, hashes.json, rowcounts.txt, models.txt and seed.patch. The b7fe9bb, 3db5f72 and e3cc942 builds are hybrids, so use the *clean stores for V1, V2 and V6. Every store records NSStoreModelVersionIdentifiers ["1.0.0"], so only the entity hashes tell the eras apart. The V6 builds needed BRUActionPopover.swift from a10e250, added only in the worktree. Worktrees are still registered and need cleanup at the end.
- reserved simulators (do not use): iPhone 17e E299C90A, iPhone 17 Pro Max B727BBEB. Allowed: iPhone 17 Pro 61A37501 (tests), iPhone Air 34AA5B29 (E2E), iPhone 17 DFD218A6 (historical store generation), and new `fitbod-dbg-` or `fitbod-hist-` simulators. The original `/private/tmp/claude-501/-Users-chrissaechao-Desktop-fitbod/b2492cc7-cf6c-449b-aa8f-c5d306df7945/scratchpad/try-store.sh` targets a reserved simulator, so do not run it.
- next_action:
  1. (done) Historical stores captured, see MANIFEST.md.
  2. (patch re-applied) Build the app and tests and fix compile errors.
  3. Compare each frozen schema's entity hashes (NSManagedObjectModel.makeManagedObjectModel(for:)) with the genuine stores and with the real V6 backup EAE53A7A.
  4. Check that each custom migration stage fetches the nested types of the correct version.
  5. Add the full-chain regression test with small fixtures and pinned hashes.
  6. Do E2E store swaps on the iPhone Air simulator, then run the test suites with -parallel-testing-enabled NO.
  7. Commit only the exact paths, with no co-author trailer.

## Evidence

- timestamp: 2026-10-02 — V6 store (2026-05-25, has ZROUTINE/ZROUTINEEXERCISE tables) crashes on launch with the fatal error. V7 store (2026-06-11) opens and runs.
- timestamp: 2026-10-02 — Schema model lists: V1/V2/V3 reference live types; V4/V5/V6 reference only `Self.` nested types; V7 uses `Self.` aliases.
- timestamp: 2026-10-02 — Existing migration tests use narrowed test-only plans (e.g. combined V6+V7 container), so the full production plan was never exercised against a real older store.

- timestamp: 2026-10-02 — ERA SHA CORRECTION. Orchestrator era SHAs b7fe9bb (V1), 3db5f72 (V2), e3cc942 (V6) are NOT era-pure model shapes: b7fe9bb is AFTER the V2 additive model edits (ee93f94, 028f139) but SchemaV1 still wrapped them; 3db5f72 is after the Phase 3 additive edits (70e4691, 3db5f72) while SchemaV2 still wrapped; e3cc942 is after the V7 rename (fb79723) so SchemaV6 there is a hybrid. TRUE era-end model sources: V1=3ec52f7, V2=0e6f48b, V3=52ef02d, V4=4274de7, V5=96c9370, V6=612b60d (fb79723^). Helper's V1/V2/V6 genuine stores (built from b7fe9bb, 3db5f72, e3cc942) therefore carry hybrid hashes; rebuild at the true SHAs. The real user V6 backup (2026-05-25) is the truth for V6.

- timestamp: 2026-10-02 — IMPLEMENTED (uncommitted, app builds): (1) python generator $SP/gen_schema.py rewrote fitbod/Persistence/SchemaV1..V6.swift as fully nested frozen snapshots from era-end model sources (V4 ext helpers appended to SchemaV4.swift); (2) FitbodSchemaMigrationPlan: V3->V4 now stashes in willMigrate from SchemaV3 nested RE/SE then applies in didMigrate to SchemaV4 Routine/Session (genuine V4 shape has NO child intentRaw; HEAD V4 had a hybrid retaining them); V5->V6 willMigrate fetches SchemaV5.UserSettings; V6->V7 stash uses SchemaV6.Session, didMigrate uses SchemaV7 aliases; (3) new fitbod/Persistence/FitbodModelContainer.swift (Schema(versionedSchema: SchemaV7), full plan) used by fitbodApp + PreviewModelContainer.
- timestamp: 2026-10-02 — E2E on iPhone Air with fixed build: real V6 backup (702 exercises) launches RUNNING, migrated store has 702 exercises, Z_METADATA identifier 7.0.0, SessionTemplate/Split tables present, relaunch OK. V7 backups (3 folders, identifiers 1.0.0) all launch RUNNING with Schema(versionedSchema:). Script: $SP/try-store-dbg.sh <sim> <dir> <label> [wait].
- TODO next: (a) fix tests that use Schema(SchemaV5/V6.models) + live types -> FitbodModelContainer.make(inMemory:true); update SchemaV4/V6/V7 migration tests; (b) new SchemaHistoryMigrationTests (hash pinning + full-chain fixture migration) once $SP/hist/MANIFEST.md exists (helper seems to use correct SHAs: wt-V1clean 3ec52f7, wt-V2clean 0e6f48b, wt-V6clean 612b60d); (c) run full suite -parallel-testing-enabled NO; (d) E2E all eras; (e) commit

- timestamp: 2026-10-02 (resume) — Build OK after adding `import CoreData` to MigrationStoreHarness. HASH FIDELITY VERIFIED: frozen SchemaV1..V6 entity hashes (dumped to $SP/frozen-hashes.json via temp ZZHashDumpTests, delete later) are IDENTICAL to genuine V1clean, V2clean, V3, V4, V5, V6clean and the real V6 backup EAE53A7A for every entity. Next: audit stages, write regression tests, E2E, full suite, commit.

- timestamp: 2026-10-02 (resume) — Stage audit OK (V3->V4 will=SchemaV3, did=SchemaV4; V5->V6 SchemaV5.UserSettings; V6->V7 stash SchemaV6, apply SchemaV7). Added fitbodTests/Persistence/{FrozenSchemaHashTests,FrozenSchemaHashes,HistoricalStoreMigrationTests}.swift + fitbodTests/Fixtures/HistoricalStores/V1..V6.store (small hist stores; test target is a synchronized group so no pbxproj edit). Both suites PASS (6+6+3 cases). Container decision: keep Schema(versionedSchema: SchemaV7) - V7 backups labelled 1.0.0 launch fine. Remaining: E2E all eras on iPhone Air, full suite, commits.

- timestamp: 2026-10-02 (reset implemented) - SchemaV1-V6, FitbodSchemaMigrationPlan, FrozenSchemaHash*, HistoricalStoreMigrationTests, HistoricalStores fixtures and MigrationStoreHarness deleted. Surviving non-migration model tests kept and renamed (ModelDefaultInitTests, RoutineFolderAndOverrideTests, PlateInventoryAndAdditiveFieldTests, BlockReviewedAtTests, Persistence/Phase5FieldDefaultsTests, Persistence/ProgramGraphInvariantTests). FitbodModelContainer.make(inMemory:storeURL:incompatibleStoresRoot:) builds Schema(versionedSchema: SchemaV7) with no plan and moves an unopenable store aside. New IncompatibleStoreRecoveryTests: (a) Exercise.name Int->String store throws "Can't find or automatically infer mapping model" and is moved aside, (b) older PlateInventory without updatedAt opens in place. Both pass. 3 UI #Preview blocks (BlockOverviewScreen, RoutineBuilderView, SupersetAssignmentSheet) switched to FitbodModelContainer.make(inMemory: true) because the plan no longer exists.
- timestamp: 2026-10-02 (E2E, iPhone Air) - Real V6 backup EAE53A7A does NOT throw without a plan: SwiftData infers a lightweight mapping (drops ZROUTINE/ZROUTINEEXERCISE, creates empty ZSESSIONTEMPLATE etc.), app RUNNING, 702 exercises kept, no IncompatibleStores dir. That backup holds 0 routines and 0 sessions so nothing was lost, but a V6 store WITH routines would lose them silently. V7 backup 85A62D29 opens in place: ZEXERCISE 702, ZBLOCK 3, ZMUSCLEGROUP 17, ZUSERSETTINGS 1 before and after.

## Eliminated

## Resolution

- root_cause: SchemaV1-V6 wrapped live @Model types whose V7 inverse relationships target V7-only entities. SwiftData builds every plan schema while it locates a store's source version, so any pre-V7 store hit SchemaEntity.swift:604.
- fix (2026-10-03, supersedes the frozen-schema fix): schema history was reset by user decision. SchemaV7 is the only VersionedSchema, the container is built by `FitbodModelContainer.make` with no migration plan, and a store SwiftData cannot open is moved aside into `IncompatibleStores/<timestamp>/` before a fresh store is created and re-seeded.
- history: the earlier frozen-schema fix (commits 1fd385a, 49344db, f850413) was never pushed. It was squashed into the single reset commit so history does not carry the frozen schemas or about 2 MB of historical store fixtures. The original commits stay reachable on branch `archive/frozen-schema-history`.
- verification: IncompatibleStoreRecoveryTests pass (an Int-to-String attribute change is moved aside; an additive change opens in place). On the iPhone Air simulator the real V6 backup opens through inferred lightweight migration with its 702 exercises kept, and a V7 backup opens in place with identical row counts. Full unit suite on 2026-10-03: 934 tests, 11 failures, all in the known baseline of stale source-introspection copy tests.
- files_changed: fitbod/Persistence/*, fitbod/fitbodApp.swift, three `#Preview` containers (BlockOverviewScreen, RoutineBuilderView, SupersetAssignmentSheet), fitbodTests
