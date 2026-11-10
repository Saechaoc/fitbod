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
//    - Internal-static helpers: historyPoints(in:intentRaw:),
//      plateInventory(for:context:), equipmentKind(for:) — declared
//      `internal static` so tests and the exercise card can reuse them
//      without duplicating the SwiftData query logic.
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
    /// ROUTINE-07). Pending working rows start without entered values.
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
    ///
    /// `calendar` decides which block day `date` falls on, so the phase the
    /// factory plans is the phase Today shows for the same moment.
    public static func start(
        template: SessionTemplate,
        slot: SplitSessionSlot? = nil,
        activeBlock: Block? = nil,
        on date: Date = .now,
        calendar: Calendar = .current,
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
            PeriodizationEngine.phase(for: block, on: date, calendar: calendar)
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
            // on the snapshotted SessionExercise row. The exercise card's WHY
            // (SessionExerciseCard.currentExplanation) runs the same step at
            // render time for its PrescriptionExplanation — SessionFactory only
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

            // Set rows resolve their offers from the frozen prescription and
            // logged performance. Pending model values are the lifter's drafts.
            let plannedWorkingSetCount = PeriodizationEngine.workingSetCount(
                targetSets: re.targetSets, phase: scheduledBlockPhase
            )

            for setIndex in 0..<plannedWorkingSetCount {
                let entry = SetEntry()
                entry.sessionExercise = se
                entry.orderIndex = setIndex + warmupSets.count   // shifted past warm-up slots
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
            // Drop the unsaved workout: left pending, it would read as a
            // workout in progress and fail every later save.
            SessionSetActions.rollBack(context)
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

    /// One exercise's prescription: the prescribed weight and how it was
    /// reached, plus the bar, plates and previous matching-intent set it was
    /// computed from, which `start` reuses for the warm-up ramp and the
    /// planned sets. The exercise card's WHY reads the explanation.
    struct ExercisePrescription {
        let weight: Double
        let explanation: PrescriptionExplanation
        let barWeight: Double
        let plates: [(weight: Double, countPerSide: Int)]
        /// The step equipment without a plate inventory rounds by; nil when
        /// the inventory rounds.
        let increment: Double?
        let previousWorkingSets: [SetEntry]
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
        // Use one matching finished workout for load progression and the
        // set-by-set offers. The active workout is separate evidence.
        // The logger runs this on every card render, so the exercise's
        // history is fetched once here and read twice.
        let logs = exercise.map { PreviousMatchingIntent.logs(of: $0.id, context: context) } ?? []
        // A set is evidence for the next workout only in the shape the
        // exercise tracks now: a time for a timed exercise, reps otherwise.
        let timed = exercise?.tracking.isTimed == true
        let previousWorkout = PreviousMatchingIntent.lastWorkingSets(
            in: logs,
            intentRaw: session.intentRaw,
            excludingSessionID: session.id,
            counting: { timed ? $0.isTimed : $0.reps > 0 }
        )
        let previousSet = previousWorkout.flatMap { PreviousMatchingIntent.topWorkingSet(in: $0) }
        let previousWorkingSets = previousWorkout?.sets ?? []

        // Timed and assisted sets have no load to progress. Their offers
        // come from the last workout's sets alone.
        if let exercise, !exercise.tracking.progressesLoad {
            return ExercisePrescription(
                weight: 0,
                explanation: PrescriptionExplanation(
                    formulaName: "", roundedWeight: 0, roundedLine: "", status: .notApplicable
                ),
                barWeight: 0,
                plates: [],
                increment: nil,
                previousWorkingSets: previousWorkingSets
            )
        }

        let inventory = plateEquipmentKind(for: exercise?.equipment ?? .other)
            .map { plateInventory(for: $0, context: context) }
        let barWeight = exercise?.barWeightOverride ?? inventory?.barWeight ?? 0
        let plates = inventory?.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) } ?? []
        let smallestIncrement = prescriptionIncrement(for: exercise, settings: userSettings)
        let minCalibrationSets = userSettings?.minCalibrationSets ?? 10
        // Labels the explanation text only; weights are stored as entered.
        let unit = WeightUnit.effective(
            for: exercise,
            default: userSettings?.weightUnit ?? .default
        )

        // Fetch history for the strategy (RESEARCH §Pitfall 7 filter applied
        // inside historyPoints — nil-RPE sets are excluded).
        // PIVOT-02: intentRaw sourced from session-level snapshot.
        let historyPoints = Self.historyPoints(in: logs, intentRaw: session.intentRaw)

        let lastRepsArray = previousWorkingSets.map(\.reps)

        // Configure a value copy so rounding cannot leak between exercises in a session.
        var configuredStrategy = strategy
        let roundingIncrement = inventory == nil ? smallestIncrement : nil
        configuredStrategy.roundingIncrement = roundingIncrement
        let (progressedWeight, progressedExplanation) = configuredStrategy.prescribe(
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
        let (weight, explanation) = holdingDeloadWeight(
            progressedWeight, progressedExplanation, previousSet: previousSet, in: session, unit: unit
        )
        return ExercisePrescription(
            weight: weight,
            explanation: explanation,
            barWeight: barWeight,
            plates: plates,
            increment: roundingIncrement,
            previousWorkingSets: previousWorkingSets
        )
    }

    /// In a deload week each lift holds its last top set's weight
    /// (docs/ROADMAP.md, "Decided" 2026-11-05): the phase already cuts the
    /// sets, and no progression adds load. A bodyweight lift holds its 0
    /// added. Outside a deload, or with no earlier set, the strategy's
    /// weight stands.
    static func holdingDeloadWeight(
        _ weight: Double,
        _ explanation: PrescriptionExplanation,
        previousSet: PreviousMatchingIntentHit?,
        in session: Session,
        unit: WeightUnit
    ) -> (weight: Double, explanation: PrescriptionExplanation) {
        guard let held = previousSet?.weight,
              let block = session.block,
              PeriodizationEngine.phase(for: block, on: session.startedAt)?.kind == .deload
        else { return (weight, explanation) }
        let heldText = held > 0 ? "\(NumberText.weight(held)) \(unit.rawValue)" : "no added load"
        return (held, PrescriptionExplanation(
            lastSessionLine: explanation.lastSessionLine,
            formulaName: explanation.formulaName,
            computedLine: held > 0
                ? "Deload week: weight held at \(heldText), your last top set."
                : "Deload week: held at no added load, as in your last top set.",
            roundedWeight: held,
            roundedLine: "→ \(heldText) (held for the deload)",
            status: explanation.status,
            bumpOccurred: false,
            range: explanation.range,
            phaseContextLine: explanation.phaseContextLine,
            deloadNoteLine: explanation.deloadNoteLine,
            sessionIntent: explanation.sessionIntent
        ))
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
            increment: prescription.increment,
            isUnilateral: sessionExercise.exercise?.equipment == .dumbbell
        )
    }

    // MARK: - Internal-static helpers (plan 03-08)
    //
    // Declared `internal static` (not private) so tests and the exercise
    // card can reuse these query primitives without duplicating the
    // SwiftData #Predicate local-capture pattern (RESEARCH §6 Pitfall 1).

    /// Takes the up to 50 most recent working, completed, RPE-logged sets
    /// of `intentRaw` from logs fetched with `PreviousMatchingIntent.logs(of:)`,
    /// maps each to a HistoryPoint via back-calculated e1RM, and returns
    /// them sorted most-recent-first.
    ///
    /// RESEARCH §Pitfall 7: sets with nil RPE are excluded BEFORE the
    /// back-calc to avoid division-by-nil; sets whose Tuchscherer percent
    /// is nil (e.g. unknown RPE) are also skipped.
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
    /// `prescription` fetches the rows once for this and `lastWorkingSets`.
    /// The sets are sorted by `completedAt`, newest first, which is the
    /// order the former all-history `completedAt` sort produced.
    ///
    /// Only sets from FINISHED sessions (`completedAt != nil`) count, the
    /// same rule as `PreviousMatchingIntent.fetchTopWorkingSet`. A set
    /// logged in the workout in progress never feeds its own explanation.
    internal static func historyPoints(
        in sessionExercises: [SessionExercise],
        intentRaw: String
    ) -> [HistoryPoint] {
        let targetIntent = intentRaw

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

    /// Resolve the shared increment for session snapshots and the logger's explanation.
    internal static func prescriptionIncrement(for exercise: Exercise?, settings: UserSettings?) -> Double {
        let requested = exercise?.smallestIncrement ?? settings?.defaultIncrementKg ?? 2.5
        if plateEquipmentKind(for: exercise?.equipment ?? .other) == nil,
           !requested.isFinite || requested <= 0 {
            return 2.5
        }
        return requested
    }

    /// Only free bars and dumbbells load a plate inventory. A Smith machine
    /// has none: its bar weight differs per machine, so it rounds by the
    /// exercise's increment like other machines.
    internal static func plateEquipmentKind(for equipment: Equipment) -> PlateEquipmentKind? {
        switch equipment {
        case .barbell:  return .barbell
        case .dumbbell: return .dumbbell
        case .ezBar:    return .ezBar
        case .trapBar:  return .trapBar
        default:        return nil
        }
    }

    /// Compatibility mapping for plate UI; prescription uses the optional mapping above.
    internal static func equipmentKind(for equipment: Equipment) -> PlateEquipmentKind {
        plateEquipmentKind(for: equipment) ?? .barbell
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
    /// `PRDetector.buildTable` replays the sets oldest first, so on equal
    /// values the earlier set keeps the record.
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
        return PRDetector.buildTable(from: candidates)
    }
}
