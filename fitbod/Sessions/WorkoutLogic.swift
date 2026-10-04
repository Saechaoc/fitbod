//
//  WorkoutLogic.swift
//  fitbod
//
//  The rules behind the active-workout screen, kept out of the views so
//  they can be unit-tested against an in-memory ModelContainer:
//
//    - WorkoutLogging   validate / complete / un-complete / add / delete
//                       sets, persisting immediately (so a kill at any
//                       moment loses nothing that was confirmed).
//    - PreviousPerformance  "what did I do last time?" per set, for the
//                       same exercise + intent, EXCLUDING the workout in
//                       progress (the old top-set query could return the
//                       current session once a set was committed).
//    - WorkoutStats     totals for headers, summaries, and history rows.
//    - WorkoutFinisher  finish (prune unfinished sets, stamp duration) and
//                       discard.
//
//  Snapshot rule (PITFALLS-doc #1): nothing here reads the source Routine.
//  A session is a self-contained copy taken at start time.
//

import Foundation
import SwiftData

// MARK: - Set validation

public enum SetValidation: Equatable, Sendable {
    case ok
    case missingReps
    case missingWeight

    /// Inline error copy for a set row ("Enter reps to complete set 2.").
    public func message(setLabel: String) -> String? {
        switch self {
        case .ok: return nil
        case .missingReps: return "Enter reps to complete set \(setLabel)."
        case .missingWeight: return "Enter a weight to complete set \(setLabel)."
        }
    }
}

public enum WorkoutLogging {

    /// Bodyweight-style equipment logs added (+) or assisted (−) load, so
    /// zero and negative weights are valid there.
    public static func allowsZeroOrNegativeWeight(_ equipment: Equipment?) -> Bool {
        equipment == .bodyweight || equipment == .weightedBodyweight
    }

    /// Reps are always required; weight must be positive unless the lift is
    /// bodyweight-based.
    public static func validate(_ entry: SetEntry, equipment: Equipment?) -> SetValidation {
        if entry.reps <= 0 { return .missingReps }
        if !allowsZeroOrNegativeWeight(equipment) && entry.weight <= 0 { return .missingWeight }
        return .ok
    }

    /// Marks a set complete and saves. Returns the validation result; the
    /// set is untouched unless `.ok`.
    @discardableResult
    public static func complete(
        _ entry: SetEntry,
        equipment: Equipment?,
        context: ModelContext,
        now: Date = .now
    ) -> SetValidation {
        let result = validate(entry, equipment: equipment)
        guard result == .ok else { return result }
        entry.isComplete = true
        entry.completedAt = now
        try? context.save()
        return .ok
    }

    /// Re-opens a completed set for editing.
    public static func uncomplete(_ entry: SetEntry, context: ModelContext) {
        entry.isComplete = false
        try? context.save()
    }

    /// Working sets (not warm-ups) in display order.
    public static func workingSets(of sessionExercise: SessionExercise) -> [SetEntry] {
        (sessionExercise.sets ?? [])
            .filter { !$0.isWarmup }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Warm-up sets in display order.
    public static func warmupSets(of sessionExercise: SessionExercise) -> [SetEntry] {
        (sessionExercise.sets ?? [])
            .filter { $0.isWarmup }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Appends a working set that copies the last working set's weight (the
    /// fastest path to "same again"). Reps start empty so the lifter enters
    /// what they actually did.
    @discardableResult
    public static func addSet(to sessionExercise: SessionExercise, context: ModelContext) -> SetEntry {
        let all = sessionExercise.sets ?? []
        let last = workingSets(of: sessionExercise).last
        let entry = SetEntry()
        entry.sessionExercise = sessionExercise
        entry.orderIndex = (all.map(\.orderIndex).max() ?? -1) + 1
        entry.setTypeRaw = SetType.working.rawValue
        entry.isWarmup = false
        entry.isComplete = false
        entry.weight = last?.weight ?? (sessionExercise.prescribedWeight ?? 0)
        entry.reps = 0
        entry.completedAt = .now
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// Deletes one set and saves.
    public static func delete(_ entry: SetEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    /// Deletes all warm-up rows of an exercise ("Skip warm-ups").
    public static func skipWarmups(of sessionExercise: SessionExercise, context: ModelContext) {
        for warmup in warmupSets(of: sessionExercise) {
            context.delete(warmup)
        }
        try? context.save()
    }

    /// Appends an unplanned exercise to a workout (SESS-06) with sensible
    /// defaults and three planned sets seeded from the last matching-intent
    /// weight. The source routine is never touched.
    @discardableResult
    public static func addExercise(_ exercise: Exercise, to session: Session, context: ModelContext) -> SessionExercise {
        let isStrength = exercise.mechanic == .compound && exercise.equipment == .barbell
        let se = SessionExercise()
        se.session = session
        se.exercise = exercise
        se.orderIndex = ((session.exercises ?? []).map(\.orderIndex).max() ?? -1) + 1
        se.intentRaw = (isStrength ? Intent.strength : Intent.hypertrophy).rawValue
        se.targetSets = 3
        se.targetRepsLow = isStrength ? 4 : 8
        se.targetRepsHigh = isStrength ? 6 : 12
        se.targetRPE = 8
        se.prescribedRestSeconds = exercise.mechanic == .compound ? 180 : 90
        context.insert(se)

        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise.id,
            intentRaw: se.intentRaw,
            context: context
        )?.weight ?? 0
        for index in 0..<se.targetSets {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = index
            entry.weight = hint
            entry.reps = 0
            entry.setTypeRaw = SetType.working.rawValue
            entry.isComplete = false
            entry.completedAt = .now
            context.insert(entry)
        }
        try? context.save()
        return se
    }

    /// Copies a previous set's numbers into an open set ("tap Previous").
    public static func apply(_ previous: PreviousPerformance.Line, to entry: SetEntry, context: ModelContext) {
        guard !entry.isComplete else { return }
        entry.weight = previous.weight
        entry.reps = previous.reps
        if entry.rpe == nil { entry.rpe = previous.rpe }
        try? context.save()
    }
}

// MARK: - Previous performance

/// The most recent earlier performance of one exercise at one intent.
public struct PreviousPerformance: Equatable, Sendable {
    public struct Line: Equatable, Sendable {
        public let weight: Double
        public let reps: Int
        public let rpe: Double?

        public init(weight: Double, reps: Int, rpe: Double?) {
            self.weight = weight
            self.reps = reps
            self.rpe = rpe
        }
    }

    public let sessionStartedAt: Date
    public let routineName: String
    /// Completed working sets in the order they were performed.
    public let lines: [Line]

    /// The previous set at the same position, falling back to the last one
    /// when today has more sets than last time.
    public func line(forSetIndex index: Int) -> Line? {
        guard !lines.isEmpty else { return nil }
        return index < lines.count ? lines[index] : nil
    }

    /// Heaviest completed set (ties → more reps).
    public var topLine: Line? {
        lines.max { a, b in
            if a.weight != b.weight { return a.weight < b.weight }
            return a.reps < b.reps
        }
    }

    /// Looks up the latest earlier session (finished or not, but never the
    /// one being logged) with at least one completed working set for this
    /// exercise + intent.
    public static func lookup(
        exerciseID: UUID?,
        intentRaw: String,
        excludingSessionID: UUID?,
        context: ModelContext
    ) -> PreviousPerformance? {
        guard let exerciseID else { return nil }
        // Local captures before #Predicate (RESEARCH §6 Pitfall 1); the
        // related-entity compare is done in Swift.
        let targetIntent = intentRaw
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate { se in se.intentRaw == targetIntent }
        )
        guard let candidates = try? context.fetch(descriptor) else { return nil }

        let ordered = candidates
            .filter { $0.exercise?.id == exerciseID }
            .filter { excludingSessionID == nil || $0.session?.id != excludingSessionID }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }

        for se in ordered.prefix(8) {
            let lines = WorkoutLogging.workingSets(of: se)
                .filter { $0.isComplete && $0.reps > 0 }
                .map { Line(weight: $0.weight, reps: $0.reps, rpe: $0.rpe) }
            if !lines.isEmpty {
                return PreviousPerformance(
                    sessionStartedAt: se.session?.startedAt ?? .distantPast,
                    routineName: se.session?.routineSnapshotName ?? "",
                    lines: lines
                )
            }
        }
        return nil
    }
}

// MARK: - Stats

/// Estimated one-rep max (Epley). Returns nil for non-positive loads or
/// reps above 12, where the estimate stops being meaningful.
public enum OneRepMax {
    public static func epley(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps > 0, reps <= 12 else { return nil }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }
}

/// Totals for a workout. Only completed working sets count.
public struct WorkoutStats: Equatable, Sendable {
    public let completedSets: Int
    public let plannedSets: Int
    public let totalReps: Int
    public let volume: Double
    public let exerciseCount: Int
    public let durationSeconds: Int

    public static func compute(for session: Session, now: Date = .now) -> WorkoutStats {
        let exercises = session.exercises ?? []
        var completed = 0
        var planned = 0
        var reps = 0
        var volume = 0.0
        for se in exercises {
            for entry in WorkoutLogging.workingSets(of: se) {
                planned += 1
                guard entry.isComplete else { continue }
                completed += 1
                reps += entry.reps
                if entry.weight > 0 {
                    volume += entry.weight * Double(entry.reps)
                }
            }
        }
        let end = session.completedAt ?? now
        let duration = session.totalDurationSeconds ?? max(0, Int(end.timeIntervalSince(session.startedAt)))
        return WorkoutStats(
            completedSets: completed,
            plannedSets: planned,
            totalReps: reps,
            volume: volume,
            exerciseCount: exercises.count,
            durationSeconds: duration
        )
    }
}

/// Per-exercise recap for the summary screen.
public struct ExerciseRecap: Identifiable, Sendable {
    public enum Delta: Equatable, Sendable {
        case firstTime
        case same
        case heavier(Double)
        case lighter(Double)
        case moreReps(Int)
        case fewerReps(Int)
    }

    public let id: UUID
    public let name: String
    public let intentRaw: String
    public let lines: [PreviousPerformance.Line]
    public let best: PreviousPerformance.Line?
    public let estimatedOneRepMax: Double?
    public let delta: Delta

    /// Builds recaps for every exercise with ≥ 1 completed working set,
    /// comparing each best set with the previous matching-intent session.
    public static func build(for session: Session, context: ModelContext) -> [ExerciseRecap] {
        let exercises = (session.exercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        return exercises.compactMap { se in
            let lines = WorkoutLogging.workingSets(of: se)
                .filter { $0.isComplete && $0.reps > 0 }
                .map { PreviousPerformance.Line(weight: $0.weight, reps: $0.reps, rpe: $0.rpe) }
            guard !lines.isEmpty else { return nil }
            let best = lines.max { a, b in
                if a.weight != b.weight { return a.weight < b.weight }
                return a.reps < b.reps
            }
            let previous = PreviousPerformance.lookup(
                exerciseID: se.exercise?.id,
                intentRaw: se.intentRaw,
                excludingSessionID: session.id,
                context: context
            )
            let earlier = previous.map { $0.sessionStartedAt < session.startedAt } ?? false
            return ExerciseRecap(
                id: se.id,
                name: se.exercise?.name ?? "Removed exercise",
                intentRaw: se.intentRaw,
                lines: lines,
                best: best,
                estimatedOneRepMax: best.flatMap { OneRepMax.epley(weight: $0.weight, reps: $0.reps) },
                delta: delta(best: best, previousBest: earlier ? previous?.topLine : nil)
            )
        }
    }

    static func delta(best: PreviousPerformance.Line?, previousBest: PreviousPerformance.Line?) -> Delta {
        guard let best, let previousBest else { return .firstTime }
        if best.weight > previousBest.weight { return .heavier(best.weight - previousBest.weight) }
        if best.weight < previousBest.weight { return .lighter(previousBest.weight - best.weight) }
        if best.reps > previousBest.reps { return .moreReps(best.reps - previousBest.reps) }
        if best.reps < previousBest.reps { return .fewerReps(previousBest.reps - best.reps) }
        return .same
    }
}

// MARK: - Finish / discard

public enum WorkoutFinisher {
    public struct Outcome: Equatable, Sendable {
        public let removedUnfinishedSets: Int
        public let removedEmptyExercises: Int
    }

    /// Number of planned sets that would be dropped on finish.
    public static func unfinishedSetCount(in session: Session) -> Int {
        (session.exercises ?? []).reduce(0) { total, se in
            total + (se.sets ?? []).filter { !$0.isComplete }.count
        }
    }

    /// Completed working sets in the session.
    public static func completedSetCount(in session: Session) -> Int {
        (session.exercises ?? []).reduce(0) { total, se in
            total + WorkoutLogging.workingSets(of: se).filter(\.isComplete).count
        }
    }

    /// Finishes a workout: drops sets that were never completed (and any
    /// exercise left with none), stamps `completedAt` and the duration, and
    /// saves. History therefore only ever contains performed work.
    @discardableResult
    public static func finish(_ session: Session, context: ModelContext, now: Date = .now) -> Outcome {
        var removedSets = 0
        var removedExercises = 0
        for se in session.exercises ?? [] {
            let sets = se.sets ?? []
            let unfinished = sets.filter { !$0.isComplete }
            if unfinished.count == sets.count {
                // Nothing performed: drop the exercise (cascade removes
                // its planned sets).
                removedSets += unfinished.count
                removedExercises += 1
                context.delete(se)
            } else {
                for entry in unfinished {
                    context.delete(entry)
                    removedSets += 1
                }
            }
        }
        session.completedAt = now
        session.totalDurationSeconds = max(0, Int(now.timeIntervalSince(session.startedAt)))
        try? context.save()
        return Outcome(removedUnfinishedSets: removedSets, removedEmptyExercises: removedExercises)
    }

    /// Deletes the workout and everything in it (cascade).
    public static func discard(_ session: Session, context: ModelContext) {
        context.delete(session)
        try? context.save()
    }
}
