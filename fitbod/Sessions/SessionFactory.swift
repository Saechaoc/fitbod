//
//  SessionFactory.swift
//  fitbod
//
//  The load-bearing snapshot deep-copy entry point for Phase 2
//  (PITFALLS-doc #1 / ROUTINE-07). `SessionFactory.start(...)` is the
//  ONLY way to create a new `Session` from a `Routine`:
//
//    1. Insert a new `Session` with `sourceRoutineID = routine.id`
//       (soft UUID ref — NOT a SwiftData @Relationship — so deleting the
//       template never erases the history) and
//       `routineSnapshotName = routine.name` (verbatim at start time so
//       a future rename leaves the session header intact).
//    2. For each `RoutineExercise` in `routine.exercises` (sorted by
//       `orderIndex`), create a `SessionExercise` snapshotting every
//       prescription field (intent / targetSets / repsLow / repsHigh /
//       RPE / RIR / restSeconds / tempo / progressionKind). Editing the
//       source `RoutineExercise` tomorrow MUST NOT mutate these rows.
//    3. Pre-populate planned `SetEntry` rows (one per `targetSets`)
//       seeded with weight from the most recent matching-intent set
//       (via `PreviousMatchingIntent`) if available, else 0. Each row
//       carries `isComplete = false` — the explicit "planned but not
//       yet logged" sentinel locked by plan 00-01.
//
//  Per RESEARCH § Pattern 1: the entire deep-copy is a single
//  `try context.save()` transaction so partial state never persists on
//  failure (load-bearing for UI-SPEC § Error states "Couldn't Start
//  Workout" alert).
//
//  Invariants enforced:
//    - One active session at a time (RESEARCH §6 Pitfall 7) — throws
//      `activeSessionAlreadyExists` if any `Session.completedAt == nil`
//      row exists.
//    - Empty routine guard — throws `routineHasNoExercises` if the
//      source routine has zero `RoutineExercise` rows. UI-SPEC says
//      save is disabled when `RoutineDraft.isValid == false` but the
//      factory guards defensively anyway.
//
//  Phase 3 (plan 03-08) additions:
//    - Block A (Prescription): invokes ProgressionStrategyFactory to
//      compute prescribedWeight per exercise (RESEARCH §SessionFactory
//      Hook Point). The step is `prescription(for:...)`, which a
//      mid-workout swap (SwapExerciseSheet.swap) and an exercise added
//      mid-workout (AddUnplannedExerciseButton.append) reuse for that
//      exercise.
//    - Block B (Warmup): invokes WarmupRamp.shouldGenerate /
//      WarmupRamp.generate for the first qualifying compound exercise.
//      The step is `warmupRamp(for:...)`, which a mid-workout swap
//      reuses to rebuild a pending or skipped ramp for the new exercise.
//    - Internal-static helpers: fetchHistoryPoints, lastSessionWorkingReps,
//      plateInventory(for:context:), equipmentKind(for:) — declared
//      `internal static` so SessionExerciseCard.currentExplanation() can
//      reuse them without duplicating the SwiftData query logic.
//
//  Phase 3.1 (PIVOT-02 / PIVOT-05 / D-14) reshape: intent + progressionKind
//  are session-level fields now, NOT per-exercise. `start(...)` snapshots
//  `routine.intentRaw → session.intentRaw` and
//  `routine.progressionKindRaw → session.progressionKindRaw` exactly once
//  before the per-exercise loop (PITFALLS-doc #1 — the snapshot pattern is
//  preserved verbatim; only the level changes). The per-SessionExercise
//  snapshot now copies just the per-exercise fields that remain:
//  targetSets / targetRepsLow/High / targetRPE / targetRIR /
//  prescribedRestSeconds / tempo / tracksTempo / tracksPartialReps /
//  prescribedWeight. Per D-14, `ProgressionStrategyFactory.make(for:)` is
//  invoked ONCE per session using `session.progressionKind` and the
//  resulting strategy instance is reused for every SessionExercise.
//

import Foundation
import SwiftData

public enum SessionFactoryError: Error {
    case activeSessionAlreadyExists
    case routineHasNoExercises
    case persistenceFailed(underlying: Error)
}

public enum SessionFactory {
    /// Start a new session from a routine. Snapshots routine-level intent
    /// + progressionKind onto the Session (PIVOT-02 / PIVOT-05) before
    /// deep-copying the remaining per-exercise prescription fields from
    /// `RoutineExercise` to `SessionExercise` (PITFALLS-doc #1 /
    /// ROUTINE-07) and pre-populates planned `SetEntry` rows with target
    /// weight pulled from the most recent matching-intent session for
    /// each exercise (`PreviousMatchingIntent.fetchTopWorkingSet`).
    ///
    /// Phase 3 (plan 03-08): also invokes ProgressionStrategyFactory ONCE
    /// per session (D-14 — one strategy per session, reused for every
    /// SessionExercise) to compute `SessionExercise.prescribedWeight`,
    /// and inserts warm-up ramp `SetEntry` rows for the first qualifying
    /// compound exercise (per RESEARCH §SessionFactory Hook Point).
    ///
    /// Phase 8 (CR-02 migrated): `activeBlock` supplies the canonical
    /// block context (resolver output / TodayView activeBlocks.first);
    /// `template.block` is no longer read for prescription resolution.
    /// Pass `activeBlock: nil` (the default) for ad-hoc sessions.
    ///
    /// Phase 8 (CR-01): `slot` is the rotation anchor written onto
    /// `session.slot`. `TodayResolver.resolveRotation` (spec §5) advances
    /// rotation by reading the latest completed session's `slot.position`.
    /// Sessions started without a slot (the default `nil`) are ad-hoc and
    /// fall out of the resolver's anchor scan — preserving ad-hoc
    /// semantics. Production callers that resolve a `.session(slot)` MUST
    /// thread the slot through so rotation actually advances.
    ///
    /// Returns the newly-inserted `Session`. Caller is responsible for
    /// presenting `SessionLoggerView(session: returnedSession)`.
    ///
    /// Throws `SessionFactoryError.activeSessionAlreadyExists` if any
    /// `Session.completedAt == nil` row already exists (RESEARCH §6
    /// Pitfall 7 — one active session at a time). Caller should surface
    /// the UI-SPEC § Error states "Workout in Progress" alert and not
    /// invoke this method until the active session is finished or
    /// discarded.
    ///
    /// Throws `SessionFactoryError.routineHasNoExercises` if the routine
    /// has no exercises.
    ///
    /// Throws `SessionFactoryError.persistenceFailed(underlying:)` if
    /// `context.save()` fails (e.g., disk full, SwiftData constraint
    /// violation). Caller surfaces UI-SPEC's "Couldn't Start Workout"
    /// alert with the underlying error's `localizedDescription`.
    public static func start(
        template: SessionTemplate,
        slot: SplitSessionSlot? = nil,
        activeBlock: Block? = nil,
        on date: Date = .now,
        context: ModelContext
    ) throws -> Session {
        // Empty-template guard — surface as a typed error BEFORE checking
        // the active-session invariant. Both are blocking conditions, but
        // the empty-template path is the cheaper check.
        let exercises = (template.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
        guard !exercises.isEmpty else {
            throw SessionFactoryError.routineHasNoExercises
        }

        // RESEARCH §6 Pitfall 7 — enforce one active session at a time.
        // An "active" session is any row whose `completedAt == nil`.
        let activeDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        if let existing = try? context.fetch(activeDescriptor), !existing.isEmpty {
            throw SessionFactoryError.activeSessionAlreadyExists
        }

        let session = Session()
        session.startedAt = date
        session.completedAt = nil
        session.routineSnapshotName = template.name
        session.sourceRoutineID = template.id          // soft UUID ref
        session.block = activeBlock                     // from resolver context (activeBlock), not the legacy template edge
        session.slot = slot                             // CR-01: rotation anchor; nil = ad-hoc (skipped by TodayResolver)
        session.template = template                     // V7 live edge (nullify on template delete)
        session.templateName = template.name            // V7 log-time name snapshot (freeze #1)
        session.notes = nil
        session.totalDurationSeconds = nil
        context.insert(session)

        // PIVOT-02 / PIVOT-05 — session-level snapshot of intent +
        // progressionKind. The values are copied from the source template
        // at session-start time (PITFALLS-doc #1 — the snapshot pattern
        // is preserved verbatim; only the level changed from per-exercise
        // to per-session). Future edits to `template.intentRaw` /
        // `template.progressionKindRaw` will NOT mutate this session's
        // intent / progressionKind — these fields are independent rows
        // from this point forward.
        session.intentRaw = template.intentRaw
        session.progressionKindRaw = template.progressionKindRaw

        // Fetch UserSettings once for the entire session — used by Block A
        // for defaultIncrementKg and minCalibrationSets.
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let userSettings = (try? context.fetch(settingsDescriptor))?.first

        // Phase 3 (plan 03-08) RESEARCH §SessionFactory Hook Point:
        // warmupGenerated tracks whether ANY exercise in this session has
        // already received a warm-up ramp. Only the FIRST qualifying
        // compound gets a ramp per session.
        var warmupGenerated = false

        // D-14 — one strategy per session; every SessionExercise uses the
        // same strategy instance. Lifted out of the per-exercise loop
        // because intent + progressionKind are now session-level
        // (PIVOT-02). The instance is stateless so reuse is safe.
        let sessionStrategy = ProgressionStrategyFactory.make(for: session.progressionKind)
        let scheduledBlockPhase = activeBlock.flatMap { block in
            PeriodizationEngine.phase(for: block, on: date)
        }
        let scheduledDeloadActive = scheduledBlockPhase?.kind == .deload

        for (orderIndex, re) in exercises.enumerated() {
            let se = SessionExercise()
            se.session = session
            se.exercise = re.exercise
            se.exerciseNameSnapshot = re.exercise?.name ?? ""
            se.orderIndex = orderIndex

            // SNAPSHOT: every per-exercise prescription field copied
            // verbatim. Future edits to `re` will NOT mutate `se` —
            // these are independent rows from this point forward
            // (PITFALLS-doc #1 / ROUTINE-07). Phase 3.1 PIVOT-03: intent
            // + progressionKind no longer live on RoutineExercise /
            // SessionExercise — they are session-level fields snapshotted
            // above (PIVOT-02).
            se.targetSets = re.targetSets
            se.targetRepsLow = re.targetRepsLow
            se.targetRepsHigh = re.targetRepsHigh
            se.targetRPE = re.targetRPE
            se.targetRIR = re.targetRIR
            se.prescribedRestSeconds = re.prescribedRestSeconds
            se.tempo = re.tempo
            // SNAPSHOT (Wave-4 plan 04-02): the routine-side toggles that
            // gate per-set opt-in row rendering in the session logger.
            // Snapshotting these onto SessionExercise keeps the active
            // session decoupled from subsequent edits to the source
            // RoutineExercise's toggles (PITFALLS-doc #1 / ROUTINE-07).
            se.tracksTempo = re.tracksTempo
            se.tracksPartialReps = re.tracksPartialReps
            se.pinnedNote = nil

            context.insert(se)

            // ─── Phase 3 (plan 03-08) RESEARCH §SessionFactory Hook Point ───
            //
            // Block A — Prescription: `prescription(for:...)` computes the
            // prescribed weight for this exercise+intent, then it is stored
            // on the snapshotted SessionExercise row. The caller
            // (SessionExerciseCard.currentExplanation) recomputes the full
            // PrescriptionExplanation at render time — SessionFactory only
            // needs to persist the scalar `prescribedWeight`. A mid-workout
            // swap or added exercise runs the same step for that exercise.
            //
            // D-14 — reuse the session-level strategy instance hoisted
            // above the loop (one strategy per session, used for every
            // SessionExercise).
            let prescription = Self.prescription(
                for: re.exercise,
                targetRepsLow: re.targetRepsLow,
                targetRepsHigh: re.targetRepsHigh,
                targetRPE: re.targetRPE,
                in: session,
                strategy: sessionStrategy,
                userSettings: userSettings,
                context: context
            )
            se.prescribedWeight = prescription.weight

            // ─── Block B — Warmup ───
            //
            // Only the FIRST qualifying compound per session receives a ramp.
            // warmupGenerated tracks whether any prior exercise in this loop
            // already received one. A mid-workout swap runs the same step
            // to rebuild a pending or skipped ramp for the new exercise.
            let warmupSets = warmupGenerated ? [] : Self.warmupRamp(
                for: se,
                prescription: prescription,
                deloadActive: scheduledDeloadActive,
                warmupConfig: re.warmupOverride
            )
            if !warmupSets.isEmpty {
                for warmup in warmupSets {
                    warmup.sessionExercise = se
                    context.insert(warmup)
                }
                warmupGenerated = true
            }

            // RESEARCH §Pitfall 5 / Area 3: "Skip warm-ups this session
            // only" lasts one start. Clear it here even though this start
            // built no ramp for the exercise, so it never suppresses the
            // ramp at the next start. The warm-up on/off setting stays.
            if let override = re.warmupOverride, override.skipNextSession {
                re.warmupOverride = WarmupConfig(enabled: override.enabled, skipNextSession: false)
            }

            // Pre-populate planned `SetEntry` rows. Each set carries the
            // previous-matching-intent weight as a "suggestion" but
            // `isComplete = false` is the explicit "planned, not yet
            // logged" sentinel (plan 00-01 D-3).
            //
            // Working set orderIndex is shifted up by the number of warm-up
            // rows inserted in Block B so warm-up rows occupy indices 0..N-1
            // and working sets start at N. With no previous matching-intent
            // set (the first logged session of this exercise and intent),
            // set rows default to weight 0.
            let seedWeight = prescription.previousSet?.weight ?? 0
            let plannedWorkingSetCount: Int
            if scheduledDeloadActive, let scheduledBlockPhase {
                plannedWorkingSetCount = max(
                    1,
                    Int(floor(Double(re.targetSets) * scheduledBlockPhase.volumeMultiplier))
                )
            } else {
                plannedWorkingSetCount = re.targetSets
            }

            for setIndex in 0..<plannedWorkingSetCount {
                let entry = SetEntry()
                entry.sessionExercise = se
                entry.orderIndex = setIndex + warmupSets.count   // shifted past warm-up slots
                entry.weight = seedWeight
                entry.reps = 0
                entry.rpe = nil
                entry.setTypeRaw = SetType.working.rawValue
                entry.isWarmup = false
                entry.isComplete = false                  // SENTINEL
                entry.completedAt = date                  // overwritten on commit
                context.insert(entry)
            }
        }

        do {
            try context.save()
        } catch {
            throw SessionFactoryError.persistenceFailed(underlying: error)
        }
        return session
    }

    /// Convenience accessor for the single active session, if one exists.
    /// Returns nil when no `Session.completedAt == nil` row is present.
    ///
    /// Used by the Today tab's "Resume workout: {name}" banner
    /// (plan 04-01) and by callers that need to gate "Start Workout" UI
    /// before invoking `start(...)`. Centralized here so the
    /// active-session predicate has exactly one definition (and matches
    /// the gate inside `start`).
    public static func active(in context: ModelContext) -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Prescription step (Block A)

    /// One exercise's prescription: the prescribed weight, plus the bar,
    /// plates and previous matching-intent set it was computed from, which
    /// `start` reuses for the warm-up ramp and the planned sets.
    struct ExercisePrescription {
        let weight: Double
        let barWeight: Double
        let plates: [(weight: Double, countPerSide: Int)]
        let previousSet: PreviousMatchingIntentHit?
    }

    /// The prescription step (Phase 3 plan 03-08): the weight `strategy`
    /// prescribes for `exercise` in `session`, from the session's intent,
    /// block and start date and the exercise's finished history. `start`
    /// runs it for every exercise; a mid-workout swap runs it for the new
    /// exercise and `AddUnplannedExerciseButton.append` for an added one,
    /// so either gets what a fresh start gives it.
    static func prescription(
        for exercise: Exercise?,
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        in session: Session,
        strategy: any ProgressionStrategy,
        userSettings: UserSettings?,
        context: ModelContext
    ) -> ExercisePrescription {
        // Resolve "previous matching-intent weight". PIVOT-02: intent is
        // sourced from the snapshotted session-level field. Only finished
        // sessions count, so `session` never feeds its own prescription.
        let previousSet = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise?.id,
            intentRaw: session.intentRaw,
            context: context,
            excludingSessionID: session.id
        )

        let ekind = equipmentKind(for: exercise?.equipment ?? .other)
        let inventory = plateInventory(for: ekind, context: context)
        let barWeight = exercise?.barWeightOverride ?? inventory.barWeight
        let plates = inventory.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        let smallestIncrement = exercise?.smallestIncrement
            ?? userSettings?.defaultIncrementKg
            ?? 2.5
        let minCalibrationSets = userSettings?.minCalibrationSets ?? 10
        // Labels the explanation text only; weights are stored as entered.
        let unit = WeightUnit.effective(
            for: exercise,
            default: userSettings?.weightUnit ?? .default
        )

        // Fetch history for the strategy (RESEARCH §Pitfall 7 filter applied
        // inside fetchHistoryPoints — nil-RPE sets are excluded).
        // PIVOT-02: intentRaw sourced from session-level snapshot.
        let historyPoints = fetchHistoryPoints(
            exerciseID: exercise?.id,
            intentRaw: session.intentRaw,
            context: context
        )

        // Fetch the last session's working-set reps array for DoubleProgression
        // bump detection. PIVOT-02: intentRaw sourced from session-level snapshot.
        let lastRepsArray = lastSessionWorkingReps(
            exerciseID: exercise?.id,
            intentRaw: session.intentRaw,
            context: context
        )

        // The strategy instance is stateless, so one per session is safe
        // (D-14); the per-exercise variation lives in these inputs.
        let (weight, _) = strategy.prescribe(
            history: historyPoints,
            targetRepsLow: targetRepsLow,
            targetRepsHigh: targetRepsHigh,
            targetRPE: targetRPE,
            lastSessionRepsArray: lastRepsArray.isEmpty ? nil : lastRepsArray,
            smallestIncrement: smallestIncrement,
            plates: plates,
            barWeight: barWeight,
            unit: unit,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: previousSet?.weight,
            lastSessionReps: previousSet?.reps,
            lastSessionRPE: previousSet?.rpe,
            lastSessionDate: previousSet?.sessionStartedAt,
            block: session.block,
            today: session.startedAt
        )
        return ExercisePrescription(
            weight: weight,
            barWeight: barWeight,
            plates: plates,
            previousSet: previousSet
        )
    }

    // MARK: - Warm-up step (Block B)

    /// The warm-up step (Phase 3 plan 03-08): the ramp `WarmupRamp` builds
    /// for `sessionExercise` from its prescription, or none when
    /// `WarmupRamp.shouldGenerate` says it gets none. The rows are not
    /// inserted. `start` runs it for the first qualifying exercise; a
    /// mid-workout swap runs it to rebuild a pending or skipped ramp for
    /// the new exercise, so the swapped exercise gets what a fresh start
    /// gives it.
    static func warmupRamp(
        for sessionExercise: SessionExercise,
        prescription: ExercisePrescription,
        deloadActive: Bool,
        warmupConfig: WarmupConfig?
    ) -> [SetEntry] {
        guard WarmupRamp.shouldGenerate(
            for: sessionExercise,
            deloadActive: deloadActive,
            topWorkingWeight: prescription.weight,
            barWeight: prescription.barWeight,
            warmupConfig: warmupConfig
        ) else { return [] }
        return WarmupRamp.generate(
            top: prescription.weight,
            bar: prescription.barWeight,
            plates: prescription.plates,
            isUnilateral: sessionExercise.exercise?.equipment == .dumbbell
        )
    }

    // MARK: - Internal-static helpers (plan 03-08)
    //
    // Declared `internal static` (not private) so SessionExerciseCard's
    // `currentExplanation()` helper can reuse these query primitives
    // without duplicating the SwiftData #Predicate local-capture pattern
    // (RESEARCH §6 Pitfall 1).

    /// Fetches up to 50 most recent working, completed, RPE-logged SetEntry
    /// rows for the given (exerciseID, intentRaw) pair, maps each to a
    /// HistoryPoint via back-calculated e1RM, and returns them sorted
    /// most-recent-first.
    ///
    /// RESEARCH §Pitfall 7: sets with nil RPE are excluded BEFORE the
    /// back-calc to avoid division-by-nil; sets whose Tuchscherer percent
    /// is nil (e.g. unknown RPE) are also skipped.
    ///
    /// RESEARCH §Pitfall 1: exerciseID and intentRaw are captured as local
    /// constants BEFORE the #Predicate closure — related-entity ID compares
    /// inside the predicate silently return empty on iOS 17/18 without this
    /// local-capture workaround.
    ///
    /// Phase 3.1 PIVOT-05 / D-13: intent is a SESSION-level field after
    /// Plan 02. The #Predicate gates on the single-level `se.exercise?.id`
    /// only, as `PreviousMatchingIntent.lastWorkingSets` does; the
    /// finished-session and intent gates read the parent `Session` in a
    /// Swift post-filter, because those multi-level chains are kept out of
    /// #Predicate.
    ///
    /// Only that exercise's rows are read. The logger rebuilds every card's
    /// explanation on each render, and fetching all completed sets in
    /// history here cost ~0.3 s per call with a year and a half of logs.
    /// The sets are then sorted by `completedAt`, newest first, which is
    /// the order the former all-history `completedAt` sort produced.
    ///
    /// Only sets from FINISHED sessions (`completedAt != nil`) count, the
    /// same rule as `PreviousMatchingIntent.fetchTopWorkingSet`. A set
    /// logged in the workout in progress never feeds its own explanation.
    internal static func fetchHistoryPoints(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> [HistoryPoint] {
        guard let exerciseID else { return [] }

        // RESEARCH §Pitfall 1 — local-let captures required before #Predicate.
        let targetID = exerciseID
        let targetIntent = intentRaw

        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID }
        )
        // Every row's session and sets are read below: load them in bulk
        // instead of one fault per row.
        descriptor.relationshipKeyPathsForPrefetching = [\.session, \.sets]
        guard let sessionExercises = try? context.fetch(descriptor) else { return [] }

        var entries: [SetEntry] = []
        for se in sessionExercises {
            guard let session = se.session,
                  session.completedAt != nil,
                  session.intentRaw == targetIntent
            else { continue }
            for entry in se.sets ?? []
            where !entry.isWarmup && entry.isComplete && entry.reps > 0 && entry.weight > 0 {
                entries.append(entry)
            }
        }
        entries.sort { $0.completedAt > $1.completedAt }

        return entries.prefix(50).compactMap { entry -> HistoryPoint? in
            // RESEARCH §Pitfall 7: skip nil-RPE entries.
            guard let rpe = entry.rpe, rpe >= 6.0 else { return nil }
            let reps = entry.reps
            guard let pct = TuchschererTable.percent(reps: reps, rpe: rpe), pct > 0 else {
                return nil
            }
            let e1RM = entry.weight / pct
            let date = entry.sessionExercise?.session?.startedAt ?? entry.completedAt
            return HistoryPoint(e1RM: e1RM, date: date)
        }
    }

    /// Returns the working-set reps array for the most recent COMPLETED session
    /// matching (exerciseID, intentRaw). Powers DoubleProgressionStrategy's bump
    /// trigger. Returns empty array if no prior session exists.
    ///
    /// A session that logs the exercise more than once counts once: its reps
    /// are read across all of those logs, in workout order and then set order.
    /// A session whose logs hold no working set is skipped, and the walk back
    /// stops after five sessions. The walk is
    /// `PreviousMatchingIntent.lastWorkingSets`, which also picks
    /// `fetchTopWorkingSet`'s session, so the bump reads the same workout as
    /// the previous top set. Its fetch keeps the Phase 3.1 PIVOT-05 / D-13
    /// shape: the #Predicate gates on the exercise only, and the session-level
    /// intent gate is a Swift post-filter (RESEARCH §Pitfall 1).
    ///
    /// Only FINISHED sessions (`completedAt != nil`) count, the same rule
    /// as `PreviousMatchingIntent.fetchTopWorkingSet`, so a set logged in
    /// the workout in progress cannot change its own bump decision.
    internal static func lastSessionWorkingReps(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> [Int] {
        PreviousMatchingIntent.lastWorkingSets(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: context
        )?.sets.map(\.reps) ?? []
    }

    /// Returns the PlateInventory for the given equipment kind. If no row
    /// exists in the store (e.g., the first-launch seed hasn't run yet),
    /// constructs and returns a transient default inventory (NOT inserted
    /// into the context — defense-in-depth to avoid double-seeding).
    internal static func plateInventory(
        for kind: PlateEquipmentKind,
        context: ModelContext
    ) -> PlateInventory {
        // RESEARCH §Pitfall 1 — local-let capture.
        let kindRaw = kind.rawValue

        let descriptor = FetchDescriptor<PlateInventory>(
            predicate: #Predicate { inv in inv.equipmentKindRaw == kindRaw }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }

        // Fallback: construct a transient inventory using canonical defaults.
        // Fetch UserSettings for the unit system; fall back to the app default.
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let unit = (try? context.fetch(settingsDescriptor))?.first?.weightUnit ?? .default

        let transient = PlateInventory()
        transient.equipmentKind = kind
        transient.barWeight = PlateInventoryDefaults.barWeight(for: kind, unitSystem: unit)
        transient.availablePlates = PlateInventoryDefaults.make(for: kind, unitSystem: unit)
        // NOT inserted into context — read-only use for prescribe() math.
        return transient
    }

    /// Maps an Exercise `Equipment` value to a `PlateEquipmentKind` for
    /// inventory lookup. Non-barbell/dumbbell equipment falls back to
    /// `.barbell` (the safest default for plate math).
    internal static func equipmentKind(for equipment: Equipment) -> PlateEquipmentKind {
        switch equipment {
        case .barbell:  return .barbell
        case .dumbbell: return .dumbbell
        default:        return .barbell
        }
    }
}

// MARK: - Phase 6 / Plan 06-07 — Per-session PR table seeding
//
// Builds the per-exercise PR table once at session start so the
// in-session detector (InSessionPRState.observeSave) never re-queries
// SwiftData on a per-set commit.
//
// The fetch reads only the session's exercises: one SessionExercise fetch
// per exercise on the single-level `se.exercise?.id` gate, then their
// sets. A multi-level optional chain such as
// `entry.sessionExercise?.exercise?.id` inside #Predicate compiles but
// throws NSInvalidArgumentException at fetch time ("Unsupported function
// expression TERNARY(...)"), which crashed the logger on every open. A
// broad fetch of every completed set with that gate in Swift avoided the
// crash but took ~0.3 s per seed with a year and a half of history, on
// every logger open, un-complete and set delete.

extension SessionFactory {

    /// Seeds the PR table from every completed working-candidate set of
    /// the exercises in `session` (including sets already logged in this
    /// session, so a resumed workout keeps its in-session PRs).
    ///
    /// Sets are fed to the table oldest first by `completedAt`, so on
    /// equal values the earlier set keeps the record.
    ///
    /// Returns an empty `PRTable` when the session has no exercises or
    /// a fetch fails; the in-session banner then simply emits no PRs
    /// until the first set lands and seeds the table inline.
    @MainActor
    public static func seedPRTable(for session: Session, context: ModelContext) async -> PRTable {
        var seen: Set<UUID> = []
        let exerciseIDs = (session.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { $0.exercise?.id }
            .filter { seen.insert($0).inserted }
        guard !exerciseIDs.isEmpty else { return PRTable() }

        var candidates: [SetEntry] = []
        for exerciseID in exerciseIDs {
            let targetID = exerciseID
            var descriptor = FetchDescriptor<SessionExercise>(
                predicate: #Predicate<SessionExercise> { se in
                    se.exercise?.id == targetID
                }
            )
            // The table reads every row's sets and session.
            descriptor.relationshipKeyPathsForPrefetching = [\.sets, \.session]
            guard let sessionExercises = try? context.fetch(descriptor) else { return PRTable() }
            for se in sessionExercises {
                for entry in se.sets ?? [] where entry.isComplete && !entry.isWarmup {
                    candidates.append(entry)
                }
            }
        }
        candidates.sort { $0.completedAt < $1.completedAt }
        return PRDetector.buildTable(from: candidates)
    }
}
