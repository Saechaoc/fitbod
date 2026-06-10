# Phase 7: Program Graph Schema V7 & Migration - Research

**Researched:** 2026-06-10
**Domain:** SwiftData VersionedSchema / custom MigrationStage / entity rename
**Confidence:** HIGH (all findings from primary source inspection of the actual codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

All locked by spec (program-graph-spec.md):

**Entities & naming (§1, §3)**
- Split entity is code-named `Split` (UI: "Routine"), NOT `Routine` — avoids SwiftData ghost-row migration hazard and git-archaeology ambiguity.
- `SessionTemplate` (was `Routine`), `SessionExerciseTemplate` (was `RoutineExercise`). Logged `Session` keeps its name.
- Aux entities `RoutineFolder`, `RoutineExerciseSetOverride`, `SupersetGroup` keep names — accepted naming debt; store-entity renames cost custom-stage row copies.
- `SplitSessionSlot` join: `split` ref, `sessionTemplate` ref, `position: Int`. Duplicate templates per split are legal. Positions contiguous via reindex-on-write; contiguity is a TEST invariant — `#Unique` deliberately omitted (SwiftData upserts on collision → silent slot merge).
- `Block` gains: `split: Split?` (nil while draft), `schedulingMode` (.rotation default | .fixedWeekly), `trainingDays: [Int]` (Calendar weekday 1=Sun…7=Sat; sorted once at write; never re-sorted at read), `archivedConfigJSON: String?`.
- `Session` gains: `slot: SplitSessionSlot?` (nil = ad-hoc), `templateName: String?` (log-time snapshot), `template` ref (renamed from `routine`).
- Block status is DERIVED, not stored — ordered switch: completed → active → ready → draft. `isActive` stays the only exclusivity bool.

**Delete rules (§3, §4)**
- `SplitSessionSlot.sessionTemplate`: `.deny`
- `Block.split`: nullify
- `Session.slot`: nullify
- `Split.slots`: cascade

**Archive DTO (§6)**
- `ArchivedBlockConfig` — Codable struct, never `@Model`. `"v": 1` stamped.

**Migration V6→V7 (§7) — seven steps, custom stage**
1. `willMigrate`: stash old `Routine` rows (incl. block ID) + Session→Routine ID pairs, as plain structs.
2. `didMigrate`: create `SessionTemplate` per stashed row; remap `Session.template` refs.
3. Per V6 block with attached templates: auto-create `Split` named "{block.name} split", slots name-sorted, mode `.rotation`. Completed blocks' auto-splits born `isArchived = true`.
4. Backfill `Session.slot` on active block's last completed session.
5. Backfill `Session.templateName` from remapped template names.
6. Best-effort `archivedConfigJSON` for pre-V7 completed blocks.
7. Old `Routine.block` field dies with the entity.

**Tests (§7, §9 — Phase 7 slice)**
- `SchemaV7MigrationTests`: ghost-free splits picker, ref remapping, rotation continuity (step 4), archive backfill presence, templateName backfill.
- `Session.slot` delete-rule test (nullify, history intact).
- Slot-position contiguity invariant after reorder/add/remove.
- Deny-rule test: template hard-delete while slotted.

### Claude's Discretion
- Exact Swift file organization (new files in `fitbod/Models/` + `fitbod/Persistence/SchemaV7.swift` following V6's typealias pattern), enum raw-value storage convention (`*Raw: String` per project), test fixture shape (mirror SchemaV6MigrationTests / FatigueTestFixtures patterns).

### Deferred Ideas (OUT OF SCOPE)
- Resolver, derived-status consumers, one-save lifecycle transactions → Phase 8.
- All surfaces (ProgramView rebuild, SplitDetailView, BlockOverviewScreen modes, banners) → Phase 9.
- Per-phase routine overrides, Progress-over-archives, top-level session-template library → v2+ (spec §11).
</user_constraints>

---

## Summary

Phase 7 is a pure data-layer phase: schema V7, two new entities (`Split`, `SplitSessionSlot`), entity renames (`Routine`→`SessionTemplate`, `RoutineExercise`→`SessionExerciseTemplate`), field additions to `Block` and `Session`, the `ArchivedBlockConfig` Codable DTO, a seven-step custom V6→V7 migration stage, and `SchemaV7MigrationTests`. The UI keeps compiling with existing behavior approximated; the resolver comes in Phase 8.

The migration challenge is significant: the old `Routine` entity disappears entirely. SwiftData cannot "rename" an entity — rows must be manually stashed in `willMigrate`, then re-created as `SessionTemplate` rows in `didMigrate`. This is the same plain-struct stash pattern the V3→V4 stage used (`SchemaV3.RoutineExercise` nested types + `backfillSessionLevelFields`), but at entity level rather than field level.

The mechanical rename of `Routine`→`SessionTemplate` and `RoutineExercise`→`SessionExerciseTemplate` affects 69 files in the app target and 43 files in the test target (rg file-level count). This is large but mechanical — the plan should treat it as a single wave with sub-tasks per file cluster. Schema count pinning assertions in `SchemaV4MigrationTests` (schemas.count == 6, stages.count == 5) and `SchemaV6MigrationTests` (stages.count == 5) will break and need bumping to 7/6 respectively.

**Primary recommendation:** Mirror the V3→V4 nested-type pattern exactly. Declare `SchemaV6.Routine` and `SchemaV6.RoutineExercise` nested standalone `@Model` classes (V6 on-disk shape, including `Routine.block` relationship) in a new `SchemaV6Extension.swift` or inline in `SchemaV6.swift` extension, then stash `willMigrate` plain structs and reconstruct `SessionTemplate`/`SessionExerciseTemplate` in `didMigrate`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Entity rename (Routine→SessionTemplate) | Persistence / Schema | Models layer | SwiftData owns entity identity; app models follow |
| Custom migration stage | Persistence / MigrationPlan | — | FitbodSchemaMigrationPlan.migrateV6toV7 |
| New entities (Split, SplitSessionSlot) | Models layer | Persistence / SchemaV7 | New @Model types + typealias in V7 schema |
| Block new fields | Models layer | Persistence / SchemaV7 | Additive fields on existing @Model |
| Session new fields + ref rename | Models layer | Persistence / SchemaV7 | Mixed: additive + rename |
| ArchivedBlockConfig DTO | Models layer (new file) | — | Codable struct, not @Model |
| SchedulingMode enum | Models/Enums | Block @Model | *Raw: String persistence pattern |
| trainingDays [Int] storage | Models layer | Block @Model | Join-to-String pattern (see §trainingDays below) |
| Migration tests | fitbodTests/Persistence | — | SchemaV7MigrationTests |
| Mechanical call-site rename | All app + test files | — | 69 app files + 43 test files |
| Count-pinning assertion refresh | SchemaV4MigrationTests, SchemaV6MigrationTests | — | Must bump 6→7 (schemas) and 5→6 (stages) |

---

## Standard Stack

### Core (all verified against actual codebase)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 26.4 | Persistence, schema versioning, migration | Locked by project constraints |
| Swift Testing | iOS 26.4 | Unit tests (`@Test`, `#expect`, `.serialized`) | Project convention; `@MainActor + .serialized` for all SwiftData suites |

No external package installs for this phase. [VERIFIED: project codebase inspection]

---

## Package Legitimacy Audit

> No external packages are installed in this phase. All code is first-party Swift.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | N/A |

---

## Architecture Patterns

### System Architecture Diagram

```
V6 on-disk store (SQLite)
        │
        │  willMigrate closure
        ▼
[SchemaV6.Routine nested @Model rows] ──► plain struct stash (RoutineStash)
[Session rows with sourceRoutineID]   ──► plain struct stash (SessionRoutineStash)
        │
        │  SwiftData runs V6→V7 schema migration (entity list diff)
        │  - Routine table renamed/transformed
        │  - New tables: SessionTemplate, SessionExerciseTemplate,
        │                Split, SplitSessionSlot
        │  - Block: adds split, schedulingModeRaw, trainingDaysJoined, archivedConfigJSON
        │  - Session: adds slot, templateName, template ref (from sourceRoutineID)
        ▼
        │  didMigrate closure
        ▼
1. Create SessionTemplate per stashed Routine row
2. Remap Session.template → SessionTemplate rows
3. Create Split per V6 block (name-sorted slots from stash)
4. Backfill Session.slot on active block's last completed session
5. Backfill Session.templateName from template names
6. Backfill archivedConfigJSON for completed blocks
        │
        ▼
V7 store (post-migration)
  Split ──── SplitSessionSlot[] ──── SessionTemplate[]
  Block.split → Split?
  Session.template → SessionTemplate?
  Session.slot → SplitSessionSlot?
```

### Recommended Project Structure

```
fitbod/Models/
├── SessionTemplate.swift       # renamed from Routine.swift
├── SessionExerciseTemplate.swift  # renamed from RoutineExercise.swift
├── Split.swift                 # NEW
├── SplitSessionSlot.swift      # NEW
├── Block.swift                 # +split, +schedulingModeRaw, +trainingDaysJoined, +archivedConfigJSON
├── Session.swift               # +slot, +templateName, ~routine→template
├── Enums/SchedulingMode.swift  # NEW
├── ArchivedBlockConfig.swift   # NEW — Codable DTO
fitbod/Persistence/
├── SchemaV7.swift              # NEW — typealiases + nested V6 shape types for migration
├── FitbodSchemaMigrationPlan.swift  # +SchemaV7.self, +migrateV6toV7
fitbodTests/Persistence/
├── SchemaV7MigrationTests.swift  # NEW
```

### Pattern 1: Entity Rename via Plain-Struct Stash (V3→V4 precedent)

**What:** When SwiftData must rename an entity (a table), declare the old entity shape as a nested `@Model` inside the old VersionedSchema enum. In `willMigrate`, fetch all old rows via `FetchDescriptor<SchemaV6.Routine>()` and copy their fields into Sendable plain structs (NOT `@Model` objects — they don't cross stage boundaries). In `didMigrate`, create new `SessionTemplate` rows and wire relationships.

**When to use:** Any migration that adds, removes, or renames an entity (not just fields on existing entities).

**Example (V6→V7 willMigrate):**
```swift
// Source: SchemaV3.swift + FitbodSchemaMigrationPlan.swift (V3→V4 pattern)
// Internal stash struct — `internal` so SchemaV7MigrationTests can call the
// helper directly (same testability pattern as bumpPlateauToleranceDefault)
internal struct RoutineStash: Sendable {
    let id: UUID
    let name: String
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let isArchived: Bool
    let folderID: UUID?
    let blockID: UUID?       // from V6 Routine.block?.id — step 3 depends on this
    let intentRaw: String
    let progressionKindRaw: String
    // exercise IDs + prescription fields follow
}
```

**Why `willMigrate` (not `didMigrate`) for stash:**
The V6 `Routine` entity no longer exists after the schema migration runs. The stash must capture all needed data BEFORE SwiftData drops the table. Model objects fetched in `willMigrate` must NOT be held across the stage boundary — only value-type plain structs survive. [VERIFIED: SchemaV3.swift comment + FitbodSchemaMigrationPlan.swift migrateV3toV4 pattern]

### Pattern 2: Nested `@Model` in VersionedSchema for Cross-Stage Type Access

**What:** To read V6-shape rows in `willMigrate`, `SchemaV6` (or a new `SchemaV6Migration.swift` extension) must declare nested standalone `@Model` classes mirroring the V6 entity shapes. The project already has this pattern in `SchemaV3.swift` for `SchemaV3.Routine`, `SchemaV3.Session`, `SchemaV3.RoutineExercise`, `SchemaV3.SessionExercise`.

**Critical details from SchemaV3.swift:**
- Inverse keypaths on nested types must reference the nested form (`SchemaV3.RoutineExercise.routine` → `SchemaV3.Routine`). Cross-schema inverses are omitted on the nested side.
- `#Index` macros are intentionally omitted from nested types (the `#Index<T>` macro can't resolve qualified type names through the enclosing enum namespace).
- The nested type list in `SchemaV6.models` currently returns `SchemaV5.models` (a passthrough). For V7, SchemaV6 must declare its own `models` array that INCLUDES the nested `SchemaV6.Routine` and `SchemaV6.RoutineExercise` types.

**V6 shape fields needed for migration:**
```swift
// SchemaV6.Routine nested type — must include Routine.block relationship
// so willMigrate can capture blockID (step 3 in §7)
@Model final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var block: fitbod.Block? = nil   // reference top-level Block (unchanged entity)
    var folderID: UUID?
    var intentRaw: String
    var progressionKindRaw: String
    // exercises: [SchemaV6.RoutineExercise]  (needed if migrating exercise rows too)
    init() {}
}
```

[VERIFIED: SchemaV3.swift nested @Model pattern — lines 95–193]

### Pattern 3: `trainingDays: [Int]` Storage — Join-to-String, NOT Native Array

**What:** SwiftData on iOS 18 does NOT support native `[Int]` (or other scalar array) storage on `@Model` types without a Transformable. The project's established pattern (see `SetEntry.clusterSubRepsJoined`) is to store the array as a `String?` column with a computed accessor that encodes/decodes.

**Confirmed from SetEntry.swift:**
```swift
// Stored column:
public var clusterSubRepsJoined: String? = nil
// Computed accessor:
public var clusterSubReps: [Int] {
    get { joined.split(separator: ",").compactMap { Int($0) } }
    set { clusterSubRepsJoined = newValue.map(String.init).joined(separator: ",") }
}
```

**Apply the same pattern to `Block.trainingDays`:**
```swift
// Persisted column (additive, default ""):
public var trainingDaysJoined: String = ""
// Computed accessor (sorted-once-at-write contract per spec §3):
public var trainingDays: [Int] {
    get {
        guard !trainingDaysJoined.isEmpty else { return [] }
        return trainingDaysJoined.split(separator: ",").compactMap { Int($0) }
    }
    set {
        trainingDaysJoined = newValue.map(String.init).joined(separator: ",")
    }
}
```

Note: iOS 26.4 target — SwiftData on latest iOS may support native `[Int]` via `@Attribute(.transformable(...))`. However, the established project pattern avoids `Transformable` wrappers entirely (no existing use in the codebase), and the join-to-String approach is battle-tested, migration-friendly, and requires zero custom type-transformer registration. [ASSUMED — native [Int] support on iOS 18+ SwiftData not confirmed via Context7/official docs in this session; join-to-String is the safe conservative choice matching project precedent]

### Pattern 4: Enum Persistence — `*Raw: String` Convention

**What:** Project convention (FOUND-03 / PITFALLS #9) — all enums on `@Model` types persist as `*Raw: String` with computed accessors. Never use native Swift enum types directly on `@Model`.

**`SchedulingMode` implementation:**
```swift
// fitbod/Models/Enums/SchedulingMode.swift
public enum SchedulingMode: String, CaseIterable, Sendable {
    case rotation
    case fixedWeekly

    public static let `default`: SchedulingMode = .rotation
}

// On Block:
public var schedulingModeRaw: String = "rotation"
public var schedulingMode: SchedulingMode {
    SchedulingMode(rawValue: schedulingModeRaw) ?? .rotation
}
```

[VERIFIED: BlockPhase.swift + BlockPhaseKind.swift + Intent.swift — identical pattern]

### Pattern 5: Delete Rule Declaration — Single-Sided Inverse Convention

**What:** Project convention (Block.swift header comment: "inverse declaration lives on `Block.routines` so the inverse keypath chain is single-sided"): declare the `@Relationship` on only ONE side; SwiftData infers the inverse. For new entities:

```swift
// Split.swift
@Relationship(deleteRule: .cascade, inverse: \SplitSessionSlot.split)
public var slots: [SplitSessionSlot]? = []

// SplitSessionSlot.swift
public var split: Split? = nil        // inverse declared on Split.slots above
// sessionTemplate DENY rule declared here:
@Relationship(deleteRule: .deny)
public var sessionTemplate: SessionTemplate? = nil

// Block.swift (new field — nullify is SwiftData default for optional ref)
public var split: Split? = nil   // no @Relationship decorator needed; default nullify

// Session.swift (new field)
public var slot: SplitSessionSlot? = nil  // nullify (default)
public var template: SessionTemplate? = nil  // replaces sourceRoutineID soft ref
```

[VERIFIED: Block.swift line 36 `@Relationship(inverse: \Routine.block)` + Routine.swift line 51 `@Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)`]

### Pattern 6: Migration Helper Extraction for Testability

**What:** MigrationStage closure bodies are not directly invokable from tests. Extract the logic into `internal static` methods on `FitbodSchemaMigrationPlan`. Tests call the helper directly against an in-memory context.

```swift
// FitbodSchemaMigrationPlan
public static let migrateV6toV7 = MigrationStage.custom(
    fromVersion: SchemaV6.self,
    toVersion: SchemaV7.self,
    willMigrate: { context in
        try Self.stashV6Routines(in: context)
    },
    didMigrate: { context in
        try Self.materializeSessionTemplates(in: context)
    }
)

// Extracted helpers (internal for test access):
internal static func stashV6Routines(in context: ModelContext) throws { ... }
internal static func materializeSessionTemplates(in context: ModelContext) throws { ... }
```

[VERIFIED: FitbodSchemaMigrationPlan.swift `bumpPlateauToleranceDefault` + `backfillSessionLevelFields` — exact pattern]

### Anti-Patterns to Avoid

- **Holding @Model objects across stage boundary:** `willMigrate` model objects become invalid after the stage completes. Stash everything as plain `struct`s (Sendable value types). [VERIFIED: SchemaV3.swift comment on cross-stage boundary]
- **`#Unique` on (split, position) to enforce contiguity:** SwiftData upserts on unique-key collision, silently destroying a slot. Use test invariant instead. [LOCKED: spec §3]
- **`Codable` on `@Model`:** Project convention forbids this (CLAUDE.md). `ArchivedBlockConfig` is a plain Codable struct, never `@Model`.
- **Reusing `Routine` as the name for `Split`:** SwiftData inferred migration matches entities by name. Reusing "Routine" would carry V6 template rows into the V7 split entity as ghosts.
- **Assigning relationships in init:** Insert into context first, then assign relationships.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Entity row copy during migration | Manual SQL or JSON roundtrip | SwiftData `FetchDescriptor` + plain struct stash + `didMigrate` create | The V3→V4 pattern handles all edge cases; manual SQL bypasses SwiftData relationship wiring |
| Slot position uniqueness | `#Unique(SplitSessionSlot, [split, position])` | Test invariant + reindex-on-write | SwiftData upserts on collision → silent slot merge |
| `[Int]` storage | Native `[Int]` property on `@Model` | Join-to-String pattern (`trainingDaysJoined: String`) | Established project pattern; no Transformable registration needed |

---

## Critical Call-Site Inventory

### `Block.routines` Consumers (REMOVED in V7)

All of these need minimal mechanical adaptation to keep the app compiling. Phase 7 makes the app compile — it does NOT need to implement the full resolver behavior (that's Phase 8). Replace `block.routines` with a nil/empty stub, a `block.split?.slots` read, or a `TODO Phase 8` comment depending on context.

| File | Line(s) | Current Usage | Phase 7 Minimal Adaptation |
|------|---------|--------------|---------------------------|
| `fitbod/Views/TodayView.swift` | 369, 374, 375 | `(block.routines ?? []).filter { !$0.isArchived }` → weekday-based heuristic | Replace with `nil` / empty → today's routine = nil until Phase 8 resolver |
| `fitbod/Periodization/BlockBuilderView.swift` | 77 | `editing?.routines?.count ?? 0` for linked-routines band count | Replace count with `editing?.split?.slots?.count ?? 0` or 0 |
| `fitbod/Periodization/BlockOverviewScreen.swift` | 209, 216, 230, 355, 503 | Multiple uses of `(block.routines ?? [])` for session filtering and count | Replace with `block.split?.slots` reads or compile-stubbed |
| `fitbod/Periodization/MesocycleWeekPage.swift` | 104 | `(block.routines ?? []).sorted { $0.name < $1.name }` | Replace with `block.split?.slots?.sorted { $0.position < $1.position }` |
| `fitbod/Sessions/SessionFactory.swift` | (multiple) | `routine:` parameter type is `Routine` | Must accept `SessionTemplate` after rename |
| `fitbod/Export/ExportDTOs.swift` | 74 | `routines: [ExportRoutineDTO]` in ExportDocument | Rename to `sessionTemplates: [ExportSessionTemplateDTO]` OR keep as-is (backward compat) |
| `fitbod/Backup/BackupRestorer.swift` | 407 | `for dto in doc.routines` | Update to `sessionTemplates` |
| `fitbod/Export/ExportService.swift` | 281 | `sourceRoutineID` in session DTO | Update |

### `Session.sourceRoutineID` / `Session.routineSnapshotName` Consumers

These are SOFT references that survive the rename in V7. The spec §3 adds a proper `template: SessionTemplate?` relationship. In V7:
- `sourceRoutineID: UUID?` becomes redundant (replaced by `template: SessionTemplate?` relationship) — BUT it may need to stay for backward-compat with the backup format. Decision: keep `sourceRoutineID` as a deprecated field in V7 or remove it and update backup DTOs. [ASSUMED: spec says rename `routine` to `template` ref, implying the relationship, not the soft UUID — verify against spec §3 "Session.template: renamed from routine"]
- `routineSnapshotName: String` is replaced by `templateName: String?` (new V7 field). The old field should remain for backward-compat or be dropped from the schema.

**Important: spec §3 shows `Session.template: SessionTemplate?` as a SwiftData relationship (not just UUID), AND `Session.templateName: String?` as a new snapshot field. The existing `Session.sourceRoutineID: UUID?` + `Session.routineSnapshotName: String` are the V6 soft-reference pair. In V7:**
- `sourceRoutineID` → V6 entity; in V7 the relationship `template: SessionTemplate?` is the canonical link
- `routineSnapshotName` → replaced by `templateName: String?`

These fields have widespread test usage (BackupRoundTripTests, SessionFactoryTests, etc.). The migration must copy `sourceRoutineID` → `template` (remap via UUID lookup) and `routineSnapshotName` → `templateName`. Whether old fields are removed or kept as deprecated depends on backup format backward-compat. [ASSUMED: unless spec explicitly removes them, keeping them as deprecated/unused in V7 is safest; planner should flag this for decision]

### Count-Pinning Assertions That Break

| File | Current assertion | Required V7 value |
|------|------------------|------------------|
| `fitbodTests/SchemaV4MigrationTests.swift:95` | `schemas.count == 6` | Must become `== 7` |
| `fitbodTests/SchemaV4MigrationTests.swift:96` | `stages.count == 5` | Must become `== 6` |
| `fitbodTests/SchemaV4MigrationTests.swift:109` | `stages.count == 5` | Must become `== 6` |
| `fitbodTests/Persistence/SchemaV6MigrationTests.swift:75` | `stages.count == 5` | Must become `== 6` |
| `fitbodTests/SchemaV4MigrationTests.swift:94` | `names == [..., "SchemaV6"]` | Must add `"SchemaV7"` |
| `fitbodTests/Persistence/SchemaV6MigrationTests.swift:68` | `names.last == "SchemaV6"` | Must become `"SchemaV7"` |

[VERIFIED: direct source inspection of SchemaV4MigrationTests.swift and SchemaV6MigrationTests.swift]

### ExportDocument Impacts

| File | Field | Impact |
|------|-------|--------|
| `fitbod/Export/ExportDTOs.swift` | `canonicalSchemaVersion = "v6"` | Must become `"v7"` |
| `fitbodTests/Phase6/ExportDocumentSnapshotTests.swift:238` | `json["schemaVersion"] == "v6"` | Must become `"v7"` |
| All ExportDocument consumers | `routines: [ExportRoutineDTO]` | Rename to `sessionTemplates`; add `splits` |

---

## Common Pitfalls

### Pitfall 1: Model Objects Crossing Stage Boundary
**What goes wrong:** Code that keeps a reference to a SwiftData `@Model` object fetched in `willMigrate` and tries to use it in `didMigrate` will crash with an invalid object error or silently read garbage.
**Why it happens:** The SwiftData context is torn down and rebuilt between stage phases. Model objects are invalidated.
**How to avoid:** Convert ALL fetched model data to plain `struct`s (Sendable value types) before the `willMigrate` closure returns. Never pass `@Model` objects across the closure boundary.
**Warning signs:** If a struct field is of type `@Model` or `PersistentModel`, that's a red flag.

### Pitfall 2: Ghost Rows from Name Collision
**What goes wrong:** If the new `Split` entity were named `Routine`, SwiftData's inferred migration would match V6 `Routine` rows to the V7 `Split` entity (same name), populating the splits list with old template rows.
**Why it happens:** SwiftData inferred migration matches entity names literally.
**How to avoid:** Use `Split` as the code name. (Already locked by spec.)

### Pitfall 3: Inverse Keypath Resolution in Nested @Model Types
**What goes wrong:** If `SchemaV6.Routine.exercises` declares `inverse: \RoutineExercise.routine` (top-level type), SwiftData may reject the schema with a "mismatched inverses" error.
**Why it happens:** Both sides of a SwiftData inverse keypath must be in the same VersionedSchema. SchemaV3.swift solves this by having `inverse: \SchemaV3.RoutineExercise.routine`.
**How to avoid:** In the nested V6 types, either use the nested form `\SchemaV6.RoutineExercise.routine` or omit the inverse (as SchemaV3 does for setOverrides) since the migration closure doesn't traverse exercise relationships.
**Warning signs:** Build failure "inverse relationship mismatch" or runtime crash on container init.

### Pitfall 4: `SchemaV6.models` Currently a Pass-Through
**What goes wrong:** `SchemaV6.models` currently returns `SchemaV5.models` (a passthrough). For V7, the nested `SchemaV6.Routine` and `SchemaV6.RoutineExercise` types must be IN `SchemaV6.models` so SwiftData can resolve them during the `willMigrate` closure.
**Why it happens:** The passthrough was fine for V5→V6 (no new entity shapes needed). V6→V7 needs the old entity shapes.
**How to avoid:** Expand `SchemaV6.models` to an explicit list that includes `SchemaV6.Routine.self` and `SchemaV6.RoutineExercise.self` alongside the other 14 production types.
**Warning signs:** `FetchDescriptor<SchemaV6.Routine>()` returns 0 results in willMigrate even though data exists.

### Pitfall 5: `#Unique` Macro on SplitSessionSlot Position
**What goes wrong:** Adding `#Unique<SplitSessionSlot>([\.split, \.position])` to enforce contiguity causes SwiftData to silently upsert on collision instead of erroring, merging two slots into one.
**Why it happens:** SwiftData's `#Unique` uses upsert semantics.
**How to avoid:** Use a test invariant (slot position contiguity test) and reindex-on-write. (Locked by spec.)

### Pitfall 6: `Session.slot` Delete Rule and History
**What goes wrong:** Setting `Session.slot` delete rule to `.cascade` instead of `.nullify` would delete logged history sessions when a slot is removed.
**Why it happens:** `.cascade` is the natural choice for "owned" relationships, but sessions outlive their slots.
**How to avoid:** `Session.slot` delete rule is NULLIFY (SwiftData default for optional relationships). Confirmed via delete-rule test in `SchemaV7MigrationTests`.

### Pitfall 7: `Block.split` Nullify on Split Hard-Delete
**What goes wrong:** If the delete rule is `.cascade`, deleting a `Split` would delete the `Block` that references it.
**Why it happens:** Cascade propagates deletion.
**How to avoid:** `Block.split` uses nullify (default for optional). Completed blocks survive split hard-delete and render from `archivedConfigJSON`. [LOCKED: spec §3]

### Pitfall 8: Export/Backup Schema Version String
**What goes wrong:** `ExportDocument.canonicalSchemaVersion` stays at `"v6"` after Phase 7 ships.
**Why it happens:** Easy to miss — it's a string constant, not a type check.
**How to avoid:** Update `canonicalSchemaVersion = "v7"` and refresh the ExportDocumentSnapshotTests assertion `json["schemaVersion"] == "v6"` → `"v7"`.

### Pitfall 9: `SplitSessionSlot.sessionTemplate` Deny Rule — Soft-Delete Unaffected
**What goes wrong:** Attempting to hard-delete a `SessionTemplate` that's referenced by one or more `SplitSessionSlot` rows fails with SwiftData throwing a deny constraint error.
**Why it happens:** `.deny` is unconditional (schema-level). The Phase 8 service-layer conditional archive check is separate.
**How to avoid:** The deny rule test in `SchemaV7MigrationTests` verifies this behavior. Document it clearly so Phase 8 service layer knows it must handle the deny error gracefully. `isArchived = true` on the template succeeds (no delete attempted).

### Pitfall 10: `trainingDaysJoined` Default vs Empty Array
**What goes wrong:** Storing `trainingDaysJoined = ""` as the default means `trainingDays.get` must guard for empty string, not nil.
**Why it happens:** `String` property on `@Model` can't be nil without declaring `String?`.
**How to avoid:** The getter must guard `!trainingDaysJoined.isEmpty` before splitting (same as `clusterSubReps` pattern in SetEntry).

---

## Code Examples

### SchemaV7 Typealias Pattern

```swift
// fitbod/Persistence/SchemaV7.swift
// Source: SchemaV6.swift (mirror exactly, add new types)
public enum SchemaV7: VersionedSchema {
    public static let versionIdentifier = Schema.Version(7, 0, 0)

    // Typealiases to production types (includes renamed types)
    public typealias SessionTemplate = fitbod.SessionTemplate
    public typealias SessionExerciseTemplate = fitbod.SessionExerciseTemplate
    public typealias Split = fitbod.Split
    public typealias SplitSessionSlot = fitbod.SplitSessionSlot
    // ... all others ...

    public static var models: [any PersistentModel.Type] {
        [
            Self.SessionTemplate.self,
            Self.SessionExerciseTemplate.self,
            Self.Split.self,
            Self.SplitSessionSlot.self,
            // ... existing types minus Routine/RoutineExercise ...
        ]
    }
}
```

### SchemaV6 Expansion for Migration

```swift
// Add to SchemaV6.swift (or SchemaV6+MigrationSupport.swift extension)
// Source: SchemaV3.swift nested @Model pattern
extension SchemaV6 {
    // V6-shape Routine — needed by willMigrate to read Routine.block?.id
    @Model final class Routine {
        @Attribute(.unique) var id: UUID = UUID()
        var name: String = ""
        var notes: String? = nil
        var createdAt: Date = Date.now
        var updatedAt: Date = Date.now
        var isArchived: Bool = false
        var block: fitbod.Block? = nil  // top-level Block (unchanged entity)
        var folderID: UUID? = nil
        var intentRaw: String = "strength"
        var progressionKindRaw: String = "double"
        // exercises relationship omitted — migration doesn't traverse it
        init() {}
    }
    
    // V6-shape RoutineExercise — needed to rebuild SessionExerciseTemplate rows
    @Model final class RoutineExercise {
        @Attribute(.unique) var id: UUID = UUID()
        var routine: SchemaV6.Routine? = nil  // nested form — CRITICAL
        var exercise: fitbod.Exercise? = nil
        var orderIndex: Int = 0
        // ... all prescription fields from fitbod.RoutineExercise verbatim ...
        init() {}
    }
}
```

**CRITICAL:** Update `SchemaV6.models` to include `SchemaV6.Routine.self` and `SchemaV6.RoutineExercise.self` in the list.

### Migration Plan Registration

```swift
// FitbodSchemaMigrationPlan.swift additions:
public static var schemas: [any VersionedSchema.Type] {
    [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self,
     SchemaV5.self, SchemaV6.self, SchemaV7.self]  // +SchemaV7
}

public static var stages: [MigrationStage] {
    [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5,
     migrateV5toV6, migrateV6toV7]  // +migrateV6toV7
}
```

### SchemaV7MigrationTests Shape

```swift
// fitbodTests/Persistence/SchemaV7MigrationTests.swift
// Source: SchemaV6MigrationTests.swift (mirror exactly)
@MainActor
@Suite("SchemaV7Migration", .serialized)
struct SchemaV7MigrationTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV7.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("Migration plan lists SchemaV7 as the latest schema")
    func migrationPlanRegistersV7() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names.last == "SchemaV7")
        #expect(names.count == 7)
    }

    @Test("Migration plan has six stages")
    func migrationPlanHasSixStages() {
        #expect(FitbodSchemaMigrationPlan.stages.count == 6)
    }

    // Ghost-free assertion:
    @Test("No ghost Routine rows in SessionTemplate after migration")
    func noGhostRoutineRows() throws { ... }

    // Rotation continuity (step 4):
    @Test("Active block's last completed session gets slot backfilled")
    func rotationContinuityBackfill() throws { ... }
}
```

---

## Mechanical Rename Scope

**Total call sites:** 69 app files + 43 test files reference `Routine` or `RoutineExercise`. [VERIFIED: rg file-level count]

**File clusters for rename:**

| Cluster | Files | Notes |
|---------|-------|-------|
| Model files | `Routine.swift`→`SessionTemplate.swift`, `RoutineExercise.swift`→`SessionExerciseTemplate.swift` | Core rename |
| Persistence | `SchemaV1-V6.swift`, `FitbodSchemaMigrationPlan.swift` | Keep old typealiases in V1-V6; V7 uses new names |
| Schema nested types (SchemaV3, SchemaV4) | `SchemaV3.Routine`, `SchemaV3.RoutineExercise`, etc. | Keep as-is (historical, canonical) |
| Routines UI | `RoutineBuilderView.swift`, `RoutinesListView.swift`, `RoutineRow.swift`, `RoutineDraft.swift`, etc. | Rename to `SessionTemplateBuilderView`, etc. |
| Sessions | `SessionFactory.swift`, `ResumeWorkoutBanner.swift` | `routine:` param → `template:` |
| Periodization | `BlockBuilderView.swift`, `BlockOverviewScreen.swift`, `ProgramView.swift`, `MesocycleWeekPage.swift` | Remove `block.routines` reads |
| Export/Backup | `ExportDTOs.swift`, `ExportService.swift`, `BackupArchiver.swift`, `BackupRestorer.swift` | Update DTO names + schemaVersion |
| Tests (43 files) | Various — see rg list above | Largest mechanical rename surface |

**GitNexus gitnexus_rename mandate:** Per CLAUDE.md, rename operations MUST use `gitnexus_rename` not find-and-replace. Run impact analysis (`gitnexus_impact`) on `Routine` and `RoutineExercise` symbols before any rename.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`, `#expect`) + XCTest (UI only) |
| Config file | Xcode scheme — no separate config file |
| Quick run command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests/SchemaV7Migration` |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | File |
|--------|----------|-----------|------|
| V7-SCHEMA | SchemaV7 compiles + container opens | smoke | `SchemaV7MigrationTests` |
| V7-COUNT | schemas.count == 7, stages.count == 6 | unit | `SchemaV7MigrationTests` + refreshed V4/V6 tests |
| V7-RENAME | Routine→SessionTemplate rows remapped | integration | `SchemaV7MigrationTests` |
| V7-GHOST | No ghost rows in SessionTemplate picker | integration | `SchemaV7MigrationTests` |
| V7-SLOT-BACKFILL | Active block rotation continuity preserved | integration | `SchemaV7MigrationTests` |
| V7-TEMPLATE-NAME | Session.templateName backfilled | integration | `SchemaV7MigrationTests` |
| V7-ARCHIVE-BACKFILL | archivedConfigJSON present for completed blocks | integration | `SchemaV7MigrationTests` |
| V7-SLOT-DENY | Hard-delete of slotted template throws | unit | `SchemaV7MigrationTests` |
| V7-SLOT-NULLIFY | Deleting slot leaves Session.slot nil, history intact | unit | `SchemaV7MigrationTests` |
| V7-POSITION-CONTIGUITY | Slot positions stay 0,1,2,... after add/remove/reorder | unit | `SchemaV7MigrationTests` |
| V7-ENUM-PERSIST | SchedulingMode cases round-trip through schedulingModeRaw | unit | `EnumPersistenceTests` (additive) |
| V7-COUNT-REFRESH | schemas.count == 7, stages.count == 6 in V4/V6 tests | unit | `SchemaV4MigrationTests`, `SchemaV6MigrationTests` |

### Wave 0 Gaps

- [ ] `fitbodTests/Persistence/SchemaV7MigrationTests.swift` — new file, all tests
- [ ] `InMemoryContainer.makeCurrent()` must be updated to `SchemaV7.models` after rename
- [ ] Count-pinning assertions in `SchemaV4MigrationTests` and `SchemaV6MigrationTests` refreshed

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Routine` entity for templates | `SessionTemplate` entity | V7 | Call-graph rename; 69+43 files |
| `RoutineExercise` entity | `SessionExerciseTemplate` entity | V7 | Same rename scope |
| `Block.routines` to-many | `Block.split → Split → SplitSessionSlot[]` | V7 | All `block.routines` reads replaced |
| Soft UUID `sourceRoutineID` as template link | `Session.template: SessionTemplate?` relationship | V7 | Plus `templateName` snapshot |
| No scheduling mode on Block | `Block.schedulingMode` (.rotation / .fixedWeekly) | V7 | New field |
| No training days on Block | `Block.trainingDays: [Int]` (join-to-String) | V7 | New field |

---

## Open Questions

1. **`Session.sourceRoutineID` and `Session.routineSnapshotName` retention**
   - What we know: spec §3 says `Session.template` replaces `Session.routine`. The old `sourceRoutineID` was a soft UUID ref; the spec says rename to a proper relationship.
   - What's unclear: Whether `sourceRoutineID` and `routineSnapshotName` are REMOVED from the V7 schema or kept as deprecated fields. Multiple test files (BackupRoundTripTests, SessionFactoryTests, ExportDocumentSnapshotTests) and the ExportDTO reference `sourceRoutineID` directly.
   - Recommendation: Keep `sourceRoutineID` as a deprecated `String?` field in V7 for backup forward-compat OR remove it and update all consumers. Planner should specify; if removed, ExportDTO, BackupRestorer, BackupArchiver, and ~5 test files need updates that should be explicit tasks.

2. **`SchemaV6.models` expansion** — currently a passthrough to SchemaV5.models. The willMigrate closure needs `FetchDescriptor<SchemaV6.Routine>()` to work. SchemaV6.models MUST include the nested types. This is a non-obvious requirement with a silent failure mode (0 rows fetched in willMigrate).
   - What's unclear: Whether to add nested types to `SchemaV6.swift` directly or in a separate `SchemaV6+MigrationSupport.swift` file.
   - Recommendation: Inline in `SchemaV6.swift` as an extension for file co-location with other schema files.

3. **`trainingDays` as join-to-String vs native `[Int]`**
   - What we know: iOS 26.4 target, existing project uses join-to-String for `clusterSubReps`.
   - What's unclear: Whether SwiftData on iOS 26.4 supports native `[Int]` storage without a Transformable.
   - Recommendation: Use join-to-String (`trainingDaysJoined: String`) to match established pattern. [ASSUMED]

4. **NewBlockBuilderFidelityTests — `NewBlockLinkedRoutinesBand`**
   - The current test in `BlockBuilderView.swift` references `editing?.routines?.count ?? 0`. When `Block.routines` is removed, this code path must be updated. The `NewBlockBuilderFidelityTests` suite asserts verbatim struct names and copy. Whether `NewBlockLinkedRoutinesBand` name survives the Phase 7 update is a planner decision (if it becomes a split picker, the name may change).
   - Recommendation: Phase 7 mechanically removes the old band and either stubs it or renames it to a split-picker component. The guardrail test needs updating if the type name changes.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `trainingDays` should use join-to-String pattern (`trainingDaysJoined: String`) | Architecture Patterns §3 | If iOS 26.4 SwiftData supports native `[Int]`, the join-to-String approach works but is less ergonomic |
| A2 | `Session.sourceRoutineID` and `routineSnapshotName` are kept as deprecated fields in V7 (not removed) | Open Questions #1 | If removed, 5+ test files and 3 export/backup files need explicit update tasks |
| A3 | `NewBlockLinkedRoutinesBand` type name does not change in Phase 7 (only its `count` data source changes) | Mechanical Rename Scope | If renamed, `NewBlockBuilderFidelityTests` verbatim struct assertion breaks |

---

## Environment Availability

> Phase 7 is code/schema changes only. No external services or CLIs required beyond Xcode + iOS Simulator.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS 26.4 Simulator | Build + test | ✓ | iOS 26.4 target (IPHONEOS_DEPLOYMENT_TARGET = 26.4) | — |
| Swift Testing | Unit tests | ✓ | iOS 26.4 | — |
| GitNexus CLI | Impact analysis + rename | ✓ (per CLAUDE.md) | per project | — |

---

## Security Domain

> This phase is pure local persistence (schema + migration). No network, no auth, no user input validation surfaces. ASVS categories V2, V3, V4, V6 do not apply.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | No user-input parsing in migration stage |
| V6 Cryptography | no | — |

---

## Sources

### Primary (HIGH confidence)
- `fitbod/Persistence/SchemaV3.swift` — nested @Model pattern, cross-stage boundary comment, inverse keypath constraint
- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` — full migration plan, `bumpPlateauToleranceDefault` + `backfillSessionLevelFields` testability patterns
- `fitbod/Persistence/SchemaV6.swift` — current passthrough-models pattern; V7 needs expansion
- `fitbod/Models/Routine.swift`, `Block.swift`, `Session.swift`, `RoutineExercise.swift` — current entity shapes
- `fitbod/Models/SetEntry.swift` — join-to-String `[Int]` pattern (`clusterSubRepsJoined`)
- `fitbod/Models/BlockPhase.swift`, `fitbod/Models/Enums/BlockPhaseKind.swift`, `fitbod/Models/Enums/Intent.swift` — `*Raw: String` enum persistence pattern
- `fitbodTests/Persistence/SchemaV6MigrationTests.swift` — migration test shape, @MainActor + .serialized, stages.count pinning
- `fitbodTests/SchemaV4MigrationTests.swift` — schemas.count + stages.count pinning assertions (lines 95, 96, 109)
- `fitbodTests/TestSupport/InMemoryContainer.swift` — test container pattern; `makeCurrent()` uses SchemaV6.models
- `.planning/quick/training-block-spec/program-graph-spec.md` — authoritative design contract
- `.planning/phases/07-program-graph-schema-v7-migration/07-CONTEXT.md` — locked implementation decisions

### Secondary (MEDIUM confidence)
- `fitbod/Export/ExportDTOs.swift` — `canonicalSchemaVersion = "v6"` string constant that needs bumping
- `fitbodTests/Phase6/ExportDocumentSnapshotTests.swift` — `"v6"` assertion at line 238
- rg file-level count: 69 app files + 43 test files reference Routine/RoutineExercise

---

## Metadata

**Confidence breakdown:**
- Schema migration mechanics: HIGH — verified against SchemaV3/V4/V5/V6 source code
- Entity rename pattern: HIGH — V3→V4 nested @Model precedent is exact
- Call-site inventory: HIGH — rg-verified file counts and specific line numbers
- `trainingDays [Int]` storage: MEDIUM — join-to-String confirmed as project pattern; native [Int] availability on iOS 26.4 not confirmed via official docs
- Count-pinning assertions: HIGH — specific line numbers verified

**Research date:** 2026-06-10
**Valid until:** 2026-07-10 (stable SwiftData APIs)
