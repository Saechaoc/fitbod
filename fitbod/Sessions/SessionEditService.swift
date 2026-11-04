// SessionEditService.swift
// fitbod
//
// Corrections to a finished workout, made from History. One `WorkoutEdit`
// is one save: it is checked first, then written in a single transaction,
// and a failed save rolls everything back, so a workout is never left half
// corrected. Deleting a workout is SessionSetActions.deleteWorkout.
//
// Rules (docs/ROADMAP.md "Decided", .planning/HANDOFF-training-model-coherence.md):
//   - A workout's place in time is `startedAt`. Moving it shifts the start,
//     the finish and every set's completedAt by one delta, never into the
//     future, and the workout then belongs to the block running at its new
//     start.
//   - The frozen prescription, names, intent and slot are never rewritten.
//   - Records, volume, progression and reviews are derived on read, so they
//     follow the corrected sets with no extra work here.

import Foundation
import SwiftData

/// One History correction: the workout's start and its set changes.
public struct WorkoutEdit: Equatable, Sendable {
    public struct Values: Equatable, Sendable {
        public var weight: Double
        public var reps: Int
        public var rpe: Double?

        public init(weight: Double, reps: Int, rpe: Double?) {
            self.weight = weight
            self.reps = reps
            self.rpe = rpe
        }
    }

    /// The new start; the whole workout moves with it.
    public var startedAt: Date
    /// New values for existing sets, by `SetEntry.id`.
    public var changed: [UUID: Values] = [:]
    /// Sets to append, by `SessionExercise.id`, in order.
    public var added: [UUID: [Values]] = [:]
    /// Existing sets to delete, by `SetEntry.id`.
    public var deleted: Set<UUID> = []

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }
}

public enum SessionEditError: Error, Equatable {
    /// Only a finished workout is corrected here; the logger edits one in progress.
    case notFinished
    /// The workout would end after now.
    case endsInFuture
    /// A set needs positive reps, a valid weight and an RPE from 0 to 10.
    case invalidSet
}

/// Correction fields accept a whole, ungrouped number, never a parsed prefix.
enum WorkoutCorrectionInput {
    static func weight(_ text: String, locale: Locale) -> Double? {
        let parts = text.components(separatedBy: locale.decimalSeparator ?? ".")
        guard parts.count <= 2 else { return nil }
        let digits = parts.compactMap(decimalDigits)
        guard digits.count == parts.count,
              let value = Double(digits.joined(separator: ".")),
              isSupported(value)
        else { return nil }
        return value
    }

    static func reps(_ text: String) -> Int? {
        guard let digits = decimalDigits(text), let value = Int(digits),
              value > 0, Int(exactly: Double(value)) != nil
        else { return nil }
        return value
    }

    static func weightText(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.grouping(.never).precision(.significantDigits(1...17)).locale(locale))
    }

    /// Rendering and volume math require a nonnegative, representable rounded Int.
    static func isSupported(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && Int(exactly: value.rounded()) != nil
    }

    private static func decimalDigits(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        var result = ""
        for character in text {
            guard character.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains),
                  let digit = character.wholeNumberValue
            else { return nil }
            result.append(String(digit))
        }
        return result
    }
}

@MainActor
public enum SessionEditService {

    public static func save(
        _ edit: WorkoutEdit,
        to session: Session,
        now: Date = .now,
        context: ModelContext
    ) throws {
        guard let finishedAt = session.completedAt else { throw SessionEditError.notFinished }
        let delta = edit.startedAt.timeIntervalSince(session.startedAt)
        guard finishedAt.addingTimeInterval(delta) <= now else { throw SessionEditError.endsInFuture }

        let exercises = session.exercises ?? []
        var workoutVolume = 0.0
        for exercise in exercises {
            let equipment = exercise.exercise?.equipment
            let kept = (exercise.sets ?? []).filter { !edit.deleted.contains($0.id) }
            let added = edit.added[exercise.id] ?? []
            guard (kept.compactMap { edit.changed[$0.id] } + added)
                .allSatisfy({ isValid($0, equipment: equipment) })
            else {
                throw SessionEditError.invalidSet
            }
            let proposed = kept.filter { $0.isComplete && !$0.isWarmup }.map {
                edit.changed[$0.id] ?? WorkoutEdit.Values(weight: $0.weight, reps: $0.reps, rpe: $0.rpe)
            } + added
            var exerciseVolume = 0.0
            for values in proposed {
                guard isValid(values, equipment: equipment) else { throw SessionEditError.invalidSet }
                exerciseVolume += values.weight * Double(values.reps)
                guard WorkoutCorrectionInput.isSupported(exerciseVolume) else { throw SessionEditError.invalidSet }
            }
            workoutVolume += exerciseVolume
            guard WorkoutCorrectionInput.isSupported(workoutVolume) else { throw SessionEditError.invalidSet }
        }
        let blocks = delta == 0 ? [] : try context.fetch(FetchDescriptor<Block>())

        do {
            try context.transaction {
                if delta != 0 {
                    session.startedAt = edit.startedAt
                    session.completedAt = finishedAt.addingTimeInterval(delta)
                    for set in exercises.flatMap({ $0.sets ?? [] }) {
                        set.completedAt = set.completedAt.addingTimeInterval(delta)
                    }
                    session.block = block(runningAt: edit.startedAt, in: blocks)
                }
                for exercise in exercises {
                    apply(edit, to: exercise, endingBy: session.completedAt ?? finishedAt, context: context)
                }
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    /// The block that was running at `date`: one that has started, and had
    /// not ended by then. Ready and draft blocks never ran, so they hold no
    /// workouts.
    public static func block(runningAt date: Date, in blocks: [Block]) -> Block? {
        blocks
            .filter { ($0.isActive || $0.endDate != nil) && $0.startDate <= date && date < ($0.endDate ?? .distantFuture) }
            .max { $0.startDate < $1.startDate }
    }

    private static func apply(_ edit: WorkoutEdit, to exercise: SessionExercise, endingBy end: Date, context: ModelContext) {
        var kept: [SetEntry] = []
        for set in SessionSetActions.ordered(exercise) {
            if edit.deleted.contains(set.id) {
                context.delete(set)
                continue
            }
            if let values = edit.changed[set.id] {
                set.weight = values.weight
                set.reps = values.reps
                set.rpe = values.rpe
            }
            kept.append(set)
        }
        // An added set is logged just after the last one, inside the workout.
        var stamp = kept.last(where: \.isComplete)?.completedAt ?? exercise.session?.startedAt ?? end
        for values in edit.added[exercise.id] ?? [] {
            let entry = SetEntry()
            context.insert(entry)
            entry.sessionExercise = exercise
            entry.weight = values.weight
            entry.reps = values.reps
            entry.rpe = values.rpe
            entry.isComplete = true
            stamp = min(stamp.addingTimeInterval(1), end)
            entry.completedAt = stamp
            kept.append(entry)
        }
        for (index, set) in kept.enumerated() where set.orderIndex != index {
            set.orderIndex = index
        }
    }

    private static func isValid(_ values: WorkoutEdit.Values, equipment: Equipment?) -> Bool {
        let rpeIsValid = values.rpe.map { $0.isFinite && (0...10).contains($0) } ?? true
        return rpeIsValid
            && SessionSetActions.isValidSet(weight: values.weight, reps: values.reps, equipment: equipment)
            && WorkoutCorrectionInput.isSupported(values.weight)
            && Int(exactly: Double(values.reps)) != nil
            && WorkoutCorrectionInput.isSupported(values.weight * Double(values.reps))
    }
}
