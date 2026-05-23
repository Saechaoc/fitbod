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
//      Hook Point).
//    - Block B (Warmup): invokes WarmupRamp.shouldGenerate /
//      WarmupRamp.generate for the first qualifying compound exercise.
//    - Internal-static helpers: fetchHistoryPoints, lastSessionWorkingReps,
//      plateInventory(for:context:), equipmentKind(for:) — declared
//      `internal static` so SessionExerciseCard.currentExplanation() can
//      reuse them without duplicating the SwiftData query logic.
//

import Foundation
import SwiftData

public enum SessionFactoryError: Error {
    case activeSessionAlreadyExists
    case routineHasNoExercises
    case persistenceFailed(underlying: Error)
}

public enum SessionFactory {
    /// Start a new session from a routine. Deep-copies every prescription
    /// field from `RoutineExercise` to `SessionExercise` (PITFALLS-doc #1
    /// / ROUTINE-07) and pre-populates planned `SetEntry` rows with
    /// target weight pulled from the most recent matching-intent session
    /// for each exercise (`PreviousMatchingIntent.fetchTopWorkingSet`).
    ///
    /// Phase 3 (plan 03-08): also invokes ProgressionStrategyFactory per
    /// exercise to compute `SessionExercise.prescribedWeight`, and inserts
    /// warm-up ramp `SetEntry` rows for the first qualifying compound
    /// exercise (per RESEARCH §SessionFactory Hook Point).
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
        routine: Routine,
        on date: Date = .now,
        context: ModelContext
    ) throws -> Session {
        // Empty-routine guard — surface as a typed error BEFORE checking
        // the active-session invariant. Both are blocking conditions, but
        // the empty-routine path is the cheaper check.
        let exercises = (routine.exercises ?? [])
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
        session.routineSnapshotName = routine.name
        session.sourceRoutineID = routine.id          // soft UUID ref
        session.block = routine.block                 // optional; safe to carry forward
        session.notes = nil
        session.totalDurationSeconds = nil
        context.insert(session)

        // Fetch UserSettings once for the entire session — used by Block A
        // for defaultIncrementKg and minCalibrationSets.
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let userSettings = (try? context.fetch(settingsDescriptor))?.first

        // Phase 3 (plan 03-08) RESEARCH §SessionFactory Hook Point:
        // warmupGenerated tracks whether ANY exercise in this session has
        // already received a warm-up ramp. Only the FIRST qualifying
        // compound gets a ramp per session.
        var warmupGenerated = false

        for (orderIndex, re) in exercises.enumerated() {
            let se = SessionExercise()
            se.session = session
            se.exercise = re.exercise
            se.orderIndex = orderIndex

            // SNAPSHOT: every prescription field copied verbatim. Future
            // edits to `re` will NOT mutate `se` — these are independent
            // rows from this point forward (PITFALLS-doc #1 / ROUTINE-07).
            se.intentRaw = re.intentRaw
            se.targetSets = re.targetSets
            se.targetRepsLow = re.targetRepsLow
            se.targetRepsHigh = re.targetRepsHigh
            se.targetRPE = re.targetRPE
            se.targetRIR = re.targetRIR
            se.prescribedRestSeconds = re.prescribedRestSeconds
            se.tempo = re.tempo
            se.progressionKindRaw = re.progressionKindRaw
            // SNAPSHOT (Wave-4 plan 04-02): the routine-side toggles that
            // gate per-set opt-in row rendering in the session logger.
            // Snapshotting these onto SessionExercise keeps the active
            // session decoupled from subsequent edits to the source
            // RoutineExercise's toggles (PITFALLS-doc #1 / ROUTINE-07).
            se.tracksTempo = re.tracksTempo
            se.tracksPartialReps = re.tracksPartialReps
            se.pinnedNote = nil

            context.insert(se)

            // Resolve "previous matching-intent weight" for the planned
            // `SetEntry` rows. Returns nil for the first-ever logged
            // session of this (exercise, intent) tuple → set rows default
            // weight = 0.
            let previousHint = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: re.exercise?.id,
                intentRaw: re.intentRaw,
                context: context
            )

            // ─── Phase 3 (plan 03-08) RESEARCH §SessionFactory Hook Point ───
            //
            // Block A — Prescription: invoke ProgressionStrategyFactory to
            // compute the prescribed weight for this exercise+intent, then
            // store it on the snapshotted SessionExercise row. The caller
            // (SessionExerciseCard.currentExplanation) recomputes the full
            // PrescriptionExplanation at render time — SessionFactory only
            // needs to persist the scalar `prescribedWeight` so the SetEntry
            // rows can be seeded with it.
            //
            let ekind = Self.equipmentKind(for: re.exercise?.equipment ?? .other)
            let inventory = Self.plateInventory(for: ekind, context: context)
            let barWeight = re.exercise?.barWeightOverride ?? inventory.barWeight
            let plates = inventory.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
            let smallestIncrement = re.exercise?.smallestIncrement
                ?? userSettings?.defaultIncrementKg
                ?? 2.5
            let minCalibrationSets = userSettings?.minCalibrationSets ?? 10

            // Fetch history for the strategy (RESEARCH §Pitfall 7 filter applied
            // inside fetchHistoryPoints — nil-RPE sets are excluded).
            let historyPoints = Self.fetchHistoryPoints(
                exerciseID: re.exercise?.id,
                intentRaw: re.intentRaw,
                context: context
            )

            // Fetch the last session's working-set reps array for DoubleProgression
            // bump detection.
            let lastRepsArray = Self.lastSessionWorkingReps(
                exerciseID: re.exercise?.id,
                intentRaw: re.intentRaw,
                context: context
            )

            // Previous-intent scalars (already fetched above for the SetEntry hint).
            let lastSessionWeight = previousHint?.weight
            let lastSessionReps = previousHint?.reps
            let lastSessionRPE = previousHint?.rpe
            let lastSessionDate = previousHint?.sessionStartedAt

            let strategy = ProgressionStrategyFactory.make(for: re.progressionKind)
            let (prescribedWeight, _) = strategy.prescribe(
                history: historyPoints,
                targetRepsLow: re.targetRepsLow,
                targetRepsHigh: re.targetRepsHigh,
                targetRPE: re.targetRPE,
                lastSessionRepsArray: lastRepsArray.isEmpty ? nil : lastRepsArray,
                smallestIncrement: smallestIncrement,
                plates: plates,
                barWeight: barWeight,
                minCalibrationSets: minCalibrationSets,
                lastSessionWeight: lastSessionWeight,
                lastSessionReps: lastSessionReps,
                lastSessionRPE: lastSessionRPE,
                lastSessionDate: lastSessionDate
            )
            se.prescribedWeight = prescribedWeight

            // ─── Block B — Warmup ───
            //
            // Only the FIRST qualifying compound per session receives a ramp.
            // warmupGenerated tracks whether any prior exercise in this loop
            // already received one.
            var warmupSetCount = 0
            if !warmupGenerated && WarmupRamp.shouldGenerate(
                for: se,
                deloadActive: false,
                topWorkingWeight: prescribedWeight,
                barWeight: barWeight,
                warmupConfig: re.warmupOverride
            ) {
                let isUnilateral = re.exercise?.equipment == .dumbbell
                let warmupSets = WarmupRamp.generate(
                    top: prescribedWeight,
                    bar: barWeight,
                    plates: plates,
                    isUnilateral: isUnilateral
                )
                warmupSetCount = warmupSets.count
                for warmup in warmupSets {
                    warmup.sessionExercise = se
                    context.insert(warmup)
                }
                warmupGenerated = true

                // RESEARCH §Pitfall 5 / Area 3: reset skipNextSession after
                // consumption so it doesn't suppress the ramp permanently.
                if re.warmupOverride?.skipNextSession == true {
                    re.warmupOverride = WarmupConfig(
                        enabled: re.warmupOverride?.enabled ?? true,
                        skipNextSession: false
                    )
                }
            }

            // Pre-populate planned `SetEntry` rows. Each set carries the
            // previous-matching-intent weight as a "suggestion" but
            // `isComplete = false` is the explicit "planned, not yet
            // logged" sentinel (plan 00-01 D-3).
            //
            // Working set orderIndex is shifted up by the number of warm-up
            // rows inserted in Block B so warm-up rows occupy indices 0..N-1
            // and working sets start at N.
            let seedWeight = lastSessionWeight ?? 0
            for setIndex in 0..<re.targetSets {
                let entry = SetEntry()
                entry.sessionExercise = se
                entry.orderIndex = setIndex + warmupSetCount   // shifted past warm-up slots
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
    internal static func fetchHistoryPoints(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> [HistoryPoint] {
        guard let exerciseID else { return [] }

        // RESEARCH §Pitfall 1 — local-let captures required before #Predicate.
        let targetID = exerciseID
        let targetIntent = intentRaw

        // Use a broader predicate (completed + non-warmup) and post-filter by
        // exercise+intent in Swift — the multi-level optional chaining
        // (entry.sessionExercise?.exercise?.id) causes type-checking timeouts
        // inside #Predicate on the Swift 6 toolchain (RESEARCH §Pitfall 1).
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { entry in
                entry.isWarmup == false && entry.isComplete == true
            },
            sortBy: [SortDescriptor(\SetEntry.completedAt, order: .reverse)]
        )

        // Fetch all completed non-warmup sets, then filter in Swift.
        // fetchLimit not set here because we filter further; cap the
        // compactMap result to 50 points below.
        guard let all = try? context.fetch(descriptor) else { return [] }

        let entries = all.filter { entry in
            entry.reps > 0
                && entry.weight > 0
                && entry.sessionExercise?.intentRaw == targetIntent
                && entry.sessionExercise?.exercise?.id == targetID
        }

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
    internal static func lastSessionWorkingReps(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> [Int] {
        guard let exerciseID else { return [] }

        // RESEARCH §Pitfall 1 — local-let captures.
        let targetID = exerciseID
        let targetIntent = intentRaw

        // Use a simpler predicate on intentRaw only; post-filter by exerciseID.
        // SortDescriptor on optional keypaths (\.session?.startedAt) can cause
        // type-checking failures in the Swift 6 toolchain.
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.intentRaw == targetIntent }
        )

        guard let allSes = try? context.fetch(descriptor) else { return [] }
        // Post-filter by exercise ID and sort by session startedAt descending.
        let recent = allSes
            .filter { $0.exercise?.id == targetID }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
            .prefix(5)

        for se in recent {
            let workingSets = (se.sets ?? []).filter { entry in
                !entry.isWarmup && entry.reps > 0 && entry.isComplete
            }
            if !workingSets.isEmpty {
                return workingSets
                    .sorted { $0.orderIndex < $1.orderIndex }
                    .map { $0.reps }
            }
        }
        return []
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
        // Fetch UserSettings for the unit system; fall back to .kg if absent.
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let unit = (try? context.fetch(settingsDescriptor))?.first?.weightUnit ?? .kg

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
