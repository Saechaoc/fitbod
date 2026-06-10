# Phase 7: Program Graph Schema V7 & Migration - Context

**Gathered:** 2026-06-10
**Status:** Ready for planning
**Mode:** Spec-derived (autonomous) — all grey areas were resolved in the approved design spec `.planning/quick/training-block-spec/program-graph-spec.md` through two adversarial review rounds. That spec is the authoritative contract; this file extracts the Phase 7 slice.

<domain>
## Phase Boundary

Schema V7 lands the program graph data layer and its migration — nothing user-visible. Deliverables: `Split` + `SplitSessionSlot` entities, `Routine`→`SessionTemplate` and `RoutineExercise`→`SessionExerciseTemplate` renames, Block additions (`split`, `schedulingMode`, `trainingDays`, `archivedConfigJSON`), logged-Session additions (`slot`, `templateName`, `routine`→`template` ref rename), the `ArchivedBlockConfig` Codable DTO type, custom V6→V7 migration stage, and `SchemaV7MigrationTests`. The scheduler, lifecycle service, and all UI are Phases 8–9.

Out of scope here: resolver logic, derived-status switch behavior beyond the computed property's existence, any view changes.

</domain>

<decisions>
## Implementation Decisions

All locked by spec (§ references to program-graph-spec.md):

### Entities & naming (§1, §3)
- Split entity is code-named `Split` (UI: "Routine"), NOT `Routine` — avoids SwiftData ghost-row migration hazard and git-archaeology ambiguity.
- `SessionTemplate` (was `Routine`), `SessionExerciseTemplate` (was `RoutineExercise`). Logged `Session` keeps its name.
- Aux entities `RoutineFolder`, `RoutineExerciseSetOverride`, `SupersetGroup` keep names — accepted naming debt; store-entity renames cost custom-stage row copies.
- `SplitSessionSlot` join: `split` ref, `sessionTemplate` ref, `position: Int`. Duplicate templates per split are legal (PPL ×2). Positions contiguous via reindex-on-write; contiguity is a TEST invariant — `#Unique` deliberately omitted (SwiftData upserts on collision → silent slot merge).
- `Block` gains: `split: Split?` (nil while draft), `schedulingMode` (.rotation default | .fixedWeekly), `trainingDays: [Int]` (Calendar weekday 1=Sun…7=Sat; sorted once at write via user's `Calendar.firstWeekday`; order canonical, never re-sorted at read), `archivedConfigJSON: String?`.
- `Session` gains: `slot: SplitSessionSlot?` (nil = ad-hoc), `templateName: String?` (log-time snapshot), `template` ref (renamed from `routine`).
- Block status is DERIVED, not stored — ordered switch: completed (endDate != nil) → active (isActive) → ready (split != nil && slotCount >= 1 && (rotation || trainingDays.count == slotCount)) → draft. `isActive` stays the only exclusivity bool.

### Delete rules (§3, §4)
- `SplitSessionSlot.sessionTemplate`: `.deny` (hard-delete refused while slotted; soft-delete via isArchived unaffected).
- `Block.split`: nullify (completed blocks survive split hard-delete — they render from archive).
- `Session.slot`: nullify — deleting a slot must NEVER touch logged history; nullified reads as ad-hoc.
- `Split.slots`: cascade.
- Conditional deny (no delete/archive of a split referenced by non-completed blocks) is Phase 8 service-layer logic — schema only carries the unconditional rules above.

### Archive DTO (§6)
- `ArchivedBlockConfig` — Codable struct, never `@Model` (project convention: no Codable on @Model). `"v": 1` stamped. Full BlockPhase field mirror + split name + slots ordered by position with session names + full SessionExerciseTemplate prescription mirrors + block name, dates, mode, trainingDays.
- Phase 7 ships the TYPE + decoder; the write-at-end-block transaction is Phase 8.

### Migration V6→V7 (§7) — seven steps, custom stage
1. `willMigrate`: stash old `Routine` rows — including each row's block ID from V6 `Routine.block` — and Session→Routine ID pairs, as plain structs (model objects don't cross stage boundary).
2. `didMigrate`: create `SessionTemplate` per stashed row; remap `Session.template` refs.
3. Per V6 block with attached templates: auto-create `Split` named "{block.name} split", slots in name-sorted order, mode `.rotation`. Completed blocks' auto-splits born `isArchived = true`.
4. Backfill `Session.slot` on the active block's last completed session (template's index in name-sorted auto-split) — rotation continuity across mid-block upgrade.
5. Backfill `Session.templateName` from remapped template names.
6. Best-effort `archivedConfigJSON` for pre-V7 completed blocks (drift accepted; readers never fall back to live templates).
7. Old `Routine.block` field dies with the entity.

### Tests (§7, §9 — Phase 7 slice)
- `SchemaV7MigrationTests` minimum assertions: ghost-free splits picker (only auto-splits exist, archived hidden), ref remapping, rotation continuity (step 4), archive backfill presence, templateName backfill.
- `Session.slot` delete-rule test (nullify, history intact).
- Slot-position contiguity invariant after reorder/add/remove.
- Deny-rule test: template hard-delete while slotted.

### Claude's Discretion
- Exact Swift file organization (new files in `fitbod/Models/` + `fitbod/Persistence/SchemaV7.swift` following V6's typealias pattern), enum raw-value storage convention (`*Raw: String` per project), test fixture shape (mirror SchemaV6MigrationTests / FatigueTestFixtures patterns).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fitbod/Persistence/SchemaV1.swift` … `SchemaV6.swift` — versioned-schema chain; V6 uses typealiases to top-level @Model types and `SchemaV5.models` passthrough. V7 follows the same shape.
- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` — registers [V1..V6] + 5 stages; V7 adds a sixth stage.
- Prior custom-stage precedents: V5→V6 (`migrateV5toV6` with `bumpPlateauToleranceDefault(in:)` internal helper — the extract-helper-for-testability pattern), V3→V4 backfill extraction (Phase 3.1).
- `SchemaV4MigrationTests` / `SchemaV6MigrationTests` — migration-test shape, including schemas.count / stages.count pinning assertions that WILL need a 7/6 refresh (known Rule-1 pattern: those counts break on every schema bump).
- `fitbod/Models/Block.swift`, `BlockPhase.swift`, `Routine.swift` (with `folderID: UUID?` soft ref), `RoutineExercise` (+ `RoutineExerciseSetOverride` cascade, `supersetGroupID: UUID?` soft ref), `Session`/`SessionExercise`/`SetEntry`.

### Established Patterns
- Versioned schemas + `SchemaMigrationPlan` from day one (project convention; every new field default-valued or optional).
- No `Codable` on `@Model` — DTO structs decoded then mapped (exercise seed pipeline precedent).
- Enums persisted as `*Raw: String`.
- SwiftData test suites: `@MainActor` + `.serialized`, in-memory `ModelContainer` over `Schema(SchemaVN.models)` + `FitbodSchemaMigrationPlan`.
- Don't assign relationships in initializers — insert into context first.
- GitNexus impact analysis before editing symbols; `gitnexus_rename` for the Routine/RoutineExercise renames (call-graph aware).

### Integration Points
- `fitbodApp.swift` + `PreviewModelContainer.swift` + test `InMemoryContainer` helpers reference the current schema version — flip to V7.
- Every consumer of `Routine`/`RoutineExercise` symbols across app + tests gets the mechanical rename (large but mechanical diff; Phase 3.1 rewired 25 suites for SchemaV4 — precedent exists).
- `Block.routines` to-many is REMOVED — `TodayView.todaysRoutine`, `ProgramView`, `BlockBuilderView` linked-routines band, and any other consumer must compile against the new shape. Phase 7 makes the minimal mechanical adaptation to keep the app compiling with existing behavior approximated (resolver comes in Phase 8); flag any behavior change in the SUMMARY.

</code_context>

<specifics>
## Specific Ideas

- Spec is authoritative: `.planning/quick/training-block-spec/program-graph-spec.md`. Where this file and the spec disagree, the spec wins.
- Migration must be tested against a seeded V6 store representing: active block with attached templates + completed sessions (continuity case), completed blocks (archived auto-split + backfilled archive case), orphan templates, blockless sessions.
- Keep the migration stage's stash structs `internal` so tests can drive them directly (mirrors `bumpPlateauToleranceDefault` testability pattern).

</specifics>

<deferred>
## Deferred Ideas

- Resolver, derived-status consumers, one-save lifecycle transactions → Phase 8.
- All surfaces (ProgramView rebuild, SplitDetailView, BlockOverviewScreen modes, banners) → Phase 9.
- Per-phase routine overrides, Progress-over-archives, top-level session-template library → v2+ (spec §11).

</deferred>
