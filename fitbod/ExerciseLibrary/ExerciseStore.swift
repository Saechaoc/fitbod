//
//  ExerciseStore.swift
//  fitbod
//
//  Explicit deletion for custom exercises (LIB-05).
//
//  `SessionExercise.exercise` / `RoutineExercise.exercise` have no inverse
//  on `Exercise`, so SwiftData does not nullify them on delete — a logged
//  workout would keep a dangling reference to a deleted model (this is
//  what the pre-existing CascadeRules tests caught). Adding an inverse
//  relationship would change the schema and need a migration, so this
//  milestone nullifies explicitly instead:
//
//    - logged sessions keep their sets; the exercise reads as "Removed
//      exercise" in history,
//    - routine lines that used the exercise are removed from those
//      routines (a routine line without an exercise cannot be started),
//    - then the exercise itself is deleted (stimulus rows cascade).
//

import Foundation
import SwiftData

public enum ExerciseStore {
    /// How many logged workouts and routines reference an exercise —
    /// shown in the delete confirmation.
    public struct Usage: Equatable, Sendable {
        public let loggedSessions: Int
        public let routines: Int
    }

    public static func usage(of exercise: Exercise, context: ModelContext) -> Usage {
        let id = exercise.id
        let sessionLines = ((try? context.fetch(FetchDescriptor<SessionExercise>())) ?? [])
            .filter { $0.exercise?.id == id }
        let routineLines = ((try? context.fetch(FetchDescriptor<RoutineExercise>())) ?? [])
            .filter { $0.exercise?.id == id }
        let sessions = Set(sessionLines.compactMap { $0.session?.id })
        let routines = Set(routineLines.compactMap { $0.routine?.id })
        return Usage(loggedSessions: sessions.count, routines: routines.count)
    }

    /// Deletes `exercise` after detaching every reference to it.
    public static func delete(_ exercise: Exercise, context: ModelContext) {
        let id = exercise.id
        for line in ((try? context.fetch(FetchDescriptor<SessionExercise>())) ?? []) where line.exercise?.id == id {
            line.exercise = nil
        }
        for line in ((try? context.fetch(FetchDescriptor<RoutineExercise>())) ?? []) where line.exercise?.id == id {
            let routine = line.routine
            context.delete(line)
            if let routine {
                let remaining = (routine.exercises ?? [])
                    .filter { $0.id != line.id }
                    .sorted { $0.orderIndex < $1.orderIndex }
                for (index, item) in remaining.enumerated() {
                    item.orderIndex = index
                }
            }
        }
        context.delete(exercise)
        try? context.save()
    }
}
