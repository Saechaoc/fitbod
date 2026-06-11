//
//  ExerciseDeletion.swift
//  fitbod
//
//  App-level delete helper for library exercises. SwiftData does not
//  reliably clear optional, inverse-less Exercise references in the same
//  context after `ModelContext.delete(_:)`, so the product delete path
//  explicitly preserves templates and history by nullifying those links
//  before deleting the Exercise row.
//

import Foundation
import SwiftData

public enum ExerciseDeletion {
    public static func delete(_ exercise: Exercise, context: ModelContext) throws {
        let exerciseID = exercise.id
        try context.transaction {
            let sessionExercises = try context.fetch(FetchDescriptor<SessionExercise>())
            for sessionExercise in sessionExercises where sessionExercise.exercise?.id == exerciseID {
                sessionExercise.exercise = nil
            }

            let routineExercises = try context.fetch(FetchDescriptor<SessionExerciseTemplate>())
            for routineExercise in routineExercises where routineExercise.exercise?.id == exerciseID {
                routineExercise.exercise = nil
            }

            context.delete(exercise)
            try context.save()
        }
    }
}
