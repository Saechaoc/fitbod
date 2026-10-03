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

            // Resolve "previous matching-intent weight" for the planned
            // `SetEntry` rows. Returns nil for the first-ever logged
            // session of this (exercise, intent) tuple → set rows default
            // weight = 0. PIVOT-02: intent is sourced from the snapshotted
            // session-level field, not the per-exercise field (which no
            // longer exists post-Plan-02).
            let previousHint = PreviousMatchingIntent.fetchTopWorkingSet(
                exerciseID: re.exercise?.id,
                intentRaw: session.intentRaw,
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
            // PIVOT-02: intentRaw sourced from session-level snapshot.
            let historyPoints = Self.fetchHistoryPoints(
                exerciseID: re.exercise?.id,
                intentRaw: session.intentRaw,
                context: context
            )

            // Fetch the last session's working-set reps array for DoubleProgression
            // bump detection. PIVOT-02: intentRaw sourced from session-level snapshot.
            let lastRepsArray = Self.lastSessionWorkingReps(
                exerciseID: re.exercise?.id,
                intentRaw: session.intentRaw,
                context: context
            )

            // Previous-intent scalars (already fetched above for the SetEntry hint).
            let lastSessionWeight = previousHint?.weight
            let lastSessionReps = previousHint?.reps
            let lastSessionRPE = previousHint?.rpe
            let lastSessionDate = previousHint?.sessionStartedAt

            // D-14 — reuse the session-level strategy instance hoisted
            // above the loop (one strategy per session, used for every
            // SessionExercise). The instance is stateless so reuse is
            // safe; the per-exercise variation lives in the prescribe()
            // call's history + history-derived inputs.
            let strategy = sessionStrategy
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
                lastSessionDate: lastSessionDate,
                block: activeBlock,
                today: date
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
                deloadActive: scheduledDeloadActive,
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
    ///
    /// Phase 3.1 PIVOT-05 / D-13: intent is a SESSION-level field after
    /// Plan 02. The intent post-filter now traverses
    /// `entry.sessionExercise?.session?.intentRaw` (was
    /// `entry.sessionExercise?.intentRaw`). The Pitfall 1 multi-level
    /// optional chain is contained inside the Swift filter step, NOT the
    /// #Predicate. The Phase 1 #Index<SessionExercise>([\.intentRaw]) is
    /// gone; the new #Index<Session>([\.intentRaw]) (Plan 02) is one
    /// indirection away and does not accelerate this specific query.
    /// Acceptable at single-user scale per CONTEXT.md performance notes.
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
        // (entry.sessionExercise?.exercise?.id, and now
        // entry.sessionExercise?.session?.intentRaw) causes type-checking
        // timeouts inside #Predicate on the Swift 6 toolchain (RESEARCH §Pitfall 1).
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { entry in
                entry.isWarmup == false && entry.isComplete == true
            },
            sortBy: [SortDescriptor(\SetEntry.completedAt, order: .reverse)]
        )

        // Fetch all completed non-warmup sets, then filter in Swift.
        // fetchLimit not set here because we filter further; cap the
        // compactMap result to 50 points below. PIVOT-05: intent is read
        // from the parent Session via the SessionExercise.session relation.
        guard let all = try? context.fetch(descriptor) else { return [] }

        let entries = all.filter { entry in
            entry.reps > 0
                && entry.weight > 0
                && entry.sessionExercise?.session?.intentRaw == targetIntent
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
    ///
    /// Phase 3.1 PIVOT-05 / D-13: intent is a SESSION-level field after
    /// Plan 02. The #Predicate gates on `se.exercise?.id == targetID`
    /// only; the intent gate moves to the Swift post-filter as
    /// `se.session?.intentRaw == targetIntent`. Pitfall 1 forbids the
    /// multi-level optional chain `se.session?.intentRaw` inside the
    /// #Predicate (mirrors PreviousMatchingIntent's pattern). The Phase 1
    /// #Index<SessionExercise>([\.intentRaw]) is gone; the new
    /// #Index<Session>([\.intentRaw]) (Plan 02) is one indirection away
    /// and does not accelerate this specific query. Acceptable at
    /// single-user scale per CONTEXT.md performance notes.
    internal static func lastSessionWorkingReps(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> [Int] {
        guard let exerciseID else { return [] }

        // RESEARCH §Pitfall 1 — local-let captures.
        let targetID = exerciseID
        let targetIntent = intentRaw

        // Predicate gates on exerciseID only (single-level optional chain
        // is safe inside #Predicate per RESEARCH §Pitfall 1 — the
        // workaround is the local-let capture above). The intent gate
        // lives in the Swift post-filter because the new
        // `se.session?.intentRaw` chain is multi-level optional which
        // Pitfall 1 forbids inside #Predicate. Mirrors
        // PreviousMatchingIntent's post-Plan-07 descriptor + filter pattern.
        // SortDescriptor on optional keypaths (\.session?.startedAt) can cause
        // type-checking failures in the Swift 6 toolchain — sort in Swift.
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.exercise?.id == targetID }
        )

        guard let allSes = try? context.fetch(descriptor) else { return [] }
        // Swift post-filter for intent (PIVOT-05 — read from parent
        // Session via the SessionExercise.session relation), then sort by
        // session startedAt descending and take the 5 most-recent
        // candidates.
        let recent = allSes
            .filter { $0.session?.intentRaw == targetIntent }
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

// MARK: - Phase 6 / Plan 06-07 — Per-session PR table seeding
//
// Builds the per-exercise PR table once at session start so the
// in-session detector (InSessionPRState.observeSave) never re-queries
// SwiftData on a per-set commit.
//
// The fetch is ONE broad predicate (completed, non-warm-up) with the
// exercise gate applied in Swift. A multi-level optional chain such as
// `entry.sessionExercise?.exercise?.id` inside #Predicate compiles but
// throws NSInvalidArgumentException at fetch time ("Unsupported function
// expression TERNARY(...)"), which crashed the logger on every open.

extension SessionFactory {

    /// Seeds the PR table from every completed working-candidate set of
    /// the exercises in `session` (including sets already logged in this
    /// session, so a resumed workout keeps its in-session PRs).
    ///
    /// Returns an empty `PRTable` when the session has no exercises or
    /// the fetch fails; the in-session banner then simply emits no PRs
    /// until the first set lands and seeds the table inline.
    @MainActor
    public static func seedPRTable(for session: Session, context: ModelContext) async -> PRTable {
        let exerciseIDs = Set((session.exercises ?? []).compactMap { $0.exercise?.id })
        guard !exerciseIDs.isEmpty else { return PRTable() }

        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate<SetEntry> { entry in
                entry.isComplete && !entry.isWarmup
            },
            sortBy: [SortDescriptor(\.completedAt)]
        )
        guard let candidates = try? context.fetch(descriptor) else { return PRTable() }
        let relevant = candidates.filter { entry in
            guard let id = entry.sessionExercise?.exercise?.id else { return false }
            return exerciseIDs.contains(id)
        }
        return PRDetector.buildTable(from: relevant)
    }
}
