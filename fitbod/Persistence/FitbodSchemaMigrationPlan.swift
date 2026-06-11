//
//  FitbodSchemaMigrationPlan.swift
//  fitbod
//
//  The project's schema migration plan (FOUND-01 / PITFALLS #2). Phase 1
//  laid the V1 wrapper, Phase 2 added the lightweight V1→V2 stage, Phase 3
//  added the lightweight V2→V3 stage, and Phase 3.1 (PIVOT-03) adds the
//  V3→V4 CUSTOM stage that backfills `Routine.intentRaw` / `intentRaw` /
//  `progressionKindRaw` from the most-common per-exercise value across
//  each routine's / session's `RoutineExercise` / `SessionExercise` rows.
//
//  Why the V3↔V4 stage cannot be lightweight: Plan 02 REMOVES
//  `RoutineExercise.intentRaw` / `RoutineExercise.progressionKindRaw` /
//  `SessionExercise.intentRaw` / `SessionExercise.progressionKindRaw` and
//  ADDS `Routine.intentRaw` / `Routine.progressionKindRaw` /
//  `Session.intentRaw` / `Session.progressionKindRaw`. Lightweight
//  migrations can't transfer values between entities. The custom stage's
//  willMigrate closure reads V3-shape RE/SE rows via the
//  `SchemaV3.RoutineExercise` / `SchemaV3.SessionExercise` nested types
//  (see SchemaV3.swift) and writes V4-shape Routine / Session rows via
//  the `SchemaV4.Routine` / `SchemaV4.Session` typealiases.
//
//  [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
//  [CITED: WWDC23 "Migrate to SwiftData" — namespaced @Model types per
//          VersionedSchema is Apple's documented pattern for migrations
//          that move fields between entities.]
//
//  Per CONTEXT.md Specifics: the user wiped + reseeded a fresh SchemaV3
//  database earlier today, so there are no real V3 rows that need
//  migrating for v1 ship — the production users won't have V3 stores at
//  all when v1 ships. SchemaV4MigrationTests is the canonical correctness
//  gate for the closure's semantics; the closure itself is exercised
//  literally in tests.
//
//  Per CONTEXT.md D-05: SINGLE custom stage covers all four field
//  additions + three field removals at once. No didMigrate.
//
//  Per CONTEXT.md D-06 / D-07: tie-break to `.strength` for intent and
//  `.double` for progressionKind when multiple per-exercise values tie
//  for most-common. The `modeRaw(of:tieBreak:)` helper implements the
//  rule and is shared between the willMigrate closure and unit tests.
//
//  Keeping `SchemaV1.self` / `SchemaV2.self` / `SchemaV3.self` in the
//  `schemas` array is non-negotiable — SwiftData needs every historical
//  schema registered so it can match an existing on-disk store at any
//  version and chain through the appropriate migration stages.
//

import Foundation
import SwiftData

public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self,
         SchemaV5.self, SchemaV6.self, SchemaV7.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5,
         migrateV5toV6, migrateV6toV7]
    }

    /// Lightweight: SwiftData handles all schema deltas automatically.
    /// Plan 00-01's deltas are all additive (new entity types + new
    /// default-valued fields) — explicitly eligible per Apple's
    /// documentation. No willMigrate / didMigrate closures needed.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
    public static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    /// Lightweight: Plan 03-01's deltas are all additive (1 new entity type
    /// PlateInventory + 7 default-valued fields on existing entities) —
    /// explicitly eligible per Apple's documentation. No willMigrate /
    /// didMigrate closures needed.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
    public static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    /// Lightweight: Phase 4 SchemaV5 adds `Block.reviewedAt: Date? =
    /// nil` (D-26 / D-21 — end-of-block review timestamp). The delta is
    /// a single additive Optional<Date> field on an existing @Model
    /// with a nil default — Apple's lightweight migration handles
    /// additive optional fields without a willMigrate closure.
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight]
    public static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    /// Custom: Phase 5 SchemaV6 adds 8 additive default-valued fields AND
    /// retroactively bumps `UserSettings.plateauTolerance` from 0.005 to
    /// 0.02 (D-12). The additive fields are lightweight-eligible, but the
    /// default-bump nuance forces a custom stage because lightweight
    /// migration does NOT rewrite existing rows when a `@Model` default
    /// changes (per RESEARCH §9.2). The willMigrate closure fetches the
    /// singleton UserSettings and bumps `plateauTolerance` if and only if
    /// it equals the prior default (0.005); user-edited values like 0.015
    /// fail the float-equality check and are preserved verbatim.
    ///
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
    public static let migrateV5toV6 = MigrationStage.custom(
        fromVersion: SchemaV5.self,
        toVersion: SchemaV6.self,
        willMigrate: { context in
            try Self.bumpPlateauToleranceDefault(in: context)
        },
        didMigrate: nil
    )

    /// Custom: Phase 7 SchemaV7 renames `Routine`→`SessionTemplate` and
    /// `RoutineExercise`→`SessionExerciseTemplate` (entity-level rename — rows
    /// must be stashed before the table is dropped and recreated). Also adds
    /// `Split`/`SplitSessionSlot` entities and backfills `Session.template`,
    /// `Session.slot`, `Session.templateName`, and `Block.archivedConfigJSON`.
    ///
    /// Orchestrator decision #2 (templateName backfill): `Session.templateName`
    /// is backfilled from the remapped `SessionTemplate.name` — equivalent to
    /// the existing `routineSnapshotName` log-time snapshot semantics.
    /// No duplicate snapshot column was added; the step reuses the same
    /// concept as the existing field, applied to the new template relationship.
    ///
    /// 7-step migration (spec §7):
    ///   1. willMigrate: stash Routine rows (incl. block?.id) + Session→Routine
    ///      pairs as Sendable plain structs (no @Model crosses stage boundary).
    ///   2. didMigrate: create SessionTemplate per stash row; remap Session.template.
    ///   3. Per block with templates: create Split "{name} split", name-sorted slots,
    ///      mode .rotation. Completed blocks → split.isArchived = true.
    ///   4. Backfill Session.slot on active block's last completed session.
    ///   5. Backfill Session.templateName from remapped template name.
    ///   6. Best-effort archivedConfigJSON for completed blocks.
    ///   7. Old Routine.block field dies with the entity (no code needed).
    ///
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
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

    // MARK: - V6→V7 stash types
    // Plain Sendable value types — safe to hold across the willMigrate/didMigrate
    // stage boundary. @Model objects fetched in willMigrate are invalidated when
    // the stage completes; only these structs survive (Pattern 1 / SchemaV3 header).

    /// Stash of one V6 Routine row. `internal` so SchemaV7MigrationTests can
    /// construct test fixtures and call `stashV6Routines`/`materializeSessionTemplates`
    /// directly (same testability pattern as `bumpPlateauToleranceDefault`).
    internal struct RoutineStash: Sendable {
        let id: UUID
        let name: String
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
        let isArchived: Bool
        let folderID: UUID?
        /// Captured from `Routine.block?.id` — step 3 (auto-Split per block) depends on this.
        let blockID: UUID?
        let intentRaw: String
        let progressionKindRaw: String
        /// Stashed exercises needed to rebuild SessionExerciseTemplate rows in didMigrate.
        let exercises: [RoutineExerciseStash]
    }

    /// Stash of one V6 RoutineExercise row (per-exercise prescription fields).
    internal struct RoutineExerciseStash: Sendable {
        let id: UUID
        let exerciseID: UUID?
        let orderIndex: Int
        let targetSets: Int
        let targetRepsLow: Int
        let targetRepsHigh: Int
        let targetRPE: Double?
        let targetRIR: Int?
        let prescribedRestSeconds: Int
        let tempo: String?
        let notes: String?
        let generateWarmups: Bool
        let supersetGroupID: UUID?
        let tracksTempo: Bool
        let tracksPartialReps: Bool
        let warmupOverrideData: Data?
    }

    /// Stash of one V6 Session→Routine pair. Used in step 2 to remap Session.template.
    internal struct SessionRoutineStash: Sendable {
        let sessionID: UUID
        /// `sourceRoutineID` from the V6 Session (soft UUID ref to the old Routine).
        let routineID: UUID?
    }

    // MARK: - V6→V7 stash storage
    // `nonisolated(unsafe)` storage lets the static vars be set from the migration
    // closures (which run on an unspecified executor) without strict-concurrency
    // violations. The migration plan enum is never instantiated; these vars act as
    // thread-local scratch storage for the duration of a single migration run.
    internal nonisolated(unsafe) static var v6RoutineStash: [RoutineStash] = []
    internal nonisolated(unsafe) static var v6SessionStash: [SessionRoutineStash] = []

    // MARK: - V6→V7 helpers (internal static for test access)

    /// willMigrate helper — stashes V6 Routine + Session rows as plain Sendable
    /// structs BEFORE SwiftData drops the Routine/RoutineExercise tables.
    ///
    /// `internal static` so `SchemaV7MigrationTests` can call it directly against
    /// an in-memory context (same pattern as `bumpPlateauToleranceDefault`).
    /// Captured @Model objects are converted to value types immediately — no @Model
    /// reference escapes this function (Pitfall 1 / cross-stage boundary rule).
    internal static func stashV6Routines(in context: ModelContext) throws {
        // Fetch V6-shape Routine rows via the nested type (requires SchemaV6.models
        // to include Self.Routine.self — Pitfall 4 fix in SchemaV6.swift).
        let routines = try context.fetch(FetchDescriptor<SchemaV6.Routine>())
        // Build exercise stash per routine in one pass.
        v6RoutineStash = routines.map { r in
            let exerciseStash = (r.exercises ?? []).map { re in
                RoutineExerciseStash(
                    id: re.id,
                    exerciseID: re.exercise?.id,
                    orderIndex: re.orderIndex,
                    targetSets: re.targetSets,
                    targetRepsLow: re.targetRepsLow,
                    targetRepsHigh: re.targetRepsHigh,
                    targetRPE: re.targetRPE,
                    targetRIR: re.targetRIR,
                    prescribedRestSeconds: re.prescribedRestSeconds,
                    tempo: re.tempo,
                    notes: re.notes,
                    generateWarmups: re.generateWarmups,
                    supersetGroupID: re.supersetGroupID,
                    tracksTempo: re.tracksTempo,
                    tracksPartialReps: re.tracksPartialReps,
                    warmupOverrideData: re.warmupOverrideData
                )
            }
            return RoutineStash(
                id: r.id,
                name: r.name,
                notes: r.notes,
                createdAt: r.createdAt,
                updatedAt: r.updatedAt,
                isArchived: r.isArchived,
                folderID: r.folderID,
                blockID: r.block?.id,   // step 3 depends on this
                intentRaw: r.intentRaw,
                progressionKindRaw: r.progressionKindRaw,
                exercises: exerciseStash
            )
        }
        // Stash Session→Routine ID pairs for step 2 (remap Session.template).
        let sessions = try context.fetch(FetchDescriptor<Session>())
        v6SessionStash = sessions.map { s in
            SessionRoutineStash(sessionID: s.id, routineID: s.sourceRoutineID)
        }
    }

    /// didMigrate helper — runs the 7-step materialization after SwiftData has
    /// applied the schema migration (new tables exist; old Routine table is gone).
    ///
    /// Steps 2–6 per spec §7. Step 7 (old Routine.block dies with the entity)
    /// requires no code — it is the natural consequence of the entity rename.
    ///
    /// `internal static` so `SchemaV7MigrationTests` can drive semantics directly.
    internal static func materializeSessionTemplates(in context: ModelContext) throws {
        // ── Step 2: Create SessionTemplate per stash row ──────────────────────────
        // Insert before relating (project convention — never assign relationships
        // in init).
        var routineIDToTemplate: [UUID: SessionTemplate] = [:]
        for stash in v6RoutineStash {
            let template = SessionTemplate()
            context.insert(template)
            template.id = stash.id
            template.name = stash.name
            template.notes = stash.notes
            template.createdAt = stash.createdAt
            template.updatedAt = stash.updatedAt
            template.isArchived = stash.isArchived
            template.folderID = stash.folderID
            template.intentRaw = stash.intentRaw
            template.progressionKindRaw = stash.progressionKindRaw
            routineIDToTemplate[stash.id] = template

            // Rebuild SessionExerciseTemplate rows (ordered by stash orderIndex).
            // Fetch the Exercise catalog row by ID for the relationship.
            for exStash in stash.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                let set = SessionExerciseTemplate()
                context.insert(set)
                set.id = exStash.id
                set.sessionTemplate = template
                set.orderIndex = exStash.orderIndex
                set.targetSets = exStash.targetSets
                set.targetRepsLow = exStash.targetRepsLow
                set.targetRepsHigh = exStash.targetRepsHigh
                set.targetRPE = exStash.targetRPE
                set.targetRIR = exStash.targetRIR
                set.prescribedRestSeconds = exStash.prescribedRestSeconds
                set.tempo = exStash.tempo
                set.notes = exStash.notes
                set.generateWarmups = exStash.generateWarmups
                set.supersetGroupID = exStash.supersetGroupID
                set.tracksTempo = exStash.tracksTempo
                set.tracksPartialReps = exStash.tracksPartialReps
                set.warmupOverrideData = exStash.warmupOverrideData
                if let exerciseID = exStash.exerciseID {
                    var exDescriptor = FetchDescriptor<Exercise>(
                        predicate: #Predicate { $0.id == exerciseID }
                    )
                    exDescriptor.fetchLimit = 1
                    if let exercise = try context.fetch(exDescriptor).first {
                        set.exercise = exercise
                    }
                }
            }
        }

        // Remap Session.template using the session stash.
        let sessions = try context.fetch(FetchDescriptor<Session>())
        let sessionByID: [UUID: Session] = Dictionary(
            uniqueKeysWithValues: sessions.map { ($0.id, $0) }
        )
        for stash in v6SessionStash {
            guard let session = sessionByID[stash.sessionID] else { continue }
            if let routineID = stash.routineID {
                session.template = routineIDToTemplate[routineID]
            }
        }

        // ── Step 3: Auto-create Split per block with attached templates ───────────
        // Group templates by blockID (from willMigrate stash).
        let templatesByBlockID: [UUID: [RoutineStash]] = Dictionary(
            grouping: v6RoutineStash.filter { $0.blockID != nil },
            by: { $0.blockID! }
        )
        let blocks = try context.fetch(FetchDescriptor<Block>())
        var blockIDToSplit: [UUID: Split] = [:]

        for block in blocks {
            guard let routineStashes = templatesByBlockID[block.id],
                  !routineStashes.isEmpty else { continue }

            let split = Split()
            context.insert(split)
            split.name = "\(block.name) split"
            split.createdAt = block.startDate
            // Completed blocks' auto-splits are born archived (history doesn't
            // pollute the picker per spec §7).
            split.isArchived = block.endDate != nil

            // Wire block→split after both are inserted.
            block.split = split
            block.schedulingModeRaw = "rotation"

            blockIDToSplit[block.id] = split

            // Slots in name-sorted order (matches the old weekday heuristic per spec §7).
            let sortedStashes = routineStashes.sorted { $0.name < $1.name }
            for (position, stash) in sortedStashes.enumerated() {
                guard let template = routineIDToTemplate[stash.id] else { continue }
                let slot = SplitSessionSlot()
                context.insert(slot)
                slot.split = split
                slot.position = position
                slot.sessionTemplate = template
            }
        }

        // ── Step 4: Backfill Session.slot on active block's last completed session ─
        // Rotation continuity: find the active block, get its split, find the last
        // completed session whose template matches a slot in that split, and set
        // Session.slot to the corresponding slot.
        if let activeBlock = blocks.first(where: { $0.isActive }),
           let activeSplit = activeBlock.split,
           let slots = activeSplit.slots {

            // Sessions associated with the active block, that are completed (have
            // completedAt), ordered by most recent first.
            let blockSessions = sessions
                .filter { $0.block?.id == activeBlock.id && $0.completedAt != nil }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

            // The name-sorted slot list mirrors the willMigrate sort — positional
            // index maps to the auto-created slot position.
            let sortedSlots = slots.sorted { $0.position < $1.position }

            // Find the last completed session whose template is one of this split's slots.
            for session in blockSessions {
                guard let tmpl = session.template else { continue }
                if let slotIndex = sortedSlots.firstIndex(where: {
                    $0.sessionTemplate?.id == tmpl.id
                }) {
                    session.slot = sortedSlots[slotIndex]
                    break   // only the most recent completed session gets the backfill
                }
            }
        }

        // ── Step 5: Backfill Session.templateName ────────────────────────────────
        // Reuses routineSnapshotName semantics — set from the remapped template name
        // (orchestrator decision #2: no duplicate snapshot column was added).
        for session in sessions {
            if let tmpl = session.template {
                session.templateName = tmpl.name
            } else if !session.routineSnapshotName.isEmpty {
                // Fall back to the existing snapshot if the template ref is nil
                // (ad-hoc sessions or sessions whose routine was deleted pre-migration).
                session.templateName = session.routineSnapshotName
            }
        }

        // ── Step 6: Best-effort archivedConfigJSON for completed blocks ──────────
        // Encode ArchivedBlockConfig from post-migration state. Drift is accepted
        // per spec §6 — exercise names and prescriptions may differ from what was
        // active at block-end time, but the archive is better than nothing.
        for block in blocks where block.endDate != nil {
            guard let split = block.split,
                  let slots = split.slots,
                  let endDate = block.endDate else { continue }

            let sortedSlots = slots.sorted { $0.position < $1.position }
            let slotDTOs = sortedSlots.map { slot -> ArchivedSlotDTO in
                let exercises = (slot.sessionTemplate?.exercises ?? [])
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .compactMap { ex -> ArchivedExerciseDTO? in
                        guard let exercise = ex.exercise else { return nil }
                        return ArchivedExerciseDTO(
                            exerciseID: exercise.id,
                            exerciseName: exercise.name,
                            orderIndex: ex.orderIndex,
                            targetSets: ex.targetSets,
                            targetRepsLow: ex.targetRepsLow,
                            targetRepsHigh: ex.targetRepsHigh,
                            targetRPE: ex.targetRPE,
                            targetRIR: ex.targetRIR,
                            prescribedRestSeconds: ex.prescribedRestSeconds,
                            tempo: ex.tempo,
                            notes: ex.notes,
                            intentRaw: slot.sessionTemplate?.intentRaw ?? "strength",
                            progressionKindRaw: slot.sessionTemplate?.progressionKindRaw ?? "double",
                            generateWarmups: ex.generateWarmups,
                            tracksTempo: ex.tracksTempo,
                            tracksPartialReps: ex.tracksPartialReps
                        )
                    }
                return ArchivedSlotDTO(
                    position: slot.position,
                    sessionName: slot.sessionTemplate?.name ?? "",
                    exercises: exercises
                )
            }

            let phaseDTOs = (block.phases ?? []).map { phase -> ArchivedPhaseDTO in
                ArchivedPhaseDTO(
                    kind: phase.nameRaw,   // BlockPhase uses nameRaw (not kindRaw)
                    weeks: phase.weeks,
                    volumeMultiplier: phase.volumeMultiplier,
                    intensityMultiplier: phase.intensityMultiplier,
                    notes: phase.notes
                )
            }

            let archiveConfig = ArchivedBlockConfig(
                v: 1,
                blockName: block.name,
                startedAt: block.startDate,
                endedAt: endDate,
                mode: block.schedulingModeRaw,
                trainingDays: block.trainingDays,
                phases: phaseDTOs,
                split: ArchivedSplitDTO(name: split.name, slots: slotDTOs)
            )

            if let jsonData = try? archiveConfig.encoded(),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                block.archivedConfigJSON = jsonString
            }
        }

        try context.save()

        // Clear stash storage after successful migration (free memory).
        v6RoutineStash = []
        v6SessionStash = []
    }

    /// Extracted bump body — same logic the willMigrate closure delegates to.
    /// `internal static` so both the migration stage AND `SchemaV6MigrationTests`
    /// can call it directly (MigrationStage closures aren't invokable from
    /// fixture tests; tests drive the semantics through this helper after
    /// SwiftData runs the open-V5 → reopen-V6 cycle).
    internal static func bumpPlateauToleranceDefault(in context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<UserSettings>())
        for row in settings {
            // Compare against the OLD V5 default (0.005). User-edited values
            // (e.g., 0.015) fail this check and are preserved.
            if abs(row.plateauTolerance - 0.005) < 1e-9 {
                row.plateauTolerance = 0.02
            }
        }
        // CR-03: propagate save failures so a failed bump aborts the V5→V6 stage
        // instead of silently opening the V6 store with the un-bumped default
        // (matches `materializeSessionTemplates`, which uses `try context.save()`).
        try context.save()
    }

    /// Custom: Phase 3.1 PIVOT-03 moves intent + progressionKind from
    /// per-exercise (RoutineExercise / SessionExercise) to per-session
    /// (Routine / Session). The didMigrate closure reads V4 intermediate
    /// RE/SE rows via `SchemaV4.RoutineExercise` / `SchemaV4.SessionExercise`
    /// (which still retain the child raw fields) and computes the
    /// most-common-with-tie-break value per Routine and per Session, then
    /// writes those values onto V4-shape Routine / Session rows via the
    /// `SchemaV4.Routine` / `SchemaV4.Session` typealiases.
    ///
    /// PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
    /// tie-break. Reads via SchemaV3 nested types (V3 shape); writes via
    /// SchemaV4 typealiased types (V4 shape). The four field-writes
    /// landed in Plan 02 of Phase 3.1 alongside the model reshape.
    ///
    /// [CITED: developer.apple.com/documentation/swiftdata/migrationstage/custom]
    public static let migrateV3toV4 = MigrationStage.custom(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self,
        willMigrate: nil,
        didMigrate: { context in
            try Self.backfillSessionLevelFields(in: context)
        }
    )

    /// Extracted backfill body — same logic the willMigrate closure
    /// delegates to. `internal static` so both the migration stage AND
    /// `SchemaV4MigrationTests` can call it (MigrationStage's willMigrate
    /// closure isn't directly invokable from a test fixture, so the test
    /// suite drives the migration semantics by calling this helper
    /// directly against an in-memory ModelContext registered with both
    /// SchemaV3 nested types and SchemaV4 typealiases).
    ///
    /// PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
    /// tie-break. Reads via SchemaV4 intermediate child rows; writes via
    /// SchemaV4 parent rows after the V3->V4 mapping has completed.
    internal static func backfillSessionLevelFields(in context: ModelContext) throws {
        // Fetch V4 intermediate child rows. They still carry the
        // deprecated intentRaw / progressionKindRaw fields so this didMigrate
        // closure can backfill the new parent-level fields.
        let v4REs = try context.fetch(FetchDescriptor<SchemaV4.RoutineExercise>())
        let v4SEs = try context.fetch(FetchDescriptor<SchemaV4.SessionExercise>())

        // Fetch V4-shape Routine + Session rows via the typealiases.
        // After Plan 02 these rows have new intent / progressionKind
        // fields with default values; the closure overwrites those
        // defaults with the backfilled mode-of-children value.
        let v4Routines = try context.fetch(FetchDescriptor<SchemaV4.Routine>())
        let v4Sessions = try context.fetch(FetchDescriptor<SchemaV4.Session>())

        for routine in v4Routines {
            let routineV4REs = v4REs.filter { $0.routine?.id == routine.id }
            let intents = routineV4REs.map { $0.intentRaw }
            let progressions = routineV4REs.map { $0.progressionKindRaw }
            // PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
            // tie-break. Reads via SchemaV3 nested types (V3 shape); writes
            // via SchemaV4 typealiased types (V4 shape).
            routine.intentRaw = Self.modeRaw(of: intents, tieBreak: "strength")
            routine.progressionKindRaw = Self.modeRaw(of: progressions, tieBreak: "double")
        }

        for session in v4Sessions {
            let sessionV4SEs = v4SEs.filter { $0.session?.id == session.id }
            let sessionIntents = sessionV4SEs.map { $0.intentRaw }
            let sessionProgressions = sessionV4SEs.map { $0.progressionKindRaw }
            // PIVOT-03 backfill: mode-of-per-exercise-value with deterministic
            // tie-break. Reads via SchemaV3 nested types (V3 shape); writes
            // via SchemaV4 typealiased types (V4 shape).
            session.intentRaw = Self.modeRaw(of: sessionIntents, tieBreak: "strength")
            session.progressionKindRaw = Self.modeRaw(of: sessionProgressions, tieBreak: "double")
        }

        try context.save()
    }

    // MARK: - Migration helpers

    /// Deterministic mode-with-tie-break used by the V3→V4 backfill and by
    /// `SchemaV4MigrationTests`. Behavior:
    ///   - empty input → returns `tieBreak`
    ///   - single most-common value → returns it
    ///   - multiple values tied for most-common → returns `tieBreak` if it
    ///     is one of the top keys, otherwise the alphabetically-first top key
    ///
    /// `internal` (not `private`) so both the willMigrate closure above and
    /// the test suite can call it directly. Exposed as `static` so callers
    /// don't have to instantiate the enum case (which is impossible anyway).
    internal static func modeRaw(of values: [String], tieBreak: String) -> String {
        guard !values.isEmpty else { return tieBreak }
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        let maxCount = counts.values.max() ?? 0
        let topKeys = counts.filter { $0.value == maxCount }.map { $0.key }
        if topKeys.contains(tieBreak) { return tieBreak }
        return topKeys.sorted().first ?? tieBreak
    }
}
