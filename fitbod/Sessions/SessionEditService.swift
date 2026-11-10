// SessionEditService.swift
// fitbod
//
// Corrections to a finished workout, made from History. One `WorkoutEdit`
// is one save: it is checked first, then written in a single transaction,
// and a failed save rolls everything back, so a workout is never left half
// corrected. Deleting a workout is SessionSetActions.deleteWorkout.
//
// Rules: ARCHITECTURE.md "Snapshots and corrections"; docs/ROADMAP.md decisions.
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
        public var durationSeconds: Int?
        public var distanceMeters: Double?
        public var level: Double?

        public init(
            weight: Double, reps: Int, rpe: Double?,
            durationSeconds: Int? = nil, distanceMeters: Double? = nil, level: Double? = nil
        ) {
            self.weight = weight
            self.reps = reps
            self.rpe = rpe
            self.durationSeconds = durationSeconds
            self.distanceMeters = distanceMeters
            self.level = level
        }

        init(_ set: SetEntry) {
            self.init(
                weight: set.weight, reps: set.reps, rpe: set.rpe,
                durationSeconds: set.durationSeconds, distanceMeters: set.distanceMeters, level: set.level
            )
        }

        fileprivate func write(to set: SetEntry) {
            set.weight = weight
            set.reps = reps
            set.rpe = rpe
            set.durationSeconds = durationSeconds
            set.distanceMeters = distanceMeters
            set.level = level
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

    /// A set's time stays under 100 hours, the most "99:59:59" can show.
    static let durationLimit = 100 * 3600

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
            let tracking = exercise.exercise?.tracking
            let kept = (exercise.sets ?? []).filter { !edit.deleted.contains($0.id) }
            let added = edit.added[exercise.id] ?? []
            // A set left alone is not judged again: it may have been logged
            // under another tracking type, and it must never block a
            // correction to the rest of its workout.
            let changedAreValid = kept.allSatisfy { set in
                edit.changed[set.id].map { isValid($0, tracking: rule(for: set, exerciseTracking: tracking)) } ?? true
            }
            guard changedAreValid, added.allSatisfy({ isValid($0, tracking: tracking) }) else {
                throw SessionEditError.invalidSet
            }
            let proposed = kept.filter { $0.isComplete && !$0.isWarmup }.map {
                edit.changed[$0.id] ?? WorkoutEdit.Values($0)
            } + added
            var exerciseVolume = 0.0
            for values in proposed {
                exerciseVolume += SetEntry.tonnage(weight: values.weight, reps: values.reps)
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
                        set.startedAt = set.startedAt?.addingTimeInterval(delta)
                    }
                    session.block = block(runningAt: edit.startedAt, in: blocks)
                }
                for exercise in exercises {
                    apply(edit, to: exercise, endingBy: session.completedAt ?? finishedAt, context: context)
                }
                try context.save()
            }
        } catch {
            SessionSetActions.rollBack(context)
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
            edit.changed[set.id]?.write(to: set)
            kept.append(set)
        }
        // An added set is logged just after the last one, inside the workout.
        var stamp = kept.last(where: \.isComplete)?.completedAt ?? exercise.session?.startedAt ?? end
        for values in edit.added[exercise.id] ?? [] {
            let entry = SetEntry()
            context.insert(entry)
            entry.sessionExercise = exercise
            values.write(to: entry)
            entry.isComplete = true
            stamp = min(stamp.addingTimeInterval(1), end)
            entry.completedAt = stamp
            kept.append(entry)
        }
        for (index, set) in kept.enumerated() where set.orderIndex != index {
            set.orderIndex = index
        }
    }

    /// The rule a correction to a stored set must meet. The shape it was
    /// logged in wins over what its exercise tracks now, which curation may
    /// have changed since.
    private static func rule(for set: SetEntry, exerciseTracking: Tracking?) -> Tracking? {
        if set.isTimed { return .duration }
        return exerciseTracking?.isTimed == false ? exerciseTracking : nil
    }

    private static func isValid(_ values: WorkoutEdit.Values, tracking: Tracking?) -> Bool {
        let rpeIsValid = values.rpe.map { $0.isFinite && (0...10).contains($0) } ?? true
        // Assistance is a negative weight, so the size is what must be representable.
        let load = abs(values.weight)
        let extrasAreValid = [values.distanceMeters, values.level]
            .allSatisfy { $0.map(WorkoutCorrectionInput.isSupported) ?? true }
            && values.durationSeconds.map { (0..<WorkoutCorrectionInput.durationLimit).contains($0) } ?? true
        return rpeIsValid && extrasAreValid
            && SessionSetActions.isValidSet(
                weight: values.weight, reps: values.reps,
                durationSeconds: values.durationSeconds, tracking: tracking
            )
            && WorkoutCorrectionInput.isSupported(load)
            && Int(exactly: Double(values.reps)) != nil
            && WorkoutCorrectionInput.isSupported(load * Double(values.reps))
    }
}
