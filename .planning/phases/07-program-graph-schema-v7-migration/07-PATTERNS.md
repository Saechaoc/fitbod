# Phase 7: Program Graph Schema V7 & Migration — Pattern Map

**Mapped:** 2026-06-10
**Files analyzed:** 18 new/modified files
**Analogs found:** 18 / 18

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `fitbod/Persistence/SchemaV7.swift` | config/schema | CRUD | `fitbod/Persistence/SchemaV6.swift` | exact |
| `fitbod/Persistence/SchemaV6.swift` (expanded) | config/schema | CRUD | `fitbod/Persistence/SchemaV3.swift` (nested @Model pattern) | exact |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (+V7 stage) | config/migration | batch | existing `migrateV5toV6` + `migrateV3toV4` helpers | exact |
| `fitbod/Models/SessionTemplate.swift` (renamed Routine.swift) | model | CRUD | `fitbod/Models/Routine.swift` | exact |
| `fitbod/Models/SessionExerciseTemplate.swift` (renamed RoutineExercise.swift) | model | CRUD | `fitbod/Models/RoutineExercise.swift` | exact |
| `fitbod/Models/Split.swift` | model | CRUD | `fitbod/Models/Block.swift` (relationship + cascade pattern) | role-match |
| `fitbod/Models/SplitSessionSlot.swift` | model | CRUD | `fitbod/Models/BlockPhase.swift` (owned join entity) | role-match |
| `fitbod/Models/Block.swift` (+split, +schedulingMode, +trainingDays, +archivedConfigJSON) | model | CRUD | `fitbod/Models/Block.swift` self | exact |
| `fitbod/Models/Session.swift` (+slot, +templateName, ~routine→template) | model | CRUD | `fitbod/Models/Session.swift` self | exact |
| `fitbod/Models/Enums/SchedulingMode.swift` | utility/enum | transform | `fitbod/Models/Enums/BlockPhaseKind.swift` | exact |
| `fitbod/Models/ArchivedBlockConfig.swift` | model/DTO | transform | `fitbod/Export/ExportDTOs.swift` (Codable struct pattern) | role-match |
| `fitbodTests/Persistence/SchemaV7MigrationTests.swift` | test | batch | `fitbodTests/Persistence/SchemaV6MigrationTests.swift` | exact |
| `fitbod/Views/TodayView.swift` (todaysRoutine stub) | component | request-response | self (lines 361-376) | exact |
| `fitbod/Periodization/BlockBuilderView.swift` (LinkedRoutinesBand data source) | component | request-response | self (lines 75-78, 1834-1852) | exact |
| `fitbod/Periodization/BlockOverviewScreen.swift` (block.routines→split) | component | request-response | self (lines 209, 216, 230, 355, 503) | exact |
| `fitbod/Periodization/MesocycleWeekPage.swift` (scheduledRoutines) | component | request-response | self (lines 103-105) | exact |
| `fitbodTests/SchemaV4MigrationTests.swift` (count-pinning refresh) | test | batch | self | exact |
| `fitbodTests/Persistence/SchemaV6MigrationTests.swift` (count-pinning refresh) | test | batch | self | exact |

---

## Pattern Assignments

### `fitbod/Persistence/SchemaV7.swift` (config/schema, new file)

**Analog:** `fitbod/Persistence/SchemaV6.swift` (lines 1-71) for the typealias shell; `fitbod/Persistence/SchemaV4.swift` (lines 45-80) for the explicit `models` array.

**Imports pattern** (SchemaV6.swift lines 43-44):
```swift
import Foundation
import SwiftData
```

**Version identifier pattern** (SchemaV6.swift line 47):
```swift
public enum SchemaV7: VersionedSchema {
    public static let versionIdentifier = Schema.Version(7, 0, 0)
```

**Typealias block pattern** (SchemaV6.swift lines 50-66 — mirror exactly, replacing Routine/RoutineExercise with the new names):
```swift
    // MARK: - Typealiases to top-level production types

    public typealias SessionTemplate = fitbod.SessionTemplate
    public typealias SessionExerciseTemplate = fitbod.SessionExerciseTemplate
    public typealias Split = fitbod.Split
    public typealias SplitSessionSlot = fitbod.SplitSessionSlot
    public typealias Session = fitbod.Session
    public typealias Block = fitbod.Block
    // ... all other unchanged entities follow
```

**Explicit models array pattern** (SchemaV4.swift lines 61-80 — V7 must NOT use the passthrough form `SchemaV6.models` because V6 is being expanded for migration types):
```swift
    public static var models: [any PersistentModel.Type] {
        [
            Self.SessionTemplate.self,
            Self.SessionExerciseTemplate.self,
            Self.Split.self,
            Self.SplitSessionSlot.self,
            Self.Session.self,
            Self.Block.self,
            // ... all 18 production types listed explicitly ...
        ]
    }
```

**Header comment pattern** (SchemaV6.swift lines 1-41): Write a matching header listing the V7 delta — new entities, renamed entities, field additions, archivedConfigJSON. Mirror the same "Phase N schema wrapper — additive successor to SchemaVM" prose.

---

### `fitbod/Persistence/SchemaV6.swift` — expansion for migration (existing file, modified)

**Analog:** `fitbod/Persistence/SchemaV3.swift` (lines 95-237) for the nested `@Model` class pattern.

**Critical modification:** `SchemaV6.models` currently returns `SchemaV5.models` (line 68-70). This must be replaced with an explicit list that includes the new nested types — identical structural requirement to SchemaV3.swift lines 70-93.

**Nested @Model class pattern** (SchemaV3.swift lines 100-115 and 167-193):
```swift
extension SchemaV6 {
    // V6-shape Routine — needed by willMigrate to read Routine.block?.id
    // for step 3 in §7. Mirror fitbod.Routine exactly as it exists at V6 close.
    @Model
    public final class Routine {
        @Attribute(.unique) public var id: UUID = UUID()
        public var name: String = ""
        public var notes: String? = nil
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now
        public var isArchived: Bool = false
        public var block: fitbod.Block? = nil   // top-level Block (unchanged entity)
        public var folderID: UUID? = nil
        public var intentRaw: String = "strength"
        public var progressionKindRaw: String = "double"

        // exercises relationship: use nested form for inverse keypath correctness
        @Relationship(deleteRule: .cascade, inverse: \SchemaV6.RoutineExercise.routine)
        public var exercises: [SchemaV6.RoutineExercise]? = []

        public init() {}
    }

    // V6-shape RoutineExercise — needed to rebuild SessionExerciseTemplate rows
    @Model
    public final class RoutineExercise {
        @Attribute(.unique) public var id: UUID = UUID()
        public var routine: SchemaV6.Routine? = nil  // nested form — CRITICAL (see SchemaV3.swift line 169)
        public var exercise: fitbod.Exercise? = nil
        public var orderIndex: Int = 0
        // ... all prescription fields verbatim from fitbod.RoutineExercise ...
        // setOverrides: intentionally omit inverse (SchemaV3.swift lines 158-166 pattern)
        @Relationship(deleteRule: .cascade)
        public var setOverrides: [RoutineExerciseSetOverride]? = []
        public init() {}
    }
}
```

**Inverse keypath rule** (SchemaV3.swift lines 47-54): Both sides of a SwiftData inverse must live in the SAME VersionedSchema. `SchemaV6.RoutineExercise.routine` must reference `SchemaV6.Routine`, not `fitbod.Routine`. Cross-schema refs (setOverrides → top-level RoutineExerciseSetOverride) omit the inverse declaration on the nested side.

**`#Index` omission rule** (SchemaV3.swift lines 121-129): Nested `@Model` types never declare `#Index<T>` — the macro can't resolve qualified type names through the enclosing enum namespace.

**Expanded `SchemaV6.models` array** (mirroring SchemaV3.swift lines 70-93):
```swift
    public static var models: [any PersistentModel.Type] {
        // Replace the current SchemaV5.models passthrough with an explicit list
        // that includes the nested migration types. All 16 production V6 entities
        // plus the 2 nested V6 shapes = 18 entries.
        [
            Exercise.self,
            MuscleGroup.self,
            ExerciseMuscleStimulus.self,
            Block.self,
            BlockPhase.self,
            // ... other unchanged top-level types ...
            Self.Routine.self,           // nested V6 shape
            Self.RoutineExercise.self,   // nested V6 shape
        ]
    }
```

---

### `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` — +migrateV6toV7 (existing file, modified)

**Analog:** `migrateV5toV6` (lines 103-110) for the custom stage shell; `bumpPlateauToleranceDefault` (lines 117-127) for the extracted-helper testability pattern; `migrateV3toV4` (lines 144-151) for the willMigrate + didMigrate split; `backfillSessionLevelFields` (lines 164-201) for the FetchDescriptor pattern.

**Schema + stages registration pattern** (FitbodSchemaMigrationPlan.swift lines 53-59 — add SchemaV7):
```swift
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self,
         SchemaV5.self, SchemaV6.self, SchemaV7.self]   // +SchemaV7
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5,
         migrateV5toV6, migrateV6toV7]   // +migrateV6toV7
    }
```

**Custom stage declaration pattern** (lines 103-110):
```swift
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
```

**`internal static` helper testability pattern** (lines 117-127 + lines 164-201):
```swift
    // willMigrate helper — `internal` so SchemaV7MigrationTests can call directly
    // (MigrationStage closures are not invokable from fixture tests)
    internal static func stashV6Routines(in context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<SchemaV6.Routine>())
        // Copy to Sendable plain structs — NEVER hold @Model objects across stage boundary
        // (see SchemaV3.swift header comment on cross-stage boundary)
        v6RoutineStash = routines.map { RoutineStash(from: $0) }
        // ... session stash similarly
    }

    internal static func materializeSessionTemplates(in context: ModelContext) throws {
        // Create SessionTemplate per stashed row; remap Session.template refs
        let templates = try context.fetch(FetchDescriptor<SessionTemplate>())
        // ... seven-step didMigrate logic ...
        try context.save()
    }
```

**FetchDescriptor pattern for stash** (lines 168-176):
```swift
        let v4REs = try context.fetch(FetchDescriptor<SchemaV4.RoutineExercise>())
        // V7 equivalent:
        let v6Routines = try context.fetch(FetchDescriptor<SchemaV6.Routine>())
        let v6Sessions = try context.fetch(FetchDescriptor<SchemaV6.Session>())
```

**Plain-struct stash type pattern** (SchemaV3.swift header + RESEARCH Pattern 1):
```swift
    // Internal Sendable stash struct — cross-stage boundary safe
    // `internal` so SchemaV7MigrationTests can construct fixtures directly
    internal struct RoutineStash: Sendable {
        let id: UUID
        let name: String
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
        let isArchived: Bool
        let folderID: UUID?
        let blockID: UUID?          // from V6 Routine.block?.id — step 3 depends on this
        let intentRaw: String
        let progressionKindRaw: String
        // exercise prescription stash follows
    }

    internal struct SessionRoutineStash: Sendable {
        let sessionID: UUID
        let routineID: UUID?        // from V6 Session.sourceRoutineID
    }
```

---

### `fitbod/Models/SessionTemplate.swift` (renamed from Routine.swift, role: model, CRUD)

**Analog:** `fitbod/Models/Routine.swift` (full file — exact rename)

**Full model pattern** (Routine.swift lines 38-62):
```swift
@Model
public final class SessionTemplate {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var notes: String? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var isArchived: Bool = false
    // block relationship REMOVED in V7 (was Routine.block)
    public var folderID: UUID? = nil
    public var intentRaw: String = "strength"
    public var progressionKindRaw: String = "double"

    @Relationship(deleteRule: .cascade, inverse: \SessionExerciseTemplate.sessionTemplate)
    public var exercises: [SessionExerciseTemplate]? = []

    public init() {}
}

extension SessionTemplate {
    public var intent: Intent { Intent(rawValue: intentRaw) ?? .strength }
    public var progressionKind: ProgressionKind {
        ProgressionKind(rawValue: progressionKindRaw) ?? .double
    }
}
```

**Header comment pattern** (Routine.swift lines 1-33): Write matching header explaining this is the V7 rename of `Routine`, that `SchemaV6.Routine` (nested in SchemaV6.swift) preserves the V6 shape for the V6→V7 migration closure, and that `SessionTemplate` is the V7 production entity.

---

### `fitbod/Models/SessionExerciseTemplate.swift` (renamed from RoutineExercise.swift, role: model, CRUD)

**Analog:** `fitbod/Models/RoutineExercise.swift` (full file — exact rename)

**Relationship rename pattern** (RoutineExercise.swift lines 60-61):
```swift
    // V7: routine → sessionTemplate; RoutineExercise → SessionExerciseTemplate
    @Relationship(deleteRule: .cascade, inverse: \RoutineExerciseSetOverride.routineExercise)
    public var setOverrides: [RoutineExerciseSetOverride]? = []
```

Note: `RoutineExerciseSetOverride` keeps its name (accepted naming debt per spec §3). The `routineExercise: RoutineExerciseSetOverride` back-ref keeps its name too.

The `routine: Routine?` field becomes `sessionTemplate: SessionTemplate?` — rename only, same structure.

---

### `fitbod/Models/Split.swift` (new file, role: model, CRUD)

**Analog:** `fitbod/Models/Block.swift` for the cascade relationship pattern + header comment structure.

**Full model pattern** (Block.swift lines 22-42 adapted):
```swift
@Model
public final class Split {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var createdAt: Date = Date.now
    public var isArchived: Bool = false

    // Slots cascade on split delete; inverse declared here (single-sided, per
    // Block.swift line 32 "inverse declaration lives on Block.phases").
    @Relationship(deleteRule: .cascade, inverse: \SplitSessionSlot.split)
    public var slots: [SplitSessionSlot]? = []

    public init() {}
}
```

**Header comment pattern** (Block.swift lines 1-17): Write matching header explaining cascade rule intent. Note: `Block.split` nullifies on split hard-delete (completed blocks survive via archivedConfigJSON).

---

### `fitbod/Models/SplitSessionSlot.swift` (new file, role: model, CRUD)

**Analog:** `fitbod/Models/BlockPhase.swift` (full file — same "owned join row" role with parent ref + orderIndex).

**Full model pattern** (BlockPhase.swift lines 22-37 adapted):
```swift
@Model
public final class SplitSessionSlot {
    @Attribute(.unique) public var id: UUID = UUID()
    public var split: Split? = nil          // inverse declared on Split.slots (single-sided)
    public var position: Int = 0            // explicit order (SwiftData to-many is unordered)

    // .deny: hard-delete refused while slotted; soft-delete (isArchived) unaffected.
    // Session.slot nullifies on slot delete — never cascade into history.
    @Relationship(deleteRule: .deny)
    public var sessionTemplate: SessionTemplate? = nil

    public init() {}
}
```

Note: No `#Unique` on (split, position) — SwiftData upserts on collision → silent slot merge. Use test invariant instead (spec §3 + RESEARCH Pitfall 5).

---

### `fitbod/Models/Block.swift` — field additions (existing file, modified)

**Analog:** `fitbod/Models/SetEntry.swift` lines 46-64 for the join-to-String `[Int]` accessor pattern; `fitbod/Models/BlockPhase.swift` lines 36-37 for the `*Raw` enum accessor pattern; `fitbod/Models/Block.swift` self for relationship additions.

**New split relationship** (Block.swift line 35 pattern — `@Relationship(inverse:)` for non-cascade):
```swift
    // V7 additive: nil while draft. nullify on split hard-delete (default for optional).
    // No @Relationship decorator needed — SwiftData default is nullify for optional refs.
    public var split: Split? = nil
```

**Enum raw + computed accessor pattern** (BlockPhase.swift lines 26-37):
```swift
    // V7 additive: scheduling mode. Default .rotation (spec §3).
    public var schedulingModeRaw: String = "rotation"
```
```swift
extension Block {
    public var schedulingMode: SchedulingMode {
        get { SchedulingMode(rawValue: schedulingModeRaw) ?? .rotation }
        set { schedulingModeRaw = newValue.rawValue }
    }
}
```

**Join-to-String [Int] pattern** (SetEntry.swift lines 46-64 — EXACT pattern to copy):
```swift
    // V7 additive: Calendar weekday numbers (1=Sun…7=Sat). Stored as comma-joined
    // String — established project pattern (see SetEntry.clusterSubRepsJoined).
    // Sorted ONCE at write; never re-sorted at read (spec §3).
    public var trainingDaysJoined: String = ""
```
```swift
extension Block {
    public var trainingDays: [Int] {
        get {
            guard !trainingDaysJoined.isEmpty else { return [] }
            return trainingDaysJoined.split(separator: ",").compactMap { Int($0) }
        }
        set {
            trainingDaysJoined = newValue.map(String.init).joined(separator: ",")
        }
    }
}
```

Note: `clusterSubReps` uses `nil` for empty (SetEntry line 62: `clusterSubRepsJoined = newValue.isEmpty ? nil : ...`). `trainingDaysJoined` stores `""` for empty (non-optional `String` default). The getter must guard `!trainingDaysJoined.isEmpty` not `guard let` (RESEARCH Pitfall 10).

**Archive JSON field** (additive, optional String):
```swift
    // V7 additive: written once at block end (freeze #2). Nil until block completes.
    public var archivedConfigJSON: String? = nil
```

**Remove `Block.routines` relationship** (Block.swift lines 35-36):
```swift
    // REMOVE this field:
    // @Relationship(inverse: \Routine.block)
    // public var routines: [Routine]? = []
```

---

### `fitbod/Models/Session.swift` — field additions + rename (existing file, modified)

**Analog:** Session.swift self for field structure; Routine.swift lines 51-54 for the soft-ref→relationship promotion pattern.

**Rename `routine` to `template`** (Session.swift currently has no SwiftData `Routine` relationship — `sourceRoutineID: UUID?` is the soft ref). V7 adds a proper relationship:
```swift
    // V7: proper relationship replacing the soft UUID ref. nullify on template delete (default).
    public var template: SessionTemplate? = nil

    // V7 additive: which slot launched this workout; nil = ad-hoc.
    // nullify on slot delete (default for optional). NEVER cascade.
    public var slot: SplitSessionSlot? = nil

    // V7 additive: log-time snapshot of template name (freeze #1 insurance).
    public var templateName: String? = nil
```

**Keep deprecated soft-ref fields** (Session.swift lines 53-54 — keep for backup format backward-compat, per RESEARCH Open Question #1 conservative recommendation):
```swift
    // DEPRECATED in V7 — replaced by template: SessionTemplate? relationship.
    // Kept for backup forward-compat. Will be cleaned up post-v7.
    public var sourceRoutineID: UUID? = nil
    public var routineSnapshotName: String = ""
```

**#Index update** (Session.swift line 48): The existing `#Index<Session>([\.startedAt], [\.sourceRoutineID], [\.intentRaw])` — `sourceRoutineID` can stay (kept as deprecated). Add no new index entries for V7 (non-persistent metadata, no schema bump needed per SetEntry.swift comment on line 29).

---

### `fitbod/Models/Enums/SchedulingMode.swift` (new file, role: utility/enum)

**Analog:** `fitbod/Models/Enums/BlockPhaseKind.swift` (full file — exact pattern match)

**Full enum pattern** (BlockPhaseKind.swift lines 15-23):
```swift
// fitbod/Models/Enums/SchedulingMode.swift
import Foundation

public enum SchedulingMode: String, CaseIterable, Sendable {
    case rotation
    case fixedWeekly

    public static let `default`: SchedulingMode = .rotation
}
```

Header comment: "Scheduling mode for a Block — how training days are assigned to slots. Persisted as `schedulingModeRaw: String` on `Block` (FOUND-03 / PITFALLS #9)."

---

### `fitbod/Models/ArchivedBlockConfig.swift` (new file, role: model/DTO, transform)

**Analog:** `fitbod/Export/ExportDTOs.swift` lines 68-122 for the Codable struct envelope pattern; the `ExportExerciseDTO` pattern (lines 126-169) for the field-mirror nested DTO pattern.

**Codable struct pattern** (ExportDTOs.swift lines 68-87):
```swift
// Plain Codable DTO — NEVER @Model (project convention: no Codable on @Model).
// "v": 1 stamped for V6+ readers.
public struct ArchivedBlockConfig: Codable, Equatable, Sendable {
    public let v: Int                       // schema version, always 1 for V7
    public let blockName: String
    public let startedAt: Date
    public let endedAt: Date
    public let mode: String                 // schedulingModeRaw value
    public let trainingDays: [Int]
    public let phases: [ArchivedPhaseDTO]
    public let split: ArchivedSplitDTO

    public init(
        v: Int = 1,
        blockName: String,
        startedAt: Date,
        endedAt: Date,
        mode: String,
        trainingDays: [Int],
        phases: [ArchivedPhaseDTO],
        split: ArchivedSplitDTO
    ) { ... }
}
```

**Nested DTO pattern** (ExportExerciseDTO lines 126-169 — memberwise init + all stored fields):
```swift
public struct ArchivedPhaseDTO: Codable, Equatable, Sendable {
    public let kind: String          // BlockPhaseKind.rawValue
    public let weeks: Int
    public let volumeMultiplier: Double
    public let intensityMultiplier: Double
    public let notes: String?
}

public struct ArchivedSplitDTO: Codable, Equatable, Sendable {
    public let name: String
    public let slots: [ArchivedSlotDTO]   // ordered by position
}

public struct ArchivedSlotDTO: Codable, Equatable, Sendable {
    public let position: Int
    public let sessionName: String
    public let exercises: [ArchivedExerciseDTO]
}

public struct ArchivedExerciseDTO: Codable, Equatable, Sendable {
    // Full SessionExerciseTemplate prescription mirror per spec §6
    public let exerciseID: UUID?
    public let exerciseName: String
    public let orderIndex: Int
    public let targetSets: Int
    public let targetRepsLow: Int
    public let targetRepsHigh: Int
    public let targetRPE: Double?
    public let targetRIR: Int?
    public let prescribedRestSeconds: Int
    public let tempo: String?
    public let notes: String?
    public let intentRaw: String
    public let progressionKindRaw: String
}
```

**JSONDecoder/JSONEncoder pattern** (ExportDTOs.swift lines 53-64): Add a static `decode(from:)` helper that uses `.iso8601` date decoding strategy — same configuration as `JSONEncoder.exportConfigured()`.

---

### `fitbodTests/Persistence/SchemaV7MigrationTests.swift` (new file, role: test, batch)

**Analog:** `fitbodTests/Persistence/SchemaV6MigrationTests.swift` (full file — mirror exactly)

**Full test suite structure** (SchemaV6MigrationTests.swift lines 43-206):

**Suite declaration + makeContext helper** (lines 43-60):
```swift
import Foundation
import SwiftData
import Testing
@testable import fitbod

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
```

**Count-pinning assertions** (SchemaV6MigrationTests.swift lines 64-75 — update values to V7):
```swift
    @Test("Migration plan lists SchemaV7 as the latest schema")
    func migrationPlanRegistersV7() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names.last == "SchemaV7")
        #expect(names == ["SchemaV1", "SchemaV2", "SchemaV3", "SchemaV4",
                          "SchemaV5", "SchemaV6", "SchemaV7"])
    }

    @Test("Migration plan has six stages")
    func migrationPlanHasSixStages() {
        #expect(FitbodSchemaMigrationPlan.stages.count == 6)
    }
```

**Helper-invocation test pattern** (SchemaV6MigrationTests.swift lines 172-205 — drives semantics through extracted helpers, not by opening a live V6 store):
```swift
    @Test("stashV6Routines + materializeSessionTemplates remaps Routine rows to SessionTemplate")
    func refRemapping() throws {
        let ctx = try makeContext()
        // ... seed SchemaV6.Routine rows via ctx.insert ...
        // ... call FitbodSchemaMigrationPlan.stashV6Routines(in: ctx) ...
        // ... call FitbodSchemaMigrationPlan.materializeSessionTemplates(in: ctx) ...
        // ... assert SessionTemplate rows exist, sourceIDs remapped ...
    }
```

**Delete-rule test pattern** (new — no direct analog, use Swift Testing pattern from rules):
```swift
    @Test("Deleting a slotted SessionTemplate throws (deny rule)")
    func slottedTemplateDenyRule() throws {
        let ctx = try makeContext()
        // insert Split, SessionTemplate, SplitSessionSlot wiring them together
        // attempt context.delete(template) + ctx.save()
        // #expect(throws: ...) { try ctx.save() }
    }

    @Test("Deleting a SplitSessionSlot nullifies Session.slot, history intact")
    func slotNullifyRule() throws {
        let ctx = try makeContext()
        // insert slot + session with session.slot = slot
        // delete slot; save
        // assert session.slot == nil, session still exists
    }
```

---

### `fitbod/Views/TodayView.swift` — `todaysRoutine` stub (existing file, modified)

**Analog:** TodayView.swift lines 361-376 (the current `todaysRoutine` computed property — replace body only)

**Current pattern to replace** (lines 366-376):
```swift
    private var todaysRoutine: Routine? {
        guard let block = activeBlocks.first else { return nil }
        let blockRoutines = (block.routines ?? []).filter { !$0.isArchived }
        guard !blockRoutines.isEmpty else { return nil }
        let weekday = Calendar.current.component(.weekday, from: .now)
        let index = (weekday - 2 + blockRoutines.count) % blockRoutines.count
        return blockRoutines.sorted { $0.name < $1.name }[index]
    }
```

**Phase 7 minimal adaptation** (compile stub — resolver comes Phase 8):
```swift
    // V7: block.routines removed; Phase 8 resolver drives this.
    // Return type changes to SessionTemplate? after rename.
    private var todaysRoutine: SessionTemplate? {
        // TODO Phase 8: replace with unified resolver predicate (spec §5)
        return nil
    }
```

Return type `Routine?` → `SessionTemplate?`. All downstream consumers at lines 123 and 165 reference `routine:` — update call sites to `template:` / `sessionTemplate:` as appropriate after rename.

---

### `fitbod/Periodization/BlockBuilderView.swift` — LinkedRoutinesBand (existing file, modified)

**Analog:** BlockBuilderView.swift lines 75-78 and 1834-1852 (the existing linked-routines band — minimal adaptation)

**Current pattern** (line 77):
```swift
NewBlockLinkedRoutinesBand(count: editing?.routines?.count ?? 0)
```

**Phase 7 minimal adaptation** (compile stub — split picker comes Phase 9):
```swift
// V7: block.routines removed; split.slots is the new count source.
// Phase 9 replaces this band with the split picker component.
NewBlockLinkedRoutinesBand(count: editing?.split?.slots?.count ?? 0)
```

`NewBlockLinkedRoutinesBand` struct at line 1834 keeps its name (RESEARCH Assumption A3 — prevents NewBlockBuilderFidelityTests guardrail breakage). Only the data source changes.

---

### `fitbod/Periodization/BlockOverviewScreen.swift` — block.routines removal (existing file, modified)

**Analog:** BlockOverviewScreen.swift lines 209, 216, 230, 355, 503 (the five call sites)

**Current pattern at each site** (grep output):
```swift
// Line 209:
|| (block.routines ?? []).contains { $0.id == session.sourceRoutineID }
// Line 216:
let routineCount = (block.routines ?? []).count
// Line 230:
|| (block.routines ?? []).contains { $0.id == session.sourceRoutineID }
// Line 355:
let scheduledCount = (block.routines ?? []).count
// Line 503:
(block.routines ?? []).contains { $0.id == s.sourceRoutineID } || s.block?.id == block.id
```

**Phase 7 minimal adaptation** (compile stubs):
```swift
// Lines 209, 230, 503 — sourceRoutineID kept as deprecated field; slot ref is new canonical link
// Replace .contains { $0.id == session.sourceRoutineID } with slot-based check or stub:
|| session.slot?.split?.id == block.split?.id   // or: || false // TODO Phase 8

// Lines 216, 355 — count via split.slots
let routineCount = block.split?.slots?.count ?? 0
let scheduledCount = block.split?.slots?.count ?? 0
```

---

### `fitbod/Periodization/MesocycleWeekPage.swift` — scheduledRoutines (existing file, modified)

**Analog:** MesocycleWeekPage.swift lines 103-105 (the `scheduledRoutines` static function)

**Current pattern** (lines 103-105):
```swift
    public static func scheduledRoutines(for block: Block) -> [Routine] {
        (block.routines ?? []).sorted { $0.name < $1.name }
    }
```

**Phase 7 adaptation**:
```swift
    // V7: block.routines removed; slots carry canonical position order.
    public static func scheduledSlots(for block: Block) -> [SplitSessionSlot] {
        (block.split?.slots ?? []).sorted { $0.position < $1.position }
    }
```

Return type changes to `[SplitSessionSlot]`. Update call sites in MesocycleWeekPage accordingly. If the function name change would break fidelity tests, keep the old name and update only the body + return type.

---

### Count-pinning assertion refresh — SchemaV4MigrationTests.swift + SchemaV6MigrationTests.swift

**Analog:** SchemaV4MigrationTests.swift lines 91-110 (the count-pinning block); SchemaV6MigrationTests.swift lines 64-75.

**Exact lines to update** (RESEARCH verified):

SchemaV4MigrationTests.swift:
```swift
// Line 94 — add "SchemaV7" to the names array:
#expect(names == ["SchemaV1", "SchemaV2", "SchemaV3", "SchemaV4", "SchemaV5", "SchemaV6", "SchemaV7"])
// Line 95 — bump from 6 to 7:
#expect(FitbodSchemaMigrationPlan.schemas.count == 7)
// Lines 96, 109 — bump from 5 to 6:
#expect(FitbodSchemaMigrationPlan.stages.count == 6)
```

SchemaV6MigrationTests.swift:
```swift
// Line 68 — bump last to "SchemaV7":
#expect(names.last == "SchemaV7")
// Line 75 — bump from 5 to 6:
#expect(FitbodSchemaMigrationPlan.stages.count == 6)
```

---

## Shared Patterns

### `@Model` Field Conventions
**Source:** `fitbod/Models/Block.swift`, `fitbod/Models/Routine.swift`, `fitbod/Models/BlockPhase.swift`
**Apply to:** All new `@Model` types (Split, SplitSessionSlot, SessionTemplate, SessionExerciseTemplate)

- Every `@Model` field gets a default value — never uninitialized
- `@Attribute(.unique)` on `id: UUID = UUID()`
- `public init() {}` — empty init only; relationship assignment happens AFTER `context.insert()`
- `public final class` (not struct, not open)

### Enum Persistence — `*Raw: String`
**Source:** `fitbod/Models/BlockPhase.swift` lines 26-37, `fitbod/Models/Enums/BlockPhaseKind.swift` lines 15-23
**Apply to:** `Block.schedulingModeRaw`, any future enum field on new entities

```swift
// On the @Model: stored raw String
public var schedulingModeRaw: String = "rotation"

// In extension: computed accessor
public var schedulingMode: SchedulingMode {
    get { SchedulingMode(rawValue: schedulingModeRaw) ?? .rotation }
    set { schedulingModeRaw = newValue.rawValue }
}
```

### Single-Sided Inverse Declaration
**Source:** `fitbod/Models/Block.swift` lines 32-38, `fitbod/Models/Routine.swift` line 12 (header comment)
**Apply to:** Split.slots, SplitSessionSlot relationships

Declare `@Relationship` (with deleteRule + inverse keypath) on the OWNING side only. The owned side declares a plain `var` with no `@Relationship` decorator. SwiftData infers the inverse automatically.

```swift
// Owning side (Split):
@Relationship(deleteRule: .cascade, inverse: \SplitSessionSlot.split)
public var slots: [SplitSessionSlot]? = []

// Owned side (SplitSessionSlot) — plain var, no @Relationship:
public var split: Split? = nil
```

Exception: `.deny` delete rules MUST be declared explicitly:
```swift
@Relationship(deleteRule: .deny)
public var sessionTemplate: SessionTemplate? = nil
```

### SwiftData Test Container Pattern
**Source:** `fitbodTests/Persistence/SchemaV6MigrationTests.swift` lines 43-60
**Apply to:** `SchemaV7MigrationTests` makeContext helper

```swift
@MainActor
@Suite("SuiteName", .serialized)
struct SomeTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaVN.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }
```

Key requirements: `@MainActor` on the struct, `.serialized` trait on the Suite, `isStoredInMemoryOnly: true`, always pass `migrationPlan: FitbodSchemaMigrationPlan.self`.

### Codable DTO Pattern (no `@Model`)
**Source:** `fitbod/Export/ExportDTOs.swift` lines 68-169
**Apply to:** `ArchivedBlockConfig` and its nested DTOs

- `struct`, never `class`
- Conforms to `Codable, Equatable, Sendable`
- All fields `public let` (immutable)
- Explicit memberwise `public init(...)` (no synthesized init for public structs)
- No SwiftData import
- Date fields use `.iso8601` encoding strategy

### Cross-Stage Boundary Safety
**Source:** `fitbod/Persistence/SchemaV3.swift` header comment lines 40-62; `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` `backfillSessionLevelFields` pattern
**Apply to:** `migrateV6toV7` willMigrate/didMigrate closures

- `willMigrate` fetches `@Model` objects and IMMEDIATELY converts to `internal struct` Sendable value types
- No `@Model` reference escapes the `willMigrate` closure
- Stash structs stored as `internal static var` on `FitbodSchemaMigrationPlan` (or captured via nonisolated storage) — accessible to test helpers

---

## No Analog Found

All files have close analogs. No entries.

---

## Metadata

**Analog search scope:** `fitbod/Persistence/`, `fitbod/Models/`, `fitbod/Models/Enums/`, `fitbod/Export/`, `fitbod/Views/`, `fitbod/Periodization/`, `fitbodTests/Persistence/`, `fitbodTests/`
**Files scanned:** 18 source files read directly
**Pattern extraction date:** 2026-06-10
